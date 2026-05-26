# Agent Autonomy + Human Approval Flow

**Principle:** Agents are autonomous by default. Humans approve exceptions,
not operations. The boundary is set by the human with their biometric —
not by the agent, and not by our servers.

---

## The Three Zones

Every agent action falls into one of three zones. The zones are defined
by the cap the human signed, not by any runtime check we control.

```
AUTONOMOUS ZONE — agent acts, no human needed
─────────────────────────────────────────────
  amount ≤ daily_limit
  recipient ∈ allowed_recipients
  action ∈ permitted_actions
  now < expires_epoch
  paused == false

APPROVAL ZONE — agent requests, human Touch IDs
─────────────────────────────────────────────────
  amount > daily_limit  (needs cap raise or one-time override)
  recipient ∉ allowed_recipients  (needs allowlist addition)
  spawn sub-agent  (needs new child cap)
  structural change  (pause/unpause, cap modification, delegation)

HARD STOP — Move contract physically blocks
────────────────────────────────────────────
  cap.paused == true  →  every tx fails at consensus
  amount > cap.total_remaining  →  arithmetic enforced by validators
  parent_cap expired  →  child caps implicitly dead
```

The autonomous zone is where agents live 99% of the time.
The approval zone is the exception surface — small, predictable, auditable.
The hard stop is not a policy — it is physics. 100+ validators enforce it.

---

## What an Approval Request Looks Like

Agents do not send "please let me do something" — they send a fully
constructed, machine-readable request that specifies exactly what they
intend to do and exactly what the human is signing.

```typescript
interface ApprovalRequest {
  // Identity
  request_id: string          // UUIDv4 — idempotent retry safe
  agent_uid: string           // "agent:treasury-ops"
  requested_at: number        // unix ms
  expires_at: number          // unix ms — request auto-voids after this

  // What the agent wants to do
  action: ApprovalAction

  // Why the agent thinks it's needed (human-readable)
  reasoning: string           // max 280 chars — forces clarity

  // The exact transaction that will execute if approved
  // Human signs THIS — not a permission, the actual operation
  pending_tx: SuiTransactionBlock

  // Risk summary (computed by substrate, not agent)
  risk: {
    amount_requested: bigint
    recipient_known: boolean      // in this agent's history
    recipient_new_to_org: boolean // never seen in org's history
    action_frequency: "first" | "rare" | "regular"
    cap_utilisation_after: number // 0.0–1.0 fraction of daily limit used
  }
}

type ApprovalAction =
  | { type: "payment"; recipient: string; amount: bigint; memo?: string }
  | { type: "spawn_agent"; spec: AgentSpec; child_cap: CapParams }
  | { type: "add_recipient"; address: string; label?: string }
  | { type: "raise_cap"; new_daily: bigint; reason: string }
  | { type: "extend_cap"; new_expiry: number }
  | { type: "resume"; was_paused_since: number }
```

The `pending_tx` field is critical. The human does not approve a *category
of action* — they sign the *specific transaction*. When they Touch ID,
the Secure Enclave signs `pending_tx` and nothing else. The agent cannot
change it after approval.

---

## The Approval UX — Three Steps

### Step 1 — Notification

The human receives a push notification (or in-app if active):

```
┌────────────────────────────────────────────────┐
│  🔔  treasury-ops needs approval               │
│                                                │
│  Payment to Acme Suppliers Ltd                 │
│  €12,400.00 USDC                               │
│                                                │
│  Reason: Monthly SLA settlement — invoice #847 │
│                                                │
│  [Review →]                      [Dismiss]     │
└────────────────────────────────────────────────┘
```

Notifications are grouped by agent. Multiple pending requests queue —
the human reviews them in order, not as a flood.

### Step 2 — Review Card

Tapping Review opens a full-screen card. No ambiguity about what is
being approved. The layout is always the same, regardless of action type.

```
┌────────────────────────────────────────────────┐
│  treasury-ops is requesting approval           │
│  ─────────────────────────────────────────── │
│                                                │
│  ACTION                                        │
│  Send payment                                  │
│                                                │
│  TO                                            │
│  Acme Suppliers Ltd                            │
│  0x1a2b...3c4d                                 │
│  ⚠ New recipient (not in your history)        │
│                                                │
│  AMOUNT                                        │
│  12,400.00 USDC  (€12,400 at current rate)     │
│                                                │
│  AGENT'S REASON                                │
│  Monthly SLA settlement — invoice #847         │
│                                                │
│  CAP IMPACT                                    │
│  Daily limit: 15,000 USDC                      │
│  After this payment: 2,600 USDC remaining      │
│  ████████████░░  82% used                      │
│                                                │
│  REQUEST EXPIRES                               │
│  in 4 hours (today at 16:30)                   │
│                                                │
│  ─────────────────────────────────────────── │
│                                                │
│  [Approve with Touch ID]    [Reject]           │
│                                                │
│  Approving signs the exact transaction above.  │
│  Nothing else will be executed.                │
└────────────────────────────────────────────────┘
```

Key UX rules:
- **No jargon in the action summary.** "Send payment" not "execute Move tx."
- **Warning flags** appear on: new recipient, amount > 50% of daily cap,
  action not seen before, agent age < 24h.
- **The disclaimer** ("Approving signs the exact transaction above") is
  always visible. Not a tooltip. Always in the card.
- **No confirm screen.** Touch ID → done. One gesture.

### Step 3 — Touch ID

Touch ID fires `navigator.credentials.get()` with WebAuthn PRF extension.
PRF produces the 32-byte hardware-bound secret. HKDF derives the signing
key. The Secure Enclave signs `pending_tx` and returns it.

The substrate submits `pending_tx` to Sui via the sponsor worker.
The agent receives a notification: `approval:granted:{request_id}` with
the on-chain tx digest.

The agent then proceeds with that exact transaction — not a re-construction
of it. The substrate holds `pending_tx` in escrow from the moment the
agent submitted the request.

---

## What Happens on Reject

Reject sends `approval:rejected:{request_id}` to the agent. The agent
handles it as a dissolved signal — mild warn(0.5), chain breaks. The
substrate learns this action type on this recipient generates rejections.

If rejections accumulate on a pattern, the substrate flags it:
```
Hypothesis: "treasury-ops payments to unknown recipients → rejected"
Confidence: 0.72 (asserted → verified)
```

The agent evolves: its next spawn or prompt rewrite will include
"only send to known recipients" as an inferred constraint.

---

## What Happens on Expiry

If the human doesn't respond within the request window, the approval
request voids. The agent receives `approval:expired:{request_id}`.

The pending transaction in escrow is deleted. Nothing was submitted.

The agent logs the expiry. If a task depends on the payment, it marks
itself `dissolved` — the substrate records it, fade applies, chain breaks.
The human sees the task as dissolved in their task board.

---

## Spawning Sub-Agents (Approval Required)

When an agent wants to spawn a child agent:

```typescript
// Agent generates this approval request
{
  action: {
    type: "spawn_agent",
    spec: {
      uid: "agent:acme-negotiator",
      model: "claude-haiku-4-5",
      skills: ["negotiate", "email"],
    },
    child_cap: {
      daily_limit: 500n,            // USDC — subset of parent's limit
      allowed_recipients: [],        // starts empty — child must request additions
      expires_epoch: parentCapExpiry, // cannot outlive parent
      paused: false,
    }
  },
  reasoning: "Acme contract renewal in progress — need dedicated negotiator"
}
```

The human sees:

```
treasury-ops wants to spawn a sub-agent

AGENT NAME:   acme-negotiator
MODEL:        Claude Haiku
SKILLS:       negotiate, email
SPENDING CAP: 500 USDC/day (out of treasury-ops's 2,600 remaining)
EXPIRES:      same as your cap for treasury-ops (30 April)

This agent will operate autonomously within these bounds.
Its actions will be visible in your activity feed.
```

Approve → child agent spawned with its own seed, wrapped under your KEK.
Its cap is a Move `Cap` object child of treasury-ops's cap.
The chain: your biometric → treasury-ops cap → acme-negotiator cap.

---

## Determinism of Approvals

Approval is deterministic because:

1. **The transaction is pre-built** — the agent builds `pending_tx` before
   requesting. What you see is what executes.

2. **The signing is hardware-bound** — Touch ID on Secure Enclave. The PRF
   output is deterministic given the same credential. No randomness in the
   approval step.

3. **The escrow is hash-locked** — the substrate holds `pending_tx` content
   hash. If the agent tried to swap the tx after approval was granted, the
   hash mismatch would reject it.

4. **The Move contract is the enforcer** — even if the substrate were
   compromised, the on-chain cap arithmetic blocks overspend. Validators
   don't know about our approval flow. They only know: does this tx fit
   within this cap?

The determinism property: if you approve request R, exactly transaction T
executes. Not T' because the agent changed its mind. Not T with extra
recipients added. T. Exactly.

---

## Integration with Security Narrative

From the human's point of view:

> I set the rules once with my fingerprint.
> My agent operates freely within them.
> When it needs to go further, it asks me — with a full description of
> exactly what it will do, and exactly what I'm signing.
> My Touch ID doesn't just approve an idea. It signs the specific transaction.
> The blockchain runs it. Verbatim.

This is what "easy and deterministic" means:
- **Easy:** One notification. One card. One Touch ID. Done.
- **Deterministic:** No ambiguity about what was approved. Math enforces it.

---

## API Surface

```
POST /api/agents/:uid/approval/request
  Body: ApprovalRequest
  Auth: agent bearer
  Effect: queues request, notifies human, starts expiry timer

GET  /api/agents/:uid/approval/pending
  Auth: human session or chairman bearer
  Returns: ApprovalRequest[]

POST /api/agents/:uid/approval/:request_id/approve
  Body: { signed_tx: string }  // signed pending_tx from WebAuthn
  Auth: human session (must be cap owner)
  Effect: submits tx, notifies agent, records on-chain digest

POST /api/agents/:uid/approval/:request_id/reject
  Body: { reason?: string }
  Auth: human session
  Effect: voids request, notifies agent, weak warn on pattern

GET  /api/agents/:uid/approval/history
  Auth: human session
  Returns: ApprovalRequest[] with outcome + on-chain digest
```

---

## Security Properties

| Property | Mechanism |
|----------|-----------|
| Human cannot approve wrong tx | `pending_tx` hash locked in escrow; sign = commit |
| Agent cannot exceed approved amount | Move cap arithmetic, consensus-enforced |
| Agent cannot swap tx after approval | Content hash checked before submit |
| Request cannot be replayed | `request_id` one-use, expires |
| Approval cannot be forged | Touch ID on Secure Enclave — physical presence required |
| Rejected approval leaves no residue | Escrow deleted on reject/expire |

---

## What Agents Do Autonomously (No Approval)

To be concrete: most agent work is fully autonomous. Examples:

| Action | Autonomous? | Why |
|--------|-------------|-----|
| Pay known supplier ≤ daily cap | ✅ | Within signed parameters |
| Draft email, post to Slack | ✅ | No financial action |
| Query TypeDB, read signals | ✅ | Read-only |
| Mark task done, emit signal | ✅ | Pheromone only |
| Spawn sub-agent reading task | ✅ | If spawn-permitted flag set |
| Pay unknown recipient | ❌ | Approval required |
| Payment exceeding daily cap | ❌ | Approval required |
| Modify own cap | ❌ | Always human-only |
| Access owner-tier endpoints | ❌ | Always human-only |

The approval surface is deliberately narrow. The point is not to make
every agent action a bottleneck — it is to make exceptions auditable.

---

*Agents run. Humans approve exceptions. Math enforces everything.*
