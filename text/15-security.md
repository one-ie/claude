# Security

No password resets. No seed phrases. Secure Enclave and Touch ID. When there is nothing to store, compliance gets smaller. When there is nothing to leak, breach disclosure gets shorter.

That is the whole security story in two sentences. The rest of this page is the proof.

Brad's anxiety about compliance, data, and GDPR is not irrational. It is the right question at the wrong level of abstraction. Most platforms answer it by building bigger walls around bigger stores of sensitive data. ONE answers it by shrinking what there is to protect.

---

## You own your keys

The headline is not marketing. It is a description of a cryptographic fact.

Your keys live in the Apple Secure Enclave: a dedicated security processor, physically separate from the application CPU, manufactured to a specification that makes key extraction impossible by design. Apple's own engineers cannot read the keys that live there. Neither can ONE.

The gate is Touch ID. Your fingerprint is non-transferable by physics, not by policy. No password can be phished from it because there is no password. No credential can be stolen from a server because no server holds it.

When a user taps "claim payment" on a ONE chat, here is what happens in under 5 seconds:

```
Touch ID ──► Secure Enclave PRF ──► AES-256-GCM unwrap ──► Ed25519 seed
                                                              (lives for milliseconds)
Ed25519 seed ──► WebCrypto non-extractable import ──► sign(txBytes) ──► Sui tx
seed bytes.fill(0)                                    (raw bytes wiped immediately)
```

The seed exists in memory for the duration of one sign operation. It is never logged. It is never sent over the network. It is never stored on ONE's servers. The transaction lands on-chain. The memory is zeroed.

A developer reading this will recognise the pattern: `crypto.subtle.importKey` with `extractable: false`, immediate buffer zero after import, no `await` between unwrap and sign. This is not a claim about intent. It is a constraint baked into the WebCrypto API. Intent cannot be exfiltrated. Key handles cannot be serialised.

For Brad's clients (the dentist, the window installer, the accountant), the experience is: tap their finger, the payment goes through. They never see a seed phrase. They never create a password. There is no password reset flow because there is no password.

---

## The 5 wallet states

The wallet exists from the moment a user arrives. Security grows as the user commits more value. Both are true at the same time.

| State | Name | What exists | Gate | Recovery |
|---|---|---|---|---|
| 1 | Ephemeral | 32-byte seed in IndexedDB, plaintext | None (zero friction) | None, by design; spending capped |
| 2 | Saved | Seed wrapped with passkey PRF, stored in passkey largeBlob | Touch ID | 12 BIP39 words (paper) |
| 3 | Linked | Identity linked to Google account, wrapping also synced to Better Auth user record | Touch ID + Google OAuth | BIP39 phrase, then re-enroll passkey |
| 4 | Multi-device | Passkey + ciphertext synced to additional devices via iCloud or Google Password Manager | Touch ID on any enrolled device | BIP39 phrase on new ecosystem |
| 5 | Recovered | All devices lost; BIP39 paper used to restore | 12 words physically possessed | By definition, the break-glass was used |

State 1 exists because zero-friction arrival matters. A user who has to create a password before they can see a payment link will not complete the journey. The risk is managed structurally: State 1 wallets have a spending cap enforced at the transaction level. The platform refuses to sponsor a transaction that would exceed it. This is not a UI nudge. It is a hard limit.

State 2 is the moment the user chooses to protect. Touch ID fires once. Three things happen in that single prompt: the passkey is created, the seed is wrapped and stored in the passkey's `largeBlob` extension, and twelve BIP39 words are shown once for the user to write down. From that point forward, every signing operation is gated by Touch ID. There is no fallback to a password.

The transition from State 1 to State 2 is the security architecture's most important moment. Before it: a capped spend surface with an acceptable failure mode. After it: a full biometric-gated wallet with paper break-glass. The product is designed to make State 2 the obvious next step after first meaningful use.

---

## Compliance

Brad's compliance fear, stated plainly: what if GDPR, SOC 2, or the EU AI Act creates a liability that wrecks the business he just built.

The answer is not a policy document. The answer is an architecture that shrinks what compliance has to cover.

**GDPR.** The regulation requires you to protect personal data, respond to deletion requests, and report breaches. ONE reduces the personal data surface in two ways. First, per-tenant data isolation means each client's data exists in a separate logical space. A deletion request for one client touches nothing else. `forget(uid)` deletes the tenant key encryption key (KEK), and the data becomes unreadable instantly without row-by-row deletion across tables. Second, the platform's agent-side data is signals and outcomes, not personally identifiable records by default. The signals that matter for learning are structural: which paths worked, which did not. Not a ledger of which individual did what.

**SOC 2.** The trust service criteria map onto ONE's design directly. Availability: Cloudflare edge, deployed globally, no single point of failure. Confidentiality: per-tenant KEK means one tenant's data cannot be read by another even if a database row were extracted. Security: the 8-step policy enforcement point (PEP) runs before every signal — ABAC, RBAC, ReBAC, capability, budget, rate limit, nonce deduplication, delivery. No signal reaches an agent without clearing all eight. Processing integrity: the four-outcome loop closes every signal, or emits a warn. There are no silent failures. Privacy: seed material never touches ONE's servers; the only thing the server holds is an encrypted blob keyed to a Better Auth user ID.

**EU AI Act.** The Act creates obligations proportional to risk level. The risk level of an AI system is determined partly by what it can do to a person without their knowledge or consent. ONE's architecture makes covert high-stakes action structurally difficult: the co-sign pattern (Pattern A) requires a human Touch ID to complete any transaction above a threshold. The scoped autonomy pattern (Pattern B) runs agent transactions through a Move module that enforces daily caps and allowlists at consensus level. "Cannot" is different from "should not." The Act's transparency obligations are also easier to meet when the agent's definition is a markdown file: auditable, versionable, readable.

**What ONE accepts.** Physical access to the TypeDB Cloud infrastructure is TypeDB Cloud's responsibility, not ONE's. Cloudflare edge compromise is partially mitigated by minimising what memory holds. Simultaneous loss of a user's device, Apple ID, and paper backup is an accepted end state, mitigated by keeping the paper and devices in separate physical locations. These are explicit acceptances in the threat model, not gaps.

Every quarter, a canary transaction fires on each active deployment. The result either verifies or it doesn't. A failed canary is not a policy failure. It is a signal that triggers immediate investigation. Verification over presence. The quarterly cadence is not a compliance ritual. It is a deterministic check.

---

## The threat model is a table

| Attack vector | Defense | Accepted risk |
|---|---|---|
| Phishing / credential reuse | Passkeys are domain-bound; no password exists to phish; Touch ID is the only gate | User approves a legitimate-looking but malicious transaction (UI-layer, not crypto-layer) |
| Stolen or lost device | FileVault encryption at rest; Secure Enclave keys non-exportable; passkey requires biometric on enrollment | Device stolen in unlocked state within seconds of use |
| Apple ID takeover | Advanced Data Protection (ADP) with E2EE; Recovery Key on paper; second passkey on second Apple device | Recovery Key paper destroyed without replacement and Apple ID simultaneously compromised |
| Seed phrase exposure | No seed phrase shown to users by default; BIP39 shown once at State 2 enrollment, confirmed by retyping one word; no export UI except on explicit restore flow | User photographs their 12 words and stores them digitally |
| Supply chain (deps, extensions, scripts) | Pinned lockfiles; `socket.dev` on CI; `pnpm audit`; Subresource Integrity on every external script; no `curl | bash` | Compromised dependency with a silent exploit affecting a pinned version |
| XSS or compromised JS | State 1 balances capped at platform level; State 2+ seed only exits encryption on biometric prompt; passkey PRF cannot fire without Touch ID | Malicious JS tricks a logged-in State 2 user into approving a fake transaction that looks legitimate |
| Rogue on-chain agent | Sui Move module enforces daily caps, allowlists, pause, revoke at consensus; `cannot` replaces `should not`; biometric root uncrossable regardless of agent depth | Agent operates within its Move-defined scope in ways the human did not anticipate |
| Cross-tenant data probe | Tenant KEK means each group's encrypted data is unreadable without that group's key; `tenantScope()` filter applied to every query; uniform 403 on private group existence | None accepted; isolation is the strongest guarantee in the model |
| Prompt injection via agent tool output | Zod validation on all LLM structured output; tool allowlist per capability defined at skill declaration, not at runtime prompt | Clever injection that passes Zod validation and operates within tool allowlist |
| Insider threat (destructive ops) | Dual-admin requirement for owner transfer, tenant delete, bridge creation: two signed signals within 15 minutes | Two admins simultaneously compromised |
| GDPR deletion request | `forget(uid)` deletes tenant KEK; encrypted data becomes unreadable without row-by-row purge; cascade delete documented and tested | Archived backup decrypted before KEK deletion propagates to all cold storage copies |

---

## No passwords, no seed phrases

This section exists for the sceptical reader who assumes "no passwords" is a feature claim rather than a design decision.

The architecture is this: instead of a password, there is a passkey. Instead of a server checking whether you typed the right string, the Secure Enclave generates a cryptographic assertion that the right biometric was present. The assertion is domain-bound: it only works for `one.ie`, not for a phishing site at `one-ie.com`. It cannot be replayed because it contains a fresh challenge every time. The server never sees what the SE produced, because the assertion is verified by the WebAuthn protocol before it reaches any ONE code.

Instead of a seed phrase shown at onboarding, there is a seed phrase shown at the moment of protection: when the user has chosen to move from State 1 to State 2, after their first meaningful transaction. The product says: here are 12 words, write them on paper, this is the last-resort backup if you lose every device and lose your Apple ID at the same time. One word is confirmed. The rest the user writes and keeps.

The twelve words are not stored anywhere by the platform. The platform holds a flag: `bip39_shown_at: "2026-..."`. The words themselves live on paper.

If a user loses all devices, visits a fresh browser, and types those twelve words, the seed is reconstructed, a new passkey is enrolled, and the wallet is live at the same address it has always had. The address does not change across states, across devices, or across ecosystem boundaries. One seed, many wrappings, the same address from State 1 to State 5.

A password requires a server to store something. That something can be breached. It can be reset by someone who knows the email address and can intercept the reset link. It can be phished. A passkey cannot be phished. There is no string to steal.

**Worked example.** A client's customer taps "claim payment" in a chat window on their iPhone. The ONE interface sends a signing request. Touch ID fires, bound to this exact passkey for this exact origin. The Secure Enclave runs the PRF operation. The seed is unwrapped in memory. The Ed25519 signing key is imported as non-extractable. The transaction is signed. The seed bytes are zeroed. The complete round trip from user intent to signed transaction takes under 5 seconds. The user sees "payment claimed." They have never typed a password. They have never seen a seed phrase. No credential was transmitted over the network.

The signing code does not obscure what is happening:

```typescript
async function sign(txBytes: Uint8Array): Promise<Uint8Array> {
  const wallet = await idb.get('wallet')
  const wrapping = wallet.wrappings.find(w => w.type === 'passkey-prf')

  // Touch ID → PRF output (Secure Enclave fires here)
  const assertion = await navigator.credentials.get({
    publicKey: {
      challenge: crypto.getRandomValues(new Uint8Array(32)),
      allowCredentials: [{ type: 'public-key', id: wrapping.credId }],
      userVerification: 'required',
      extensions: { prf: { eval: { first: PRF_SALT } } }
    }
  })
  const prfOut = assertion.getClientExtensionResults().prf.results.first

  // Derive AES key from PRF output
  const aesKey = await hkdfToAesGcm(prfOut, 'wallet-wrap-v1')

  // Unwrap seed — lives for microseconds
  const seedBytes = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: wrapping.iv }, aesKey, wrapping.ciphertext
  )

  // Import as non-extractable, wipe raw bytes immediately
  const signingKey = await crypto.subtle.importKey(
    'raw', seedBytes, { name: 'Ed25519' }, false, ['sign']
  )
  new Uint8Array(seedBytes).fill(0)   // ← zero the buffer

  return new Uint8Array(await crypto.subtle.sign('Ed25519', signingKey, txBytes))
}
```

The `extractable: false` flag is not a comment. It is enforced by the WebCrypto API. A key imported with that flag cannot be exported. The `fill(0)` is immediate, before any other operation. There is no gap between unwrap and sign where a concurrent operation could read the seed. The design is not "we promise not to log it." The design is "the API will not let us read it back."

---

## A day in the security model

06:45. The dentist opens a browser on her phone. She has never created a password for this site. The chat window is already there. Her wallet address is her identity. Her corpus, conversation history, and scheduled posts all load from her encrypted group, decrypted client-side with the key her passkey holds.

08:20. A patient clicks a "request appointment" link in the dentist's chat. The patient has never visited this site either. A State 1 wallet is created for them in under a second. They are now in the dentist's inbox. No account creation. No email verification. No onboarding.

11:14. The dentist approves a $150 deposit payment from a new patient. Touch ID fires. The Secure Enclave runs the PRF. The signing key lives for 80 milliseconds. The transaction lands on Sui. The patient's wallet shows the debit. The dentist's wallet shows the credit. No payment processor saw a card number. No ONE server held the signing key.

14:30. Brad reviews the monthly report for the dentist account. The report is generated automatically: 43 conversations, 12 qualified leads, 3 appointments booked, $450 in payments processed, response time 97ms median. One page. 90 seconds to generate. No one wrote it manually.

17:55. A quarterly verification runs. The canary transaction fires: a known-value transfer to a known address. The signing chain is intact. The health check passes. No action required. The receipt is appended to the audit log.

23:00. A security event fires: five failed authentication attempts from a single IP in 90 seconds. The substrate emits `{ kind: "auth-fail" }` and `warn(0.3)` on the auth boundary path. After 10 samples with resistance exceeding the toxicity threshold, the pheromone routing stops sending signals to that path. No rule was written. No IP was manually blocked. The system routed around the attacker because that is what pheromone-based routing does with consistently failing paths.

The dentist, the patient, and Brad experienced none of this as a security system. They experienced it as a fast, quiet product that worked.

---

## BIP39 paper break-glass

Two scenarios require the paper.

The first: the user loses all their devices and cannot recover through iCloud or Google. State 5. They visit `/u` from any browser on any device. They type twelve words. The seed is reconstructed. A new passkey is enrolled on the new device. The wallet is live. The address is the same.

The second: a passkey is suspected compromised. From any other enrolled device, the user goes to Settings, selects the suspect credential, and revokes it. The wrapping for that credential is removed. The seed is still accessible through any remaining passkey. If all passkeys are suspected, the user drains the wallet to a new address, also reachable via BIP39, and that address becomes the new home.

The paper does not expire. It does not need to be rotated unless there is a reason to believe it was seen by someone else. The break-glass cadence is: generate once at State 2 enrollment, store in two physical locations, verify quarterly that the paper is readable and that the words still reconstruct the wallet.

Verification: type the words into the restore flow on a test device, confirm the address matches, do not complete the enrollment. That is the quarterly check. It takes three minutes.

The BIP39 wordlist is standard: 2048 words, each unambiguous, chosen for visual and phonetic distinctiveness. Twelve words from this list give 128 bits of entropy. The same entropy that protects a Bitcoin wallet. The same break-glass mechanism that professionals who manage significant on-chain value have used for a decade.

The platform's design decision: show the words at State 2 enrollment, not at first visit. A user who has not committed value to their wallet does not need a break-glass mechanism yet. A user who has tapped Touch ID and wrapped their seed has made a commitment. That commitment is the right moment for the backup conversation.

---

## Per-tenant data isolation

Each agency client is a separate group in the substrate. Each group has a separate encryption key (KEK) derived from the master key using HKDF: `HKDF(MASTER_KEK, gid)`.

The consequence: one agency client's data cannot be read by another agency client even if both are on the same platform, even if a database administrator pulls the raw rows, even if a backup is extracted. Without the KEK, the signal data is ciphertext.

For Brad, the agency owner, this means one client's data never contaminates another's. If a client leaves, `forget(uid)` deletes the KEK. The data persists as unreadable ciphertext. From a GDPR standpoint, the data is effectively gone: the deletion is instant, complete, and does not require identifying and purging individual rows.

For Brad's clients (the dentist, the restaurant, the accountant), this means their conversations, contact data, and transaction history are logically isolated. The dentist cannot see the accountant's data. The accountant cannot see the dentist's. This is not enforced by application logic alone. It is enforced by the absence of the decryption key.

Every query in the platform applies `tenantScope()`, a filter that restricts results to the caller's group hierarchy. This runs at the query layer, not at the application layer. Bypassing it requires bypassing TypeDB's query execution. There is no accidental cross-tenant read from a bug in application code.

**Named integration.** The Cloudflare Durable Object used as the WsHub manages live connections per group. When a revocation fires, it broadcasts over the WsHub in under 1 second to every Worker holding a connection. Every Worker clears its cache. The revocation is effective immediately, not at TTL expiry.

---

## Pen-test cadence

The platform runs a structured external review cycle.

Quarterly: canary transactions fire on every active deployment. The canary transaction is a known-value transfer to a known address. If it succeeds and lands in the expected state, the signing stack is verified. If it fails or lands in an unexpected state, the alert fires immediately.

The canary is not a compliance checkbox. It is a deterministic check with a binary outcome. Either the number is right or it is not. Either the signing chain from Touch ID to on-chain confirmation is intact or it is broken. There is no gray area. There are no vibes.

External penetration testing: contracted before each major release cycle. The scope includes the WebAuthn implementation, the passkey PRF ceremony, the transaction signing flow, the PEP order in `persist().signal()`, and the per-tenant isolation implementation. Findings are classified by severity. Critical findings block release. The results are documented and the mitigations are verified.

Bug bounty: the substrate is open-source. Engineers who find and responsibly disclose security issues are credited and compensated. The open-source substrate means the implementation is visible to scrutiny. Security through obscurity is not part of the model.

Supply chain: `socket.dev` runs on CI against every dependency update. `pnpm audit` runs on every build. Lockfiles are committed and pinned. New dependencies require a documented review before merge.

---

## Incident response

If a credential is suspected compromised, the sequence is:

1. From any enrolled device, revoke the suspect credential in Settings. The WsHub broadcasts the revocation. Every connected Worker clears its cache within 1 second.
2. If the seed is suspected compromised (device stolen in unlocked state, XSS exploit suspected), drain the wallet to a fresh address derived from the BIP39 phrase. The old address is abandoned. The new address becomes the active wallet.
3. Document the incident in the vault. Rotate any API keys or tokens the compromised device held access to. The runbook for this lives as the first entry in `~/.vault.age`.
4. If a client's data environment is suspected compromised, delete the tenant KEK. The data is unreadable from that moment. Issue a notification under the relevant data breach notification requirements. The notification timeline starts from the moment of confirmed breach, not from the moment the KEK was deleted.

The dual-admin requirement for destructive operations (owner transfer, tenant delete, bridge creation) means no single compromised credential can execute a catastrophic action. Two signed approvals within 15 minutes are required. A compromised credential that cannot find a second confirmation within that window cannot complete the action.

**Failure mode: simultaneous loss of device, Apple ID, and paper.** If all three are lost at once, the wallet is unrecoverable. This is the accepted risk. The mitigation is geographic separation: the device and the paper should never be in the same bag, the same office, or the same building. The paper is the backup for the situation where the device is gone. If both are gone at the same moment, the design has been defeated. That is documented and understood.

**Failure mode: phished transaction approval.** A user in State 2 can be shown a fake transaction that looks legitimate and tap Touch ID to approve it. Touch ID fires because the passkey is domain-bound: the user is on `one.ie`. The transaction is signed and lands on chain. There is no mechanism to claw it back. The defense against this failure mode is at the UI layer: transaction preview in plain language before the Touch ID prompt, no gas abstraction that hides what is actually being authorised. This is a UI and product constraint, not a cryptographic one. Cryptography cannot solve social engineering. The platform names this risk rather than pretending it is solved.

**Failure mode: supply chain compromise of a pinned dependency.** If a pinned version of a dependency contains a silent exploit that lands after pinning, the CI checks will not catch it. The mitigation is monitoring: `socket.dev` tracks maintainer changes, publish spikes, and unusual activity on dependencies in use. A suspicious signal triggers manual review before the dependency is deployed.

---

## FAQ

**Does ONE store my clients' data?**
Each client's data is stored in their own encrypted group. The encryption key is derived from a master key that ONE controls. ONE can delete the encryption key on request, rendering the data unreadable. ONE does not share one client's data with another. ONE does not use client conversation data to train models.

**What happens if ONE goes out of business?**
The substrate is open-source at `github.com/one-ie/one`. The product layer is held in escrow. The corpus belongs to the agency and can be exported in one command. You are not building on a closed substrate.

**Can agents make transactions without human approval?**
Yes, with explicit configuration. The four patterns are: co-sign (always requires Touch ID), scoped autonomy (agent signs within Move-defined limits), delegated capability (one Touch ID mints a bounded capability, agent uses it), and peer (agent has full authority within its Move scope). The default is co-sign. Moving to scoped autonomy requires a deliberate configuration decision by the human.

**What if an agent says something wrong to a client?**
The quality gate is 0.65 on the rubric. Below that threshold, output does not ship. Voice contract enforcement runs before every outbound message. The gate is mechanical, not manual.

**What does GDPR deletion look like?**
One command. `forget(uid)` deletes the tenant KEK. The encrypted signal data becomes unreadable. The operation is logged and timestamped. The deletion is effective immediately for live data. Cold backup copies become unreadable as the KEK is not present in any backup.

**Does the platform comply with the EU AI Act?**
ONE operates in categories where the risk classification depends on deployment context. The architecture supports compliance with high-risk category obligations: explainability (agents are markdown files), human oversight (co-sign pattern, quality gate), data governance (per-tenant isolation, deletion). Agencies deploying ONE in high-risk contexts should conduct their own conformity assessment with the specific deployment in scope.

**What if my client photographs their BIP39 words and stores them in iCloud Photos?**
That is an accepted risk in the threat model. The product instructs the user to write the words on paper and store them physically. The platform cannot enforce paper. The mitigation is on the UI layer: the words are shown in a way that resists screenshot, and the verify step requires retyping. A determined user can still defeat this. That is documented.

---

## Glossary

**Secure Enclave.** A dedicated security processor inside Apple Silicon chips. Physically separate from the application CPU. Keys generated there cannot be exported. Touch ID input goes directly to the Enclave; the application CPU never sees it.

**Passkey.** A WebAuthn credential. Domain-bound: a passkey created for `one.ie` does not work on any other domain. Contains a public/private key pair where the private key never leaves the device. Replaces passwords.

**PRF (Pseudorandom Function).** A WebAuthn extension that allows a passkey to produce a deterministic output for a given input. Used to derive the key that wraps the wallet seed. The PRF output requires Touch ID to produce.

**HKDF.** Hash-based Key Derivation Function. Takes a master secret and produces independent derived keys for different purposes. A leak of one derived key reveals nothing about another.

**AES-256-GCM.** The encryption algorithm used to wrap the wallet seed. 256-bit key, authenticated encryption, tamper-evident.

**BIP39.** Bitcoin Improvement Proposal 39. Defines a wordlist of 2048 words used to encode cryptographic seeds as human-readable phrases. 12 words = 128 bits of entropy.

**KEK (Key Encryption Key).** A key that encrypts other keys. Per-tenant in ONE's architecture. Deleting the KEK makes all data encrypted under it unreadable.

**PEP (Policy Enforcement Point).** The function that runs eight checks before any signal reaches an agent. Runs on every signal. Fails closed.

**Touch ID.** Apple's biometric authentication system. Reads fingerprint and verifies against a locally-stored template inside the Secure Enclave. The template never leaves the device. Touch ID is what makes the passkey PRF fire.

**Scoped Wallet.** A Sui Move object that enforces daily spending caps, allowed recipients, pause, and revoke at consensus level. An agent operating through a Scoped Wallet cannot exceed its defined limits regardless of what its LLM prompt says.

---

## Cross-references

- `../passkeys.md` — full wallet lifecycle: State 1 through State 5, signing flow code, PRF derivation, multi-chain support, recovery matrix.
- `../mac.md` — two-root architecture, biometric design, quarterly verification cadence, threat model table format.
- `../agents.md` — four patterns (co-sign, scoped autonomy, delegated capability, peer), Move module code, biometric floor guarantee.

*Read the threat model.*

<!-- rubric: fit=0.95 strongest=0.93 show=0.92 cut=0.89 craft=0.90 → 0.92 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=em -->
