# Wallet Architecture — Ephemeral First, Protect Later

For a browser Sui wallet where the user never sees a seed phrase, never signs in to create it, and never loses the address once they've got one. Goal: zero friction to arrive, progressive security, one address for life.

---

## The one-line summary

**Arrive → wallet exists. Tap Touch ID → wallet is safe. One seed, many wrappings, never regenerated.** Better Auth + Google handles identity (already installed); passkey is the gate on the seed; BIP39 is the paper break-glass. No zkLogin. No salt server. No vendor on the hot path.

---

## Same pattern, fourth surface

| Surface | Secret | Gate | Host | Doc |
| --- | --- | --- | --- | --- |
| Mac personal | age identity | Touch ID | Secure Enclave | `mac.md` |
| Dev secrets | vault key | Touch ID | `~/.vault.age` + SE | `secrets.md` |
| **Wallet seed** | **Ed25519 seed** | **Touch ID (after Save)** | **WebAuthn + IndexedDB** | **this doc** |
| Sui agents | agent keypair | consensus (Move) | on-chain | `agents.md` |

Structurally identical to the Mac: entropy is held, a biometric gates its use, ciphertext or signatures come out. The difference is the user walks up the staircase at their own pace — the first step is free.

### Users get the same three-store shape as developers

The `secrets.md` split (Keychain / dotenvx / vault) has a direct mirror in the browser. This is not a coincidence — same architecture, different primitives:

| Developer (native) | User (browser) |
|---|---|
| Secure Enclave age key | WebAuthn passkey with PRF extension |
| `~/.vault.age` (encrypted seed store) | Passkey `largeBlob` (encrypted wrapped seed) |
| Touch ID | Same Touch ID / Face ID via WebAuthn |
| FileVault at-rest + Apple ID Recovery Key | iCloud Keychain sync + Apple ID Recovery Key (user's ecosystem) |
| Paper 2 (break-glass age key) | 12 BIP39 words (the user's break-glass) |
| dotenvx (team repo) | N/A — user has no team store; the product's backend uses dotenvx for its own keys |
| iCloud Keychain (website autofill) | Same iCloud Keychain (where available) / Google Password Manager |

The architectural claim: **every person at one.ie — dev, team member, or end-user — owns their key material end-to-end, biometric gates usage, paper is the universal recovery.** The product backend never holds user seeds. The only difference is that developers use native SE; users use WebAuthn, which is the portable cross-browser cross-OS version of the same idea.

---

## The lifecycle — five states, one address

```
  ┌─ State 1 ─┐  "Save"   ┌─ State 2 ─┐  Google    ┌─ State 3 ─┐
  │ Ephemeral │ ───────►  │   Saved   │ ────────►  │  Linked   │
  └───────────┘  Touch ID └─────┬─────┘  OAuth     └─────┬─────┘
                                │                        │
                        new device, same ecosystem    new device, different ecosystem
                                │                        │
                                ▼                        ▼
                          ┌───────────┐            ┌─────────────┐
                          │  Multi-   │            │  Recovered  │
                          │  device   │            │  (BIP39)    │
                          └───────────┘            └─────────────┘
```

**The address is the same in every state.** The seed is generated once in State 1 and never regenerated — only re-wrapped.

### State 1 — Ephemeral (arrive, zero friction)

- User hits `/u`. Page runs `crypto.getRandomValues(32)` → seed.
- `IndexedDB[wallet] = { version: 1, seed: <32 raw bytes>, address }`, plaintext.
- Address = Ed25519 keypair from seed → `toSuiAddress()`.
- Works immediately. Can receive, view, run sponsored-tx small spends. No prompt, no login, no biometric.
- Risk surface: anything that can read same-origin IndexedDB can read the seed. Mitigation: cap what a State 1 wallet can hold or send (product decision — see `wallet.md` §State 1 spending caps).

### State 2 — Saved (opt-in Touch ID)

User taps *"Save this wallet"*. One Touch ID prompt. Three things happen:

1. **Passkey created** on this device, origin-bound to `one.ie`, with PRF extension requested.
2. **Seed wrapped** — PRF(`"one.ie-wallet-v1"`) returns 32 deterministic bytes → HKDF-SHA256 → AES-256-GCM key → encrypt seed.
3. **Ciphertext stored in the passkey's `largeBlob` extension** — *not* just in IndexedDB. iCloud Keychain / Google Password Manager sync the passkey *and* its largeBlob across the user's devices. Wallet backup comes free with passkey backup.

Then, once, the user sees **twelve BIP39 words** — the paper break-glass. They confirm by retyping one word. Seed is now double-protected: every passkey-synced device, plus paper.

IndexedDB after State 2:

```
IndexedDB[wallet] = {
  version: 1,
  address: "0x...",
  wrappings: [
    { type: "passkey-prf", credId, iv, ciphertext }
  ],
  plaintext_seed: null,     // wiped
  bip39_shown_at: "2026-..."
}
```

Every sign op from here on: Touch ID → PRF → unwrap seed → `crypto.subtle.importKey(seed, Ed25519, extractable: false)` → `crypto.subtle.sign(tx)` → wipe the raw seed bytes. The unwrapped seed has a lifetime measured in milliseconds.

### State 3 — Linked (opt-in Google)

User taps *"Sign in with Google"*. Better Auth runs its existing flow. On success:

- TypeDB gets a `unit(unit-kind="human")` via `ensureHumanUnit()` (existing code path — see `one.ie/CLAUDE.md`).
- `identity-link(subject: unit, front-door: "google")` records the link.
- The wallet address is written to the `unit` as an attribute. The passkey credId is written too.
- **No seed material ever leaves the browser.** The server never sees the seed, never sees the ciphertext, never sees the PRF output.

What Link buys the user:
- Their account follows them across devices (preferences, history, agent relationships)
- A recovery channel that isn't paper (if they lose all passkeys, Google account recovery → app recognises them → they restore from BIP39 with identity context)
- Multi-device UX hint: the app can say *"you have passkeys on Apple devices; enroll one here too"* the moment they log in on Windows

### State 4 — Multi-device

**Same ecosystem (iPhone → Mac, Android → Android laptop):** iCloud Keychain or Google Password Manager syncs both the passkey *and* the largeBlob ciphertext. User opens `/u` on the new device, OS recognises the passkey, Touch ID unwraps, wallet is live. **Zero enrollment needed** — just the natural OS sync.

**Different ecosystem (iPhone → Windows):** passkeys don't cross Apple↔Google↔Microsoft boundaries. User signs in with Google (Better Auth recognises them), app prompts *"enroll Touch ID on this device"* — but this device doesn't have the seed. Two paths:

- **v1 (simple):** user types their BIP39 phrase → seed restored → new passkey enrolled → ciphertext written to new passkey's largeBlob → now synced within the new ecosystem.
- **v2 (deferred):** server-held wrapping under a KEK released after Better Auth verify. Zero-seed-knowledge on the server; uses wrap-unwrap ceremony. Adds a Worker endpoint, adds complexity. Only if the BIP39-cross-ecosystem UX tests badly.

Both cases: address unchanged, one additional wrapping in `wrappings[]`, both devices can now sign.

### State 5 — Recovered (paper break-glass)

All devices lost, all passkeys gone, iCloud/Google sync unavailable. User visits `/u` on a fresh browser on any device. *"Restore a wallet"* → type 12 words → seed reconstructed → new passkey enrolled → wallet alive at the same address.

This is the `mac.md` paper motif. Writing down twelve words is the one moment where the product admits the word *"recovery"* to the user — after their first meaningful transaction, when there's something worth protecting. `simple.md` owns the copy.

### Cloud sync — encrypted envelope (Better Auth bridge)

When the user has a Better Auth account (password or Google), every vault mutation uploads an encrypted envelope to the server. On sign-in from a new device, the client fetches that envelope and decrypts it with the BIP-39 recovery phrase — bootstrapping the vault without waiting for the user to re-derive wallets from scratch.

```
syncKey = HKDF(masterSecret, info="vault.sync.export.v1")
blob     = AES-GCM(JSON { meta (minus passkeys), wallets }, syncKey)
```

The server stores only `blob` — a self-describing AES-GCM ciphertext keyed by Better Auth `user_id`. The sync key is derived from the vault master, reachable only via an already-unlocked session (hot re-sync) or the recovery phrase (cold restore). Server cannot read, modify, or cross-decrypt.

- **Write path:** `saveWallet` / `deleteWallet` → `notifyMutation()` → fire-and-forget `PUT /api/vault/sync` (`src/components/u/lib/vault/sync.ts`). No-op when locked or signed out.
- **Restore path:** sign-in success → `hasCloudBlob() && !hasVault()` → `CloudRestorePanel` prompts for 24-word phrase → `restoreFromCloud(phrase)` seeds IndexedDB + opens session under `method: 'recovery'`. User then enrolls a passkey on the new device (re-adds to `meta.passkeys[]`, which was stripped before upload — passkeys stay device-bound).
- **Storage:** D1 table `vault_blob (user_id PK, blob, version, updated_at)` — migration `0022_vault_blob.sql`.
- **Relation to v2 above:** this is *envelope sync* (seed-encrypted ciphertext, server has no key), not the *server-held KEK* v2 sketched in State 4. v2 remains an option for users who never wrote the phrase down.

---

## Envelope encryption — one seed, many wrappings

The seed is a 32-byte constant. Wrappings are the set of ways it can be recovered. Each wrapping is independent; any one unlocks the wallet.

```
IndexedDB[wallet] = {
  version: 1,
  address: "0x...",
  wrappings: [
    { type: "passkey-prf", credId, iv, ciphertext },   // Apple passkey
    { type: "passkey-prf", credId, iv, ciphertext },   // Windows passkey
    { type: "bip39-shown",  createdAt }                // flag only — phrase lives on paper
    // Future: { type: "server-kek", wrappedBy: "better-auth-google" }
  ],
  plaintext_seed: null
}
```

**The invariant:** a new wrapping is added whenever a new recovery path is enrolled. **A wrapping is never rewritten** — add-only. Rotation means revoking a credential *and* removing its wrapping, never changing an existing one in place.

This is the same shape as `mac.md` §Two roots, one biometric, paper resurrects — multiple independent recovery paths, biometric convenience on the common path, paper for catastrophe.

---

## Passkey's role — wrapper, not signer

In the original architecture, the passkey was the Sui signer (native `secp256r1`). In this architecture, the passkey is a **gate on the seed**, and the seed drives an Ed25519 signer.

Tradeoff explicit:

| | Passkey-as-signer | Passkey-as-wrapper (this doc) |
| --- | --- | --- |
| Key never in JS | ✓ | Only within ms during `sign()` |
| Wallet exists before enrollment | ❌ | ✓ |
| Same address across states | ❌ (rotation on enrollment) | ✓ |
| Address portability across ecosystems | via multisig | via BIP39 / sync |
| Complexity | MultiSigPublicKey, zkLogin, Enoki | one Ed25519 keypair |

We chose wrapper because **zero-friction arrival** is load-bearing for the product. The signing window is mitigated by WebCrypto non-extractable import. The seed never sits in memory outside a sign op.

---

## The signing flow (technical)

```ts
// Any sign op, State 2+
async function sign(txBytes: Uint8Array): Promise<Uint8Array> {
  const wallet = await idb.get('wallet')
  const wrapping = wallet.wrappings.find(w => w.type === 'passkey-prf')

  // 1. Touch ID → PRF output
  const assertion = await navigator.credentials.get({
    publicKey: {
      challenge: crypto.getRandomValues(new Uint8Array(32)),
      allowCredentials: [{ type: 'public-key', id: wrapping.credId }],
      userVerification: 'required',
      extensions: { prf: { eval: { first: PRF_SALT } } }
    }
  })
  const prfOut = assertion.getClientExtensionResults().prf.results.first

  // 2. Derive AES key from PRF
  const aesKey = await hkdfToAesGcm(prfOut, 'wallet-wrap-v1')

  // 3. Unwrap seed (lives for microseconds)
  const seedBytes = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: wrapping.iv }, aesKey, wrapping.ciphertext
  )

  // 4. Import as non-extractable signing key, immediately wipe raw bytes
  const signingKey = await crypto.subtle.importKey(
    'raw', seedBytes, { name: 'Ed25519' }, false, ['sign']
  )
  new Uint8Array(seedBytes).fill(0)

  // 5. Sign
  return new Uint8Array(await crypto.subtle.sign('Ed25519', signingKey, txBytes))
}
```

Five calls, no SDK glue beyond `@mysten/sui/cryptography` for formatting. No zkLogin. No Enoki. No salt server.

---

## Multi-chain via PRF — still works

Passkeys on Sui are `secp256r1`-native. For other chains, use the same PRF with a different salt:

- **Sui:** sign directly via the flow above (Ed25519 derived from seed)
- **Ethereum:** `HKDF(PRF("wallet:eth"), info="eth")` → secp256k1 private key → viem
- **Solana:** `HKDF(PRF("wallet:sol"), info="sol")` → Ed25519 → `Keypair.fromSeed`
- **Bitcoin:** `HKDF(PRF("wallet:btc"), info="btc")` → secp256k1 → noble-curves

One passkey unlocks one finger across every chain. Different salt → different, unrelated secret. Same backup story (iCloud / Google / BIP39) covers all chains at once.

**Note:** the multi-chain keys derive from PRF *output*, not from the Sui seed. That's intentional — the seed is Sui's; other chains get their own independent entropy from the same passkey root. Losing the seed but keeping the passkey loses the Sui wallet but preserves the other-chain wallets; losing the passkey loses everything unless BIP39 recovers it.

## PRF derives more than wallets — it's the substrate root

Same PRF, different salts, every key the user needs:

| Salt (HKDF info) | Derives | Purpose |
| --- | --- | --- |
| `"wallet:sui"` (or default) | Ed25519 seed wrap key | This doc — wraps the wallet seed |
| `"wallet:eth"` / `"wallet:sol"` / `"wallet:btc"` | secp256k1 / Ed25519 / secp256k1 | Multi-chain (above) |
| `"api-key:owner:v1"` | Substrate owner API key | `owner.md` — apex role bearer |
| `"agent-key:{uid}:v1"` | KEK wrapping agent's seed | `owner.md` / `agents.md` — agents the owner spawns |
| `"vault-sync:v1"` | Cloud sync envelope key | §Cloud sync above — encrypted blob to D1 |

**The architectural claim:** one biometric, one PRF, all keys. No master derivation seed, no env-var that compromises everything. Salt isolation is cheap (one HKDF call) and produces unrelated keys — leaking one tells you nothing about the others. See `owner.md` for the full algebra.

---

## Why not zkLogin

Originally this doc recommended zkLogin for onboarding. We dropped it because:

1. **Better Auth + Google is already wired** in one.ie. "Sign in with Google" is covered at the identity layer; we don't need it at the signer layer too.
2. **zkLogin needs a salt server** — a permanent-loss-stakes database we'd have to operate (see the archived `zklogin.md` for what that cost).
3. **Every zkLogin signer type adds a multisig or address migration.** Single-signer Ed25519 keeps one address forever.
4. **Zero-friction arrival is impossible with zkLogin** — OAuth redirect is required before wallet exists. The IndexedDB ephemeral seed is instant.

zkLogin is a great protocol for wallets that start at OAuth. This product starts before OAuth, so we don't use it.

---

## Recovery — five journeys

| Journey | What the user does | What the system does |
| --- | --- | --- |
| **Lost phone, same Apple ID** | Open on iPad / Mac | iCloud Keychain already has passkey + largeBlob; Touch ID → wallet live |
| **Lost all Apple devices** | New device, type BIP39 | seed restored → new passkey → wallet live; optional: Google login to relink identity |
| **Never saved (State 1) and cleared browser** | Nothing to do | wallet lost. By design — cap State 1 balances to tolerate this. |
| **Moved to Windows** | Google login → enter BIP39 | new passkey enrolled on Windows Hello; wallet alive on both ecosystems |
| **Compromised passkey** | From another device, *Settings → Devices → Revoke* | remove wrapping; if suspicion of exfil, drain seed to a new address (BIP39 on both old/new) |

Note vs `simple.md`: the Recovery story doesn't mention testnet, epochs, or signature types. Every journey is one user action and one sentence of copy.

---

## Signer composition on Sui (simpler now)

A Sui account is a single address, backed by one keypair in the common case. We use Ed25519. No multisig by default.

When multisig *is* useful:
- **Agent co-sign** (`agents.md` Pattern A) — 2-of-2 of {user_ed25519, agent_key}. User retains sole signing power; agent can only *propose*.
- **Multi-passkey "social" sharing** (future) — 2-of-3 for team-owned agent wallets.

Neither requires zkLogin. Both are plain Sui multisig over Ed25519 signers.

**The asymmetry preserved:** the passkey (SE-bound, non-transferable) is still the signer type no agent can produce. Not because the passkey signs the tx — the Ed25519 does — but because *the seed only exits encryption with Touch ID*. An agent, however clever, cannot produce the PRF output. `agents.md` §Safety floor holds.

---

## Security considerations

### The browser-app trust boundary

Worst case: one.ie JS is compromised (supply chain, XSS, DNS hijack).

- **Can:** display a fake transaction to a signed-in user, who approves with Touch ID. Same as before.
- **Can:** in State 1 (ephemeral) steal the seed directly from IndexedDB. **This is why State 1 balances must be capped.**
- **Cannot:** in State 2+, steal the seed without firing Touch ID. The passkey PRF is the gate.

The State 1 window is new surface vs the original plan. Mitigate product-side: State 1 wallets have a daily receive cap (e.g. $20), and the UI nags to Save before balance grows.

### Hardening the frontend

Same requirements as before, carried forward verbatim:
- Strict CSP — no `unsafe-inline`, no `unsafe-eval`, allowlist exact origins
- Subresource Integrity on every `<script>` / `<link>`
- `pnpm-lock.yaml` committed; `socket.dev` in CI; `pnpm audit`
- Transaction preview in human terms before the Touch ID prompt
- Origin-bound passkeys — narrowest `rpId`, no wildcard subdomains

### WebCrypto hygiene

- Always import the unwrapped seed with `extractable: false`.
- Wipe the raw bytes (`new Uint8Array(buf).fill(0)`) immediately after import.
- Never `await` external I/O between unwrap and sign — no window for interleaved JS to read the key handle.
- Never log the PRF output, the AES key, or the seed. Not even at debug level.

### What you should never do

- Store the seed in `localStorage` (serialises to string, no `fill(0)` of the store).
- Persist the unwrapped seed in any browser state — always recompute from wrapping.
- Accept a "key import" UI in the product — that's where users get phished. BIP39 entry exists on **one** page with explicit *"restore"* copy.
- Log tx details to third-party analytics with addresses or amounts intact.

---

## Browser & device support

- **Passkey + PRF:** Safari 17+, Chrome 118+, Edge 118+, Firefox 122+
- **largeBlob extension:** Chrome 105+, Safari 17+, Edge 105+. Firefox: behind flag as of 2026-Q1 — **fallback required**.
- **Fallback when largeBlob unavailable:** store ciphertext in IndexedDB, and atomically write a duplicate into a server-held blob keyed to the Better Auth user record (never touched without OAuth). **Ships day one** — reconciled with `wallet.md` which requires server-held duplicate ciphertext from day one. Atomic write contract: largeBlob + server mirror succeed together or roll back together. See `todo.md` §C.c2b / §R.1.
- **Cross-ecosystem sync:** Apple ↔ Apple only, Google ↔ Google only. Cross-ecosystem always requires BIP39 restore.

Ship a user-agent check + clean message for unsupported browsers. A broken wallet flow is worse than no wallet flow.

---

## What this replaces

- ❌ Seed phrase UX displayed up front, "write these 12 words down before you do anything"
- ❌ `localStorage` plaintext wallet state
- ❌ Custom AES + PBKDF2 vault, PRF ceremony scattered across files
- ❌ zkLogin plugin, salt server, prover, Enoki dependency
- ❌ 1-of-2 multisig address that had to coordinate two signer types
- ❌ "Export key" buttons — BIP39 on one page, on explicit user request, with copy that says *"this is your paper backup"*

---

## Open questions for the build

- [ ] **State 1 balance cap** — what's the max a not-yet-Saved wallet can hold? (Recommended: $20 equivalent; enforced server-side via sponsored-tx refusal if unfunded deposits exceed cap.)
- [ ] **Nag cadence** — after first tx? first $5? first session longer than 5 min? (Recommended: first tx, then dismissable daily until Saved.)
- [x] **largeBlob fallback** — **resolved**: ship with server-held duplicate ciphertext from day one (atomic write contract per §Browser support). Reconciles with `wallet.md`; see `todo.md` §C.c2b.
- [ ] **BIP39 UX** — 12 words or 24? confirm-one-word or type-all-twelve? (Recommended: 12, confirm-one-word, skippable with *"I'll write them down later"* that re-nags every session.)
- [ ] **State 3 server schema** — just the passkey credId and wallet address on the user record, or also the wrappings' credIds for multi-device hints? (Recommended: store credIds so "this user has passkeys elsewhere" UX works.)
- [ ] **Multi-ecosystem v2 path** — build the server-KEK wrapping, or accept BIP39-on-cross-ecosystem as v1? (Recommended: BIP39 for v1; revisit when Windows/Android share surfaces with Apple users.)
- [ ] **Agent co-sign wiring** — ed25519 Sui multisig with agent keypair is still wanted per `agents.md` Pattern A; confirm threshold & shape in `wallet.md`.
- [ ] **Recovery-phrase prompts timing** — show BIP39 at State 2 enrollment, or after first real tx? (Recommended: at State 2 — the moment they chose to protect, copy says "here's the last-resort backup.")
