# Security Copy — "Humans are proven by biometrics"

**The reframe:** This is not primarily a story about keeping keys safe.
It is a story about **identity**.

For the first time in digital history, you can prove that a specific human being
was physically present when a digital action was authorised.
Not a password — transferable, guessable, stolen in breaches.
Not a certificate — copyable, revokable by a third party.
A fingerprint on a chip that cannot leave the chip.

Every transaction in ONE traces back to a biometric moment.
That changes everything: legal standing, governance, liability, compliance.
"I didn't authorise that" stops being a defence.
"Who authorised this?" stops being a question.

---

## The core insight — one sentence for each audience

**CEO:** For the first time, every digital action in your company has a provable human behind it.

**Legal:** A Touch ID signature is non-repudiable. The Secure Enclave records who was physically present. That is admissible.

**Compliance:** Every transaction in the system traces to a biometric root. KYC is baked into the cryptographic layer, not bolted on.

**Developer:** The private key is hardware-bound and non-extractable. The signing event is a proof of physical presence, not a proof of password knowledge.

**Agent:** My authority traces to a human who was physically there when they gave it to me. That human set my spending limit with their fingerprint. I cannot exceed it. The blockchain enforces it. My actions are theirs, bounded.

---

## Hero

### Headline (A/B options)

1. **Prove the human. Then trust the agent.**
2. **Every digital action, traced to a fingerprint.**
3. **For the first time: a digital signature that proves you were there.**
4. **Your fingerprint is a legal signature. Now every agent action has one at its root.**

### Subhead

> Touch ID doesn't just unlock your wallet. It proves you authorised everything that follows.
> Every agent you spawn, every transaction they make, every decision they take —
> traces back through the blockchain to the moment your fingerprint touched the chip.
> That's not a security feature. That's a new kind of accountability.

### The shift (below the fold, first paragraph)

Traditional digital identity is a claim. A password says "someone who knows this string is authorised." A token says "someone who possesses this credential is authorised." Claims can be transferred, stolen, forged.

Biometric identity is a proof. Touch ID on Apple's Secure Enclave says "the person whose fingerprint is enrolled on this chip was physically present at this moment." That proof is generated inside hardware that cannot be remotely accessed, cloned, or socially engineered. It cannot be delegated. It cannot be forwarded. The only way to produce it is to be there.

ONE builds everything on that proof.

---

## Section 01 — The human is proven

### Headline
**"I didn't authorise that" is no longer a viable defence.**

### Body
When you act in ONE — create an agent, set a spending limit, sign a transaction — your finger touches Touch ID. Apple's Secure Enclave, a dedicated security chip inside your device, produces a cryptographic proof that you were physically present.

This proof is:
- **Non-transferable.** You cannot email your fingerprint to a colleague. You cannot copy-paste it. The chip produces the proof only when the enrolled biometric is present.
- **Non-forgeable.** The Secure Enclave's private key is generated at device manufacture and is architecturally isolated from all software — including the operating system. No amount of server compromise, social engineering, or credential theft can produce a valid fingerprint proof without the actual finger.
- **Recorded.** Every biometric authentication is tied to a transaction, a timestamp, and an on-chain record. The audit trail does not say "someone with the API key did this." It says "the person enrolled at this Secure Enclave authorised this at this moment."

### The legal dimension
In most jurisdictions, a digital signature backed by a strong authentication mechanism — one that uniquely identifies the signer, is under their sole control, and is linked to the signed data — meets the standard for an electronic signature with legal standing equivalent to a wet signature. Touch ID on Secure Enclave meets all three criteria. The implications for corporate governance, financial authorisation, and regulatory compliance are significant.

### What this replaces
| Old model | New model |
|-----------|-----------|
| "Someone with this password did this" | "This human was physically here" |
| Repudiable ("my password was stolen") | Non-repudiable ("my fingerprint fired") |
| Identity is a string | Identity is physics |
| Trust-me audit trail | Cryptographic proof |
| Compliance bolted on | KYC at the cryptographic root |

---

## Section 02 — The authority chain

### Headline
**Every agent action traces back to a human who was there.**

### Body
When you give an AI agent a spending limit in ONE, you are doing something new in the history of digital systems: you are signing a bounded power of attorney with your biometric. The blockchain records it. The Move smart contract enforces it. The agent can act within those bounds — and cannot act outside them, regardless of what its AI model tells it to do.

The chain is:

```
Your fingerprint (Secure Enclave, non-transferable)
  ↓ proves your presence
Your spending cap transaction (signed, on-chain)
  ↓ authorises the agent
Agent's wallet (random seed, wrapped under your biometric-derived key)
  ↓ bounded by the cap you set
Agent's sub-agents (if any — each bounded by their parent's remaining cap)
  ↓
Every transaction across the entire tree
  ↓ traces back to you, with your biometric signature
```

When a regulator asks "who authorised this payment?" — the answer is a cryptographic chain, not a policy document. When an auditor asks "who hired this agent?" — the answer is a biometrically-signed transaction record. When something goes wrong — "who is accountable?" — the chain points to a human who was physically present when they set the limits.

This is what accountability means when it is built into the substrate rather than bolted onto it.

### Agents are economic peers, not delegates
This matters: agents are not acting "as" you. They are acting within bounds you set. They have their own wallets, their own addresses, their own keys. When an agent makes a payment, it signs with its own key — not yours. But the cap that permits that payment was signed by you. And the key that wraps the agent's seed was derived from your biometric.

The authority chain is real. The agent is not pretending to be you. It is an authorised actor whose authorisation traces back to you, provably and irreversibly.

---

## Section 02b — Agent autonomy and the approval flow

### Headline
**Agents run freely. Exceptions need a fingerprint.**

### The setup (one paragraph)
You set the rules once — with your biometric. Your agent operates freely inside them, around the clock, no approval needed. When it needs to do something outside those bounds, it pauses, sends you a precise notification, and waits. You review. You Touch ID. The specific transaction the agent described executes. Nothing else.

### The three zones
Every agent action falls into one of three zones. The zones are drawn by the cap you signed — not by our servers, not by the agent itself.

**Autonomous zone:** Amount within daily cap. Recipient in your approved list. Action within permitted set. Cap not expired or paused. Agent acts. No human needed.

**Approval zone:** New recipient. Amount above daily cap. Spawning a sub-agent. Changing cap structure. Agent requests. You Touch ID.

**Hard stop:** Cap paused, total remaining exceeded, parent cap expired. The Move contract blocks at consensus. The agent cannot act regardless of what its model says, what we configure, or what anyone instructs it to do.

### What the approval feels like (for the CEO)
You receive a notification: "treasury-ops needs approval." You tap through to a card. It shows you: the action (send payment), the recipient (Acme Suppliers Ltd, new — highlighted), the amount (€12,400), the agent's reason (monthly SLA settlement, invoice #847), how much of the daily cap this uses (82%). One button: Approve with Touch ID. One disclaimer: "Approving signs the exact transaction above. Nothing else."

That is the entire flow. Notification → review card → one gesture. No second screen, no confirmation dialog.

### Why it's deterministic (for the legal team)
The agent builds the full transaction before asking for approval. What appears on your review card is the transaction — not a description of it, not a summary that could be interpreted loosely. When you Touch ID, the Secure Enclave signs that transaction and it is submitted directly to the blockchain. The transaction is hash-locked in escrow from the moment the agent submits the request: it cannot be modified, swapped, or extended after your signature. What you approved is what executed. Exactly.

### What happens if you reject or ignore
Reject sends the agent a dissolved signal — the task breaks cleanly, nothing is submitted. Ignore lets the request expire — same result. At no point does inaction accidentally approve anything. The default is always no. The system is designed so that a compromised notification infrastructure cannot trick you into approving by silencing the notification: no Touch ID means no transaction.

### Sub-agent spawning (the recursive case)
When an agent wants to create a child agent, it also needs approval. You see: agent name, model, permitted skills, spending cap (which must be a subset of the parent's remaining cap), and expiry (which cannot outlive the parent's cap). Approve → child spawned with its own key, wrapped under your biometric-derived key-encrypting key. Its cap is a Move Cap object, child of the parent's. The chain: your fingerprint → parent cap → child cap → every transaction that child ever makes.

### The one-line version
> You set the rules with your fingerprint. Your agent runs. Exceptions come back to you as a specific transaction you approve by touching a chip. The blockchain runs it. Verbatim.

---

## Section 03 — What this means for your organisation

### For boards and governance
Every board resolution, every major financial authorisation, every governance action can now carry a biometric proof that the person voted. Not "the person's device voted." Not "the person's account voted." The person. Their fingerprint on their enrolled chip.

Multi-sig extends this: require three of five board members to biometrically confirm before an action executes. No single compromised device, no single coerced individual can act alone. Governance has a physics layer.

### For compliance and audit
Your entire agent fleet's activity traces to biometric authorisations. An auditor can follow any transaction to the human who authorised the limits that permitted it. GDPR erasure is a signed action. KYC is at the root, not the edge. The audit trail is on-chain — immutable, not held by us.

### For finance and treasury
An agent with access to your treasury is a liability. An agent with access to your treasury, whose spending limit was set with your CEO's biometric signature, whose allowed recipient list was signed by your CFO, and whose pause trigger fires the moment any of them calls it — that is a controlled, auditable, legally-grounded instrument.

### For governments and sovereigns
Sovereign deployments run their own substrate — their own biometric root, their own key hierarchy, their own TypeDB instance. We never touch the keys. Every action taken in the system traces to a biometrically-proven human in their organisation. Federation with other agencies requires a biometric handshake from both sides. There is no "trust the vendor" anywhere in the chain.

---

## Section 04 — The safety properties (downstream of the insight)

These are consequences of the biometric root — not the primary story.

### Wallets
Wallet seeds are wrapped under keys derived from biometrics. There is no plaintext key on our servers because there is nothing to store: the key is derived fresh each time Touch ID fires. A server breach yields scrambled hashes.

### Agents
Per-agent isolated seeds, each wrapped under a biometric-derived key-encrypting key. Compromising one agent's environment compromises that agent. The fleet is isolated because each key traces to a different derivation path from the same biometric root.

### Spending caps
Enforced by Sui Move consensus. The contract does not know or care about our servers. It knows the rules you set when your finger touched the chip. Those rules run on 100+ validators simultaneously.

### Recovery
Twelve words on paper reconstruct the same biometric-derived key hierarchy on any new device. Not because we gave you a backup — because the hierarchy is derived from an input you control.

---

## Section 05 — FAQ for the sceptical CEO

**"Biometrics can be faked."**
Lab-scale attacks on biometric sensors exist. They require physical access to the enrolled device and significant resources. They are not practical attacks against business or government deployments. The more relevant comparison is not "biometrics vs. perfect" but "biometrics vs. passwords" — and on that comparison, there is no contest.

**"What if I lose my device?"**
Twelve words on paper recover the same key hierarchy on a new device. Same wallet address, same agent authorisations, same spending caps. The biometric proof regenerates on the new device. You enrol once; you recover from paper.

**"Can an agent impersonate me?"**
No. Agents have their own keys, derived from their own seeds. They do not sign with your key. They sign with their key, within the bounds your biometric authorised. Your Secure Enclave does not know about agents at all — it knows about you, and you gave those agents their limits.

**"Is this legally binding?"**
The architecture meets the technical criteria for a qualified electronic signature in most jurisdictions (sole control, uniquely identifies, linked to data, tamper-evident). You should verify with your legal counsel in your jurisdiction. The technical properties are not in doubt; the legal interpretation is jurisdiction-specific.

**"What if someone forces me to use Touch ID?"**
Coerced biometric is out of scope for this architecture — as it is out of scope for every security model. The same applies to physical violence against a person holding a wet signature. The architecture defends against digital attacks, not physical coercion.

---

## Framing for different audiences

### Headline ladder (most to least abstract)

1. **The paradigm shift:** "Identity is physics now."
2. **The business implication:** "Every digital action in your company, traced to a human."
3. **The safety property:** "Your agents can't overspend. A breach can't drain your accounts."
4. **The feature:** "Touch ID wallet with on-chain spending caps."

For a cold-read CEO: start at 2.
For a board-level security conversation: start at 1.
For a procurement evaluation: start at 3.
For a developer: start at 4 and work up.

### The one-line version (for the homepage or a pitch deck)
> "Biometrics prove the human. Blockchain bounds the agent. Everything in between is math."

---

*Copy principle: Lead with the paradigm shift — identity is physics — then show the safety properties as downstream consequences. The safety properties are important but they are not the story. The story is that digital identity has been unsolved for 50 years and biometrics on Secure Enclave hardware, anchored to a blockchain, is the solution.*
