# ONE Security Whitepaper

**Version:** 1.0 — April 2026  
**Authors:** ONE Engineering  
**Audience:** CTOs, security engineers, cryptographers, compliance teams

---

## Preface — the paradigm shift

Digital identity has been unsolved for fifty years. The fundamental problem is that every conventional identity mechanism is built on a *claim*: a password says "someone who knows this string is present"; a token says "someone who possesses this credential is present." Claims can be transferred, stolen, replayed, or forged. The history of digital security is largely a history of defending claims against attackers who are better at obtaining them than defenders are at protecting them.

Biometric authentication on hardware security chips changes the nature of the proof.

When a user authenticates with Touch ID on Apple's Secure Enclave, the chip produces a cryptographic output that certifies physical presence of the enrolled biometric. This is not a claim — it is a proof. The proof is generated inside hardware that cannot be remotely accessed, cannot be cloned, and cannot be socially engineered. It cannot be forwarded to an attacker, delegated to an agent, or produced by any software on the device. The only way to generate it is to be there, with the enrolled finger, on the enrolled device.

ONE builds its entire key hierarchy on this proof. Every private key in the system — wallets, API credentials, agent key-encrypting keys — is derived deterministically from this hardware-bound root. Every agent's authority traces, through a verifiable on-chain chain of custody, to a biometric moment: a specific human being physically present when they authorised the bounds within which that agent operates.

The consequences are significant:

- **Non-repudiation at depth.** "I didn't authorise that" is no longer a viable defence for actions that trace to a biometric.
- **KYC at the cryptographic root.** Identity is embedded in the key derivation, not bolted on at the application layer.
- **Legal standing.** Touch ID signatures meet the technical criteria for qualified electronic signatures in most jurisdictions.
- **Accountability without surveillance.** The chain proves who authorised what without requiring centralised monitoring.

The safety properties described in this whitepaper — no plaintext keys on servers, blockchain-enforced spending caps, tamper-evident audit logs — are downstream consequences of this root. The primary architectural claim is simpler: **humans are proven by biometrics, and every action in the system inherits that proof.**

---

## Executive summary

ONE uses a layered cryptographic architecture in which the entire key hierarchy of any deployment traces back to a single biometric gesture on hardware the operator controls. Agent spending is enforced by blockchain consensus. Private keys never exist on ONE's infrastructure.

The architecture has five properties that distinguish it from conventional approaches:

1. **Humans are proven, not claimed.** Touch ID on Secure Enclave produces a non-transferable, hardware-bound proof of physical presence. Every key in the system derives from this.
2. **No plaintext keys on servers.** We store `hash(key)` only. The plaintext is derived on-device and never transmitted.
3. **No master derivation seed.** Each principal has an isolated secret. Compromising one compromises one.
4. **Spending authority is on-chain.** Agent caps are Sui Move objects enforced by the validator network — not application policy.
5. **The LLM is the only probabilistic step.** Every identity check, cap enforcement, and routing decision is deterministic. A model generating malicious output operates inside a cryptographically bounded scope.

This document explains the underlying primitives, the derivation algebra, the agent wallet lifecycle, and the threat model with honest residuals.

---

## 1. The hardware root — Apple Secure Enclave

### What the Secure Enclave is

Apple's Secure Enclave Processor (SEP) is a dedicated security co-processor included in every Apple Silicon and T-series Mac, iPhone, and iPad since 2013. It is physically isolated from the Application Processor — it has its own firmware, its own encrypted memory, and its own boot process. The SEP's job is narrow: generate cryptographic keys and perform cryptographic operations without those keys ever leaving the chip.

The SEP generates an elliptic-curve key pair at device provisioning time using hardware-sourced entropy. This keypair is the root from which Touch ID/Face ID derive their enrollment templates and from which WebAuthn authenticator keys are derived. No software — including the OS kernel — can export this key. The only interface available to applications is: *"given a challenge, produce a signature or an HMAC"*.

This is meaningfully different from a software keystore or even a TPM in transparency: Apple's SEP design has been audited by independent security researchers, is documented in Apple's [Platform Security Guide](https://support.apple.com/guide/security/), and is subject to Secure Boot attestation chains. Side-channel attacks exist at lab scale; they are not practical against a running device.

### Touch ID as an access gate

Touch ID does not "send your fingerprint to Apple" or "verify your fingerprint on a server." It works as follows:

1. At enrollment, the SEP captures a mathematical representation of fingerprint minutiae. This representation is encrypted with a key that exists only inside the SEP and is stored inside the SEP's encrypted memory.
2. At verification time, the SEP compares a fresh scan against the stored template entirely inside the chip. It never leaves.
3. If the match passes, the SEP signals success — and only then will it service a cryptographic request from an authorised application.

From a security engineering perspective: Touch ID is an access gate on the SEP's signing/HMAC capability. A correct fingerprint unlocks the gate; an incorrect one does not. No fingerprint data crosses the chip boundary.

### Windows Hello and Android equivalents

The same architecture exists on other platforms:

| Platform | Hardware root | Standard |
|----------|--------------|---------|
| Apple (Mac/iPhone/iPad) | Secure Enclave Processor | Proprietary (well-documented) |
| Windows | TPM 2.0 + Windows Hello | TCG TPM spec + FIDO2 |
| Android | StrongBox / TEE | Android Keystore + FIDO2 |

ONE's architecture uses WebAuthn as the abstraction layer, so it works on all three. The security properties hold on all three — the primitives are equivalent, the specifics vary.

---

## 2. WebAuthn — the W3C standard that ONE uses

### What WebAuthn is

WebAuthn (Web Authentication API) is a W3C standard, Level 2 as of 2021, implemented in every major browser (Safari 14+, Chrome 67+, Firefox 60+, Edge 18+). It defines a JavaScript API that lets websites interact with hardware authenticators — Secure Enclave, TPM, YubiKey — without ever receiving the private key.

The core protocol is:

```
Website                             Browser                     Authenticator (SE/TPM)
   │                                    │                               │
   │── challenge (32 random bytes) ───►│                               │
   │                                    │── create(challenge, origin) ─►│
   │                                    │◄─ credentialId, publicKey ────│
   │◄─ credentialId, publicKey ─────────│                               │
   │   (store credentialId + pubkey)    │                               │
   │                                    │                               │
   │── challenge ────────────────────► │                               │
   │                                    │── sign(challenge, credId) ──► │ (Touch ID prompt)
   │                                    │◄─ signature ──────────────────│
   │◄─ signature ────────────────────── │                               │
   │   (verify: pubkey.verify(sig))     │                               │
```

The private key is generated inside the authenticator and never leaves. The website receives a credential ID (a handle to identify the credential later) and a public key. Authentication is: "prove you control the private key matching this public key" — standard asymmetric auth.

Passkeys are WebAuthn credentials that sync via iCloud Keychain or Google Password Manager. The private key is synced end-to-end encrypted across the user's devices in the same ecosystem (Apple-to-Apple, Google-to-Google). The sync blob is encrypted such that the platform (Apple/Google) cannot read the private key.

### The credentialId

A WebAuthn credential ID is an opaque byte string, typically 16–64 bytes, generated by the authenticator. It functions as a lookup key — "which credential should I use for this authentication?" It is not secret (it is sent in cleartext during authentication) but it is device-specific: knowing a credentialId does not grant the ability to authenticate.

ONE stores `credentialId` values alongside wallet metadata in IndexedDB and optionally in TypeDB (when linked to an account). They are safe to store unencrypted; they have no value without the corresponding device.

---

## 3. PRF — the extension that makes wallets possible

### The problem PRF solves

Standard WebAuthn gives you one thing: a signature. The authenticator proves "I possess the private key" by signing a challenge. This is perfect for login. It is not sufficient for key derivation — you cannot reconstruct a wallet seed from a signature alone, because a signature over a fixed message would be deterministic and therefore leakable.

The **PRF extension** (Pseudo-Random Function, part of the WebAuthn Level 3 specification, sometimes called `hmac-secret` in CTAP2) solves this. It asks the authenticator a different question: *"given this salt, produce a keyed HMAC-SHA256 output using the authenticator's internal secret."*

Formally:

```
PRF(salt) = HMAC-SHA256(authenticator_secret, salt)
```

Where `authenticator_secret` is a value held inside the SEP, derived from the credential's private key material, that never leaves the chip. The output is 32 bytes — deterministic given the same credential and the same salt, and unguessable without access to the authenticator.

### Why this is the right primitive for wallets

| Property | Signature | PRF |
|----------|-----------|-----|
| Deterministic | No (EdDSA uses ephemeral nonce by default) | Yes |
| 32-byte output | No (signature is 64 bytes, format-dependent) | Yes (always 32B) |
| Suitable for key derivation | No | Yes |
| Requires Touch ID | Yes | Yes |
| Private key leaves chip | No | No |
| Usable as AES key material | No | Yes |

The PRF output is the substrate from which everything else in ONE's key hierarchy is derived. It is reproduced identically on every authentication — "fresh" in the sense that Touch ID must fire, but deterministic in the sense that the same finger on the same device always produces the same 32 bytes for the same salt.

### How ONE uses PRF

ONE calls the WebAuthn API with the PRF extension:

```typescript
const assertion = await navigator.credentials.get({
  publicKey: {
    challenge: crypto.getRandomValues(new Uint8Array(32)),
    allowCredentials: [{ type: 'public-key', id: credentialId }],
    userVerification: 'required',
    extensions: {
      prf: {
        eval: {
          first: new TextEncoder().encode('one.ie-wallet-v1')
        }
      }
    }
  }
})

const prfOutput = assertion
  .getClientExtensionResults()
  .prf.results.first   // 32 bytes
```

`prfOutput` is the 32-byte PRF output. It is used immediately in-memory for key derivation and is never stored, logged, or transmitted.

**Browser support:** Chrome 118+, Safari 17+, Edge 118+. Firefox has `hmac-secret` behind a flag as of 2026-Q1 — ONE ships a largeBlob fallback for browsers without PRF.

---

## 4. HKDF — deriving multiple unrelated keys from one secret

### What HKDF is

HKDF (HMAC-based Key Derivation Function) is defined in [RFC 5869](https://www.rfc-editor.org/rfc/rfc5869). It takes:

- **IKM (Input Key Material):** the secret from which to derive (in ONE's case, the 32-byte PRF output)
- **Salt:** optional randomness (ONE uses an empty salt since the PRF output is already uniformly random)
- **Info:** a context string that distinguishes derived keys from each other
- **Length:** how many output bytes to produce

The function is built on HMAC-SHA256. Its key property is **domain separation**: given `HKDF(secret, info_A)` and `HKDF(secret, info_B)`, knowing one output tells you nothing about the other, even if you know both info strings. Each derived key is computationally independent.

### ONE's derivation tree

```
PRF output (32B, hardware-bound)
│
├─ HKDF(info="wallet:sui")     → 32B wrap key → AES-GCM wraps Sui seed
├─ HKDF(info="wallet:eth")     → 32B                 → Ethereum private key
├─ HKDF(info="wallet:sol")     → 32B                 → Solana private key
├─ HKDF(info="wallet:btc")     → 32B                 → Bitcoin private key
├─ HKDF(info="api-key:owner:v1")      → 32B → bearer token (substrate owner)
├─ HKDF(info="api-key:chairman:g:X:v1") → 32B → bearer token (chairman of group X)
├─ HKDF(info="agent-key:<uid>:v1")    → 32B → KEK wrapping agent <uid>'s seed
└─ HKDF(info="vault-sync:v1")         → 32B → AES-GCM key for cloud sync blob
```

**The info strings are the security boundary.** Two users with the same PRF output (impossible, but hypothetically) would derive the same keys. Two users with different PRF outputs (the normal case) derive completely different keys across all derivations. Leaking one derived key — say, the vault-sync key — reveals nothing about the wallet key or the API key.

**Version suffixes (`:v1`)** enable rotation: when a key is rotated, the info string changes to `:v2`, deriving a new key without invalidating the derivation path for existing keys.

### Implementation

```typescript
async function hkdf(
  ikm: Uint8Array,
  info: string,
  length = 32
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    'raw', ikm, 'HKDF', false, ['deriveBits']
  )
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new Uint8Array(32),          // zero salt (PRF output already uniform)
      info: new TextEncoder().encode(info)
    },
    key,
    length * 8
  )
  return new Uint8Array(bits)
}
```

All HKDF operations run in the browser's WebCrypto API — they are not transmittable to ONE's servers.

---

## 5. AES-256-GCM — envelope encryption of the wallet seed

### Why the wallet seed is random, not PRF-derived

The Sui wallet seed is a 32-byte random value generated by `crypto.getRandomValues(32)` on first visit. It is *not* derived from the PRF. This is intentional:

1. **Existing users.** The consumer wallet launched with random seeds. Changing address derivation to PRF-based would change every existing user's address — catastrophic.
2. **Separation of concerns.** The PRF wraps the seed; it does not generate it. This means the seed can be re-wrapped for multiple devices (multiple wrappings in the `wrappings[]` array) without changing the underlying Ed25519 keypair.
3. **Latency.** WebAuthn PRF requires a user interaction (Touch ID). Requiring Touch ID on every page load to derive the seed would break zero-friction arrival. The random seed can be loaded from IndexedDB instantly; Touch ID fires only when signing.

The security property is equivalent: the seed is only accessible after a Touch ID unwrap. The unwrap path uses the PRF, so the chain is `hardware → PRF → AES key → decrypt seed`. The seed is never accessible without the hardware root.

### The wrapping operation

At State 2 (Save), the following sequence runs:

```typescript
// 1. PRF fires (Touch ID required)
const prfOut = await getPrf(credentialId, 'one.ie-wallet-v1')

// 2. Derive AES wrap key
const wrapKeyBytes = await hkdf(prfOut, 'wallet-wrap-v1')
const wrapKey = await crypto.subtle.importKey(
  'raw', wrapKeyBytes,
  { name: 'AES-GCM' },
  false,
  ['encrypt', 'decrypt']
)

// 3. Encrypt the seed
const iv = crypto.getRandomValues(new Uint8Array(12))
const ciphertext = await crypto.subtle.encrypt(
  { name: 'AES-GCM', iv },
  wrapKey,
  seed                 // 32-byte raw seed bytes
)

// 4. Store wrapping entry — plaintext seed wiped
idb.wrappings.push({ type: 'passkey-prf', credId, iv, ciphertext })
idb.plaintext_seed = null
```

AES-256-GCM provides both confidentiality and integrity. The 12-byte IV is random per-wrapping; IV reuse under the same key would be catastrophic for GCM, and the construction here ensures freshness. The ciphertext includes a 128-bit authentication tag that detects tampering.

### The unwrap / sign operation

Every signing operation:

```typescript
async function sign(txBytes: Uint8Array): Promise<Uint8Array> {
  const w = await idb.get('wallet')
  const wrapping = w.wrappings.find(w => w.type === 'passkey-prf')

  // Touch ID required — PRF fires inside Secure Enclave
  const prfOut = await getPrf(wrapping.credId, 'one.ie-wallet-v1')
  const wrapKeyBytes = await hkdf(prfOut, 'wallet-wrap-v1')
  const wrapKey = await crypto.subtle.importKey(
    'raw', wrapKeyBytes, { name: 'AES-GCM' }, false, ['decrypt']
  )

  // Decrypt seed — lives for microseconds
  const seedBytes = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: wrapping.iv },
    wrapKey,
    wrapping.ciphertext
  )

  // Import as NON-EXTRACTABLE Ed25519 signing key
  const signingKey = await crypto.subtle.importKey(
    'raw', seedBytes,
    { name: 'Ed25519' },
    false,              // extractable: false — OS-level enforcement
    ['sign']
  )

  // Zero raw bytes immediately — GC cannot be trusted to do this
  new Uint8Array(seedBytes).fill(0)

  return new Uint8Array(
    await crypto.subtle.sign('Ed25519', signingKey, txBytes)
  )
}
```

`extractable: false` is enforced by the WebCrypto implementation in the browser engine — it is not a JavaScript-layer flag. A key imported with `extractable: false` cannot be exported via `crypto.subtle.exportKey()`. An attacker with JS execution (XSS) could call `sign()` with a malicious transaction, but they could not extract the raw key bytes.

---

## 6. Ed25519 — the signing algorithm

Ed25519 is a digital signature scheme using the Edwards-curve Digital Signature Algorithm (EdDSA) over Curve25519. It produces 64-byte signatures from a 32-byte private key and a 32-byte public key.

Properties relevant to ONE:

| Property | Detail |
|----------|--------|
| Key size | 32 bytes private, 32 bytes public |
| Signature size | 64 bytes |
| Deterministic | Yes — no random nonce required per signature |
| Security level | ~128-bit (2^128 operations to forge) |
| Malleability | None (non-malleable by design) |
| Side-channel resistance | Strong — constant-time reference implementations |
| Sui native | Yes — Ed25519 is one of Sui's three supported signature schemes |

Determinism is important for wallet implementations: losing the signing nonce in ECDSA destroys the private key (as famously demonstrated in Sony PS3). EdDSA is deterministic — the nonce is derived from the private key and the message, so key exposure from a faulty RNG is not possible.

The Sui address is derived from the Ed25519 public key:
```
address = blake2b_256(0x00 || publicKey)[0..32]
```
Where `0x00` is the Ed25519 flag byte. This means the address is immutable as long as the 32-byte seed is preserved — which is the core identity guarantee ONE is built on.

---

## 7. Agent wallet architecture

### The problem with a master seed

The naive approach to giving many agents wallets is a master seed:

```
master_seed (env var)
  → HMAC-SHA256(master_seed, agent_uid) → agent_i's private key
```

This is what ONE's legacy `SUI_SEED` architecture did. The security failure is obvious: `master_seed` is a god-mode secret. Compromise of any single CF Worker's environment — via a log leak, a misconfigured secret, a supply-chain attack — compromises every agent's key simultaneously.

### The target architecture — per-agent isolation

```
owner_prf (hardware-bound, 32B)
│
└─ HKDF(info="agent-key:<uid>:v1") → agent_kek (32B, Key-Encrypting Key)
     │
     └─ AES-GCM(agent_seed, agent_kek) → ciphertext
          │
          └─ D1.agent_wallet { uid, ciphertext, kdf_version }
```

`agent_seed` is `randomBytes(32)` generated at spawn time. It is immediately wrapped under the agent's KEK and the plaintext is discarded. The ciphertext lives in D1 (Cloudflare's edge SQL database). The KEK is derived on-demand from the owner's Touch ID when needed.

**Key properties:**

- **Blast radius = one agent.** Each agent has an independent random seed. Compromising one agent's worker environment (which holds the decrypted seed at runtime) exposes that agent's key. It tells an attacker nothing about any other agent's key, because the seeds are independent random values.
- **Owner can recover any agent.** The KEK is deterministically derived from the owner PRF + agent UID. Loss of D1 (the ciphertext) does not permanently destroy the agent, but would require re-registration. Loss of the owner biometric (Touch ID + BIP39 paper) loses all agent KEKs — which is why BIP39 recovery is non-negotiable.
- **No master seed in any environment variable.** `grep -r "SUI_SEED" workers/` returns nothing. Each worker's `AGENT_KEY` env var is the decrypted per-agent seed for that specific agent.

### Peer-spawned agents (agent spawns agent)

When an agent spawns a sub-agent without human interaction:

```
child_seed = HKDF(parent_seed, info="agent:<nonce>:child")
```

The nonce is generated at spawn time and recorded in the Sui transaction that creates the child's spending cap. The parent can reconstruct any descendant's seed given its own seed and the on-chain spawn nonce — a full audit trail without requiring storage of child seeds in the parent.

Max depth is 8 levels, enforced by the Move contract (the `spawn_child` function aborts if `depth(parent_cap) >= 8`). Practical limit exists because each spend must traverse the cap tree to decrement all ancestors, and deep trees burn more gas.

---

## 8. Spending caps — Sui Move as the policy layer

### Why application-layer policy is insufficient

Consider a conventional implementation:

```
Agent calls payment API
  → API checks database: agent.daily_spent + amount <= agent.daily_limit
  → If pass: execute payment
```

This fails in several ways:
- A database race condition can allow double-spend beyond the limit
- An application bug, a compromised library, or a compromised developer can modify the check
- The limit is stored in a mutable database row — accessible to any sufficiently privileged database user
- There is no tamper-evident record of limit changes

### The Move smart contract approach

A Move smart contract is a program stored on the Sui blockchain and executed by every validator in the network when a transaction references it. The validators reach consensus on the execution result — if any of them produces a different result (because they ran different code, or because the check failed), the transaction is rejected.

The key security property: **the on-chain code is immutable**. Once deployed, the `ScopedWallet` module cannot be modified. A bug in the module requires deploying a new package and migrating cap objects — a visible, auditable operation.

The ONE spending cap Move module enforces:

```move
public entry fun spend<T>(
    cap: &mut Cap,
    coin: Coin<T>,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext
) {
    // 1. Liveness check
    assert!(!cap.paused, E_PAUSED);
    assert!(tx_context::epoch(ctx) < cap.expires_epoch, E_EXPIRED);

    // 2. Identity check
    assert!(tx_context::sender(ctx) == cap.spender, E_NOT_SPENDER);

    // 3. Daily limit check with epoch reset
    let current_epoch = clock::epoch(clock);
    if (current_epoch > cap.day_epoch) {
        cap.spent_today = 0;
        cap.day_epoch = current_epoch;
    };
    assert!(
        cap.spent_today + coin::value(&coin) <= cap.daily_limit,
        E_OVER_LIMIT
    );

    // 4. Recipient allowlist check
    assert!(
        vector::contains(&cap.allowed_recipients, &recipient),
        E_NOT_ALLOWED
    );

    // 5. Cap tree invariant — decrement all ancestors
    // (handled by parent_cap reference chain)
    cap.spent_today = cap.spent_today + coin::value(&coin);

    // 6. Execute transfer
    transfer::public_transfer(coin, recipient);
}
```

Every one of these checks runs on every validator. None of them can be skipped by the agent, by ONE's application code, or by anyone without the owner's private key to call `pause`, `revoke`, or `set_limit`.

### Cap operations and their authorisation

| Operation | Who can call | What it does |
|-----------|-------------|--------------|
| `mint(cap)` | Owner / chairman | Creates a new Cap for an agent |
| `spawn_child(parent, child)` | Cap owner | Creates a child Cap, decrements parent `daily_limit` allocation |
| `pause(cap)` | Cap owner | Sets `cap.paused = true` — all `spend()` calls abort |
| `unpause(cap)` | Cap owner | Clears pause |
| `revoke(cap)` | Cap owner | Destroys Cap object, returns remaining funds to parent |
| `rotate_spender(cap, new_key)` | Cap owner | Updates `cap.spender` — key rotation without changing limits |
| `set_limit(cap, new_limit)` | Cap owner | Adjusts `daily_limit` (bounded by parent's allocation) |
| `ping(cap)` | Cap spender | Updates `last_spender_ping` — dead-man's switch heartbeat |

"Cap owner" is the address in `cap.owner` — the human or parent agent that created the cap. This owner field is set at `mint` time and is immutable.

---

## 9. The role hierarchy and permission model

### Permission = Role × Pheromone

ONE's permission model has two components:

1. **Role** — a value on a group membership relation in TypeDB. Roles are `chairman | board | ceo | operator | agent | auditor`. A membership record with `role = chairman` inside `g:acme` gives chairman capabilities within that group.
2. **Pheromone** — the strength/resistance score on a path between two actors in the substrate. This is the learned component: paths that consistently produce results gain strength; paths that produce failures accumulate resistance.

There is no ACL table. Removing a membership removes the role. There is no cache to invalidate beyond the in-process key cache (TTL 5 minutes, plus `invalidateKeyCache()` on revoke).

### Role capabilities

| Capability | owner | chairman | ceo | operator | auditor | agent |
|-----------|-------|----------|-----|----------|---------|-------|
| Bypass scope/network/sensitivity gates | ✓ | — | — | — | — | — |
| Mint root-tier API keys | ✓ | — | — | — | — | — |
| Hire / fire agents within group | ✓ | ✓ | ✓ | — | — | — |
| Set spending caps | ✓ | ✓ | — | — | — | own children |
| Read all signals within group | ✓ | ✓ | ✓ | ✓ | ✓ | own paths |
| Read private-scope signals | sender or receiver only | sender or receiver only | — | — | — | — |
| Delete memory (GDPR erasure) | ✓ | ✓ | — | ✓ | — | — |
| Bypass rate ceiling | — | — | — | — | — | — |
| Escape audit log | — | — | — | — | — | — |

The last two rows are the most important security properties: no role — including `owner` — can bypass the rate ceiling or escape the audit log. Owner-tier actions emit `audit:owner:{action}` to a D1 `owner_audit` table *before* the bypass executes, with a `payload_hash` (SHA-256 for tamper evidence) and a `payload_redacted` (PII stripped, human-readable). `enforce` mode blocks any owner action if the audit emit fails — no bypass without a record.

### Signal scope

Signals in the substrate carry a `scope` attribute:

- `private` — visible only to sender and receiver. TypeDB queries in group context exclude them.
- `group` — visible to all members of the groups that contain both parties.
- `public` — visible across groups, hardenable to on-chain.

No server-side policy enforces this — it is structural in TypeDB: the query that lists a group's signals uses a `has scope "group"` or `has scope "public"` filter. Private signals are simply not returned by any group-scoped query, regardless of the requester's role.

---

## 10. Multi-sig for enterprise groups

For groups where a single chairman key is insufficient (high-value treasury, sensitive regulatory data, government departments), ONE supports N-of-M multisig on chairman-tier actions.

When a group is configured with `multisig: { n: 3, m: 5 }`, any chairman-tier action (agent hire, cap mint, GDPR erasure) requires 3 of the 5 designated board members to each provide a WebAuthn assertion within a 5-minute window. The assertions are collected server-side with a nonce that expires, and the action is gated on `count(valid_assertions) >= n`.

This is not multisig at the Sui Move level (which would require constructing a Move `MultiSigPublicKey` object with weighted thresholds). It is a server-side gate on the API — sufficient for enterprise use cases where the threat model is "single compromised device or coerced individual" rather than "compromised server."

For on-chain multisig (e.g. requiring 2-of-3 human biometrics before a spending cap can be unpaused), the `Cap.owner` field would be a Sui `MultiSigPublicKey` address and the `unpause` entry function would require a threshold-signed transaction. This is planned as a future enterprise capability.

---

## 11. Federation across substrates

When two organisations run separate ONE substrates and wish to exchange signals, they form a **bridge**: a cryptographic handshake that requires both owners to sign, establishing a trust boundary.

```
Substrate A (owner_A's PRF root)           Substrate B (owner_B's PRF root)
       │                                           │
       ├─ bridge handshake: owner_A signs ────────►│
       │◄─ bridge handshake: owner_B signs ────────┤
       │                                           │
       │── signal from A ──────────────────────────►
       │                        downgraded to "chairman" semantics
       │                        (not owner — A's owner is not root over B)
```

Key properties:

- **Neither owner is root over the union.** A signal from substrate-A's owner is treated by substrate-B as a foreign chairman — it passes group-scoped gates but not owner-bypass gates.
- **Bridge carries peer version.** The handshake stores `peer_owner_address` and `peer_owner_version`. If owner-A rotates their key, all bridges to A become stale. Each one requires a re-handshake — a visible, auditable event.
- **Bridge is revocable.** Either owner can unilaterally revoke a bridge with a single API call. Signals from the revoked peer return 403 after propagation (eventually consistent, ~5 seconds).

---

## 12. Key rotation

HKDF info strings include a version suffix (`:v1`, `:v2`, etc.). Rotation procedure:

1. Derive new key with bumped version: `HKDF(prf, "api-key:owner:v2")`
2. Register new key hash in the substrate: `POST /api/auth/api-keys { version: 2 }`
3. Both v1 and v2 keys are valid during a **cutover window** (default: 30 days from `issued_at` of v2, configurable)
4. After the cutover window, v1's `expires_at` passes. The key returns 401. Hash retained for forensic audit.

Rotation is:
- **Voluntary** for the substrate owner (recommended: annually or on device loss)
- **Scheduled** (90-day cycle) for chairman-tier keys
- **Immediate** on suspected compromise — `DELETE /api/auth/api-keys/:id` sets `expires_at = now`

The BIP39 paper recovery path produces the same PRF output regardless of key version, since BIP39 reconstructs the seed input → same WebAuthn credential → same PRF → same HKDF derivations. Rotation does not change the recovery procedure.

---

## 13. Threat model

| Threat | Defence | Accepted residual risk |
|--------|---------|----------------------|
| **Database/TypeDB compromise** | Server stores only `hash(key)`. No plaintext keys. | Audit log readable by attacker. Not sensitive. |
| **D1 wipe** (CF accident, failed migration) | Owner address pinned in an immutable `SubstrateOwner` Move object at first-mint. On-chain is authoritative over D1 for identity. | Agent wallet ciphertexts lost. Re-registration required. Audit history lost. Identity survives. |
| **Worker environment variable leak** | Each worker holds only its own per-agent decrypted seed (`AGENT_KEY`), not a master seed. | One agent's private key compromised. Blast radius = that agent's daily cap. No cross-agent leakage. |
| **Mac/device stolen, biometric not defeated** | Device is locked. Attacker cannot use Touch ID. Key is inside SE. | None. |
| **Mac/device stolen, biometric defeated** | BIP39 paper recovery from a secure off-site location. Rate ceiling limits burst API calls before rotation. | Window between theft and key rotation. Mitigated by monitoring `audit:owner:*` events. |
| **BIP39 paper + device both stolen** | No defence for substrate owner (single-key by design — owner accepts this). Multi-sig for enterprise chairmen (gap 3). | Owner accepts catastrophic loss. Enterprise chairmen don't — N-of-M distributes this risk. |
| **Compromised LLM (hallucination or prompt injection)** | LLM never holds signing keys. Output goes through deterministic Move cap check before any value moves. | LLM can propose a malicious transaction. It will be rejected by Move if out-of-scope. |
| **Compromised LLM DOS** | Rate ceiling per-key-hash, regardless of role. | LLM can exhaust its agent's daily API quota. Not the owner's quota; not another agent's quota. |
| **XSS / supply chain on one.ie** | State 1 (unsaved): seed in IndexedDB, readable by malicious JS. State 2+: seed behind non-extractable WebCrypto key; attacker can trigger sign but cannot extract the key. | State 1 balance cap mitigates State 1 risk. Strict CSP + SRI required. |
| **Replay of API call** | Nonce + timestamp on WebAuthn assertion. Bearer token is short-lived in-process cache (tab close = eviction). | None if nonce window is tight (<5 minutes). |
| **Hostile federated peer** | Downgraded from owner to chairman semantics. Bridge revocable in one API call. | Cross-tenant audit gap until revoke propagates (~5 seconds). |
| **Coerced biometric** | Out of scope. Architecture doesn't defend against a scenario where the attacker has physical control of both person and device simultaneously. | Accepted. Substrate owner opts out of high-coercion environments by design. |

---

## 14. The deterministic sandwich

Every LLM call in the substrate is wrapped:

```
Signal arrives
  │
  ├─ PRE: isToxic(edge)?
  │    resistance >= 10 AND resistance > 2 * strength AND total_samples > 5
  │    → dissolve (no LLM call, zero cost)
  │
  ├─ PRE: capability exists?
  │    TypeDB lookup: does the target unit have this skill?
  │    → dissolve if not found (mild warn 0.5)
  │
  ├─ PRE: cap.remaining > 0?
  │    Move state read (via Sui RPC)
  │    → reject if over cap
  │
  LLM call (the one probabilistic step)
  │
  ├─ POST: result?         → mark(edge, chain_depth)  — path strengthens
  ├─ POST: timeout?        → neutral                   — path unchanged
  ├─ POST: dissolved?      → warn(edge, 0.5)           — path weakens mildly
  └─ POST: no result?      → warn(edge, 1.0)           — path weakens fully
```

The LLM operates inside a scope determined entirely by deterministic checks. Its output can be probabilistic; its authority cannot be.

Pheromone accumulation (the `mark`/`warn` mechanism) means the substrate learns which paths are reliable over time. Toxic edges — those with high resistance relative to strength — are blocked before an LLM call is made. The LLM never sees traffic that the substrate has already learned is bad.

---

## 15. Open-source components and auditability

| Component | Location | Status |
|-----------|----------|--------|
| Move spending cap contract | `src/move/one/sources/one.move` | Open source — auditable on-chain at testnet package `0xd064...` |
| WebAuthn PRF vault | `src/components/u/lib/vault/passkey.ts` | Open source |
| HKDF derivation | `src/lib/api-key.ts` + vault code | Open source |
| Role permission matrix | `src/lib/role-check.ts` | Open source |
| TypeDB schema (ontology) | `src/schema/one.tql` | Open source |
| Engine (world + persist) | `src/engine/world.ts`, `persist.ts` | Open source |

The Sui testnet package is permanently recorded at `0xd064518697137f39a333d50f3a6066117332aeb079fc23a7617271b9ad5f4980`. It cannot be modified retroactively. Independent verification: query any Sui explorer for the package ID and inspect the modules.

---

## 16. Compliance touchpoints

| Requirement | How ONE addresses it |
|-------------|---------------------|
| **GDPR Article 17 (right to erasure)** | `DELETE /api/memory/forget/:uid` — deletes actor, signals, hypotheses, group memberships, and emits a timestamped audit record. |
| **GDPR data minimisation** | Private-scope signals not returned in group queries. PRF output never stored. No PII in derivation paths. |
| **SOC 2 Type II (access control)** | Role hierarchy in TypeDB; capability objects on Sui. Audit log for all owner-tier actions. Auditor role with read-only access. |
| **PCI DSS (payment security)** | Spending caps enforced by Move, not application code. Allowed recipient lists limit exfiltration surface. On-chain transaction record is immutable. |
| **ISO 27001 (key management)** | Key rotation on 90-day schedule for non-owner principals. Version-suffixed derivation enables seamless cutover. Rotation policy documented in `docs/key-rotation.md`. |
| **FedRAMP / government** | Sovereign deployment possible — customer runs their own TypeDB instance, their own CF Workers, their own biometric root. ONE never holds customer keys. |

---

## Appendix A — Cryptographic primitive summary

| Primitive | Standard | Key size | Use in ONE |
|-----------|----------|---------|-----------|
| WebAuthn PRF | W3C Level 3 / CTAP2 `hmac-secret` | N/A (hardware) | PRF output — root of all key derivation |
| HKDF-SHA256 | RFC 5869 | Input: 32B; Output: 32B | All key derivation |
| AES-256-GCM | NIST SP 800-38D | 256-bit key, 96-bit IV | Wallet seed wrapping, vault encryption |
| Ed25519 | RFC 8032 | 32-byte privkey | Sui transaction signing |
| PBKDF2-SHA256 | RFC 8018 | Variable | API key hash verification (server-side) |
| SHA-256 | FIPS 180-4 | N/A | Payload integrity in audit log |
| BIP39 | BIP-0039 | 128–256 bits entropy | 12-word paper recovery phrase |
| Sui secp256r1 | SEC 2 | 256-bit | Passkey native sign (co-sign pattern) |

---

## Appendix B — Glossary

**Secure Enclave Processor (SEP):** Apple's dedicated security co-processor. Generates and holds cryptographic keys that cannot be exported to any software, including the OS.

**Touch ID:** Apple's fingerprint biometric. Functions as an access gate on the SEP — correct fingerprint allows SEP to service a cryptographic request.

**WebAuthn:** W3C standard for hardware-backed authentication in web browsers. Defines the JavaScript API that ONE uses to interact with the SEP.

**PRF (Pseudo-Random Function):** A WebAuthn extension (CTAP2 `hmac-secret`) that asks the authenticator to produce a deterministic, hardware-bound HMAC output given a salt. The output is the cryptographic root in ONE's key hierarchy.

**HKDF (HMAC-based Key Derivation Function):** RFC 5869. Takes a secret and a context string (info) and produces a derived key. Domain separation: different info strings produce computationally independent keys.

**AES-256-GCM:** Authenticated encryption standard. Used to wrap the wallet seed under the PRF-derived AES key. Provides both confidentiality (attacker cannot read) and integrity (attacker cannot tamper without detection).

**Ed25519:** Elliptic-curve digital signature scheme. Used for Sui transaction signing. Deterministic, 128-bit security, no malleable signatures.

**KEK (Key-Encrypting Key):** A key used to encrypt (wrap) another key. In ONE, each agent's KEK is `HKDF(owner_prf, "agent-key:<uid>:v1")`. The KEK wraps the agent's random seed; only the ciphertext is stored.

**BIP39:** Bitcoin Improvement Proposal 39. A standard for generating human-readable mnemonic phrases (12 or 24 words) from entropy. ONE uses 12 words as a paper recovery path for the wallet seed.

**Cap tree:** The hierarchy of Sui Move `Cap` objects that bounds agent spending. Each node in the tree is enforced by consensus; parent caps decrement when children spend.

**Pheromone:** ONE's term for the strength/resistance scores on paths between actors. Analogous to ant pheromone trails — marks accumulate on successful paths, fades occur on unused paths, warnings accumulate on failed paths.

---

*ONE Engineering — one.ie/security*  
*For security disclosures: security@one.ie*
