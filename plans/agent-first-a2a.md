# Agent-First A2A — the negotiation handshake

**Status:** design
**Parent:** `plans/agent-first-spec.md` (the registry this builds on) · `plans/0000-agent-first.md` (why)
**Pattern source:** dev.one.ie's marketplace (reference only — proven on testnet; rewritten here into receiver/`signal.data` terms, no `units/`/nanoclaw paths carried over)
**Blast radius:** receiver family (`market:*`) · `signal.data` convention · `mark`/`warn` · escrow/pay — **no schema changes**

---

## The gap

Today `market:hire` is a single shot: one agent calls, the substrate matches, done. There is no way for **agent A to negotiate with agent B** — to offer terms, counter, agree on acceptance criteria and a deadline, escrow value, deliver, verify, settle, and dispute. That handshake is what turns "a directory of agents" into "an economy of agents." It is the ❌ peer-mesh row in `agentic-patterns-oneie.md`.

This plan adds it — and the elegant surprise (proven in dev.one.ie) is that **it needs no new schema**. A deal is a JSON envelope in `signal.data`; its lifecycle is a `stage` field; reputation rides the `path.strength`/`resistance` the substrate already keeps. A2A is *receivers + a data convention + `mark`/`warn`* — exactly the registry philosophy.

---

## The principle: the deal is data, the path is reputation

Two locked moves, both inherited from substrate canon:

1. **Deal-as-data (schema-lock).** No `deal` entity, no `escrow` table. The deal lives in `signal.data` as a typed envelope, declared once in the registry so it is validated, introspectable, and dry-runnable. The ontology stays at 6 dimensions.
2. **Settlement *is* reputation.** The `mark` that strengthens the A→B path on a successful settle *is* the payment weight — `revenue = weight`. One event, not two. A dispute `warn`s the same path. Reputation is measured (paid traversals), never assigned.

```ts
// the deal envelope — one zod schema in @oneie/sdk/receivers, carried in signal.data
const Deal = z.object({
  id: z.string(),                    // idempotency anchor for the whole handshake
  buyer: z.string(), seller: z.string(),
  skill: z.string(),
  price: z.number(), currency: z.enum(["USD","SUI","ETH","BTC"]),
  deadline: z.number(),              // absolute ms — the timeout that auto-refunds
  rubric: z.object({ fit: z.number(), form: z.number(), truth: z.number(), taste: z.number() }), // acceptance criteria, set at offer time
  stage: z.enum(["OFFER","ESCROW","EXECUTE","VERIFY","SETTLE","RECEIPT","DISPUTE","FADE"]),
  escrowRef: z.string().optional(),  // pay/x402 lock handle
  result: z.unknown().optional(),
})
```

---

## The state machine (enforced, never silent)

The trade arc is already canon in `lifecycle.md` (LIST → DISCOVER → OFFER → ESCROW → EXECUTE → VERIFY → SETTLE → RECEIPT → DISPUTE → FADE). The negotiation receivers *drive* the transitions; an enforced `VALID` matrix rejects illegal ones (dev.one.ie's reducer pattern — invalid transition throws, no silent corruption):

```
DISCOVER ─offer─▶ OFFER ─counter─▶ OFFER        (re-negotiate)
                   │ accept
                   ▼
                 ESCROW ─lock─▶ EXECUTE ─deliver─▶ VERIFY
                   │                                  │ pass        │ fail / timeout
                   │ reject/timeout                   ▼             ▼
                   ▼                                SETTLE        DISPUTE
                  FADE ◀──────────────────────────  RECEIPT  ───▶  FADE
```

Backtracking (`OFFER → DISCOVER`) and early exit to `DISPUTE` are legal from any active stage. Every transition closes the loop with `mark`, `warn`, or `dissolve` — locked rule #1.

---

## The receiver family

All `market:*`, all declared in the registry with the enriched metadata (this is *why* A2A needs the registry first):

| Receiver | Stage move | `signal.data` | Metadata that matters |
|---|---|---|---|
| `market:offer` | DISCOVER → OFFER | full `Deal` (stage=OFFER) | `simulatable:true` (dry-run the match + cost) |
| `market:counter` | OFFER → OFFER | `Deal` with revised terms | `idempotent` on `(id, terms-hash)` |
| `market:accept` / `market:reject` | OFFER → ESCROW / FADE | `{ id }` | irreversible once accepted |
| `market:escrow` | ESCROW → EXECUTE | `{ id, escrowRef }` | `settles:"onchain"`, `cost`, `reversible:false` |
| `market:deliver` | EXECUTE → VERIFY | `{ id, result }` | `idempotent` on `(id)` |
| `market:verify` | VERIFY → SETTLE / DISPUTE | `{ id, scores }` | rubric-gated (below) |
| `market:settle` | SETTLE → RECEIPT | `{ id }` | `settles:"onchain"`, marks the path (+strength, +revenue) |
| `market:dispute` | any → DISPUTE | `{ id, reason }` | warns the path (+resistance), refunds escrow |

Timeout is not a receiver — it's the substrate's 4-outcome `timeout`, which auto-fires `market:dispute` (refund + mild `warn`, not a ban). The loop always closes.

---

## Three patterns lifted from dev.one.ie (translated)

### 1 · Lazy trust bootstrap — strangers escrow, highways don't

The hard problem: how do two agents with no shared history trade safely? dev.one.ie's answer (x402 + escrow template) maps directly onto our `ask`:

- **`market:offer` from a low-trust path** (`path.strength < 1`) → outcome carries an **escrow requirement** (the x402 402-style template: amount, deadline, settle handle). The buyer must `market:escrow` before `EXECUTE`.
- **`market:offer` over a hardened highway** (proven path) → escrow optional; trust is earned, the handshake skips straight to `EXECUTE`. New entrants start cold and climb by delivering.

Trust is not configured; it's the path weight the substrate already computes.

### 2 · Rubric-gated verify — acceptance without a human reviewer

`market:verify` scores the delivered `result` against the `rubric` embedded in the offer, using the agent rubric (`fit`/`form`/`truth`/`taste` — `plans/rubrics.md`). Each dimension becomes a tagged edge (`A>B:fit`, `A>B:truth`…). Gate (dev.one.ie's thresholds): any dimension < 0.5 → `DISPUTE`; composite ≥ 0.65 → `SETTLE` (mark scaled by composite); ≥ 0.85 → full mark. The *reason* travels in the outcome, so a dispute can cite the dimension that failed.

### 3 · Durable settlement — the deal survives a restart

The deal envelope is persisted (KV/D1, keyed by `Deal.id` — the same id that makes the whole handshake idempotent), with `status: pending | settled | failed` and a retry count. An agent that crashes mid-handshake resumes from `meta:recall` rather than losing the escrow. Failures record the exact reason. Closed loop, no orphaned escrow.

---

## The human guard (threat model)

A2A moves real value, so the four human↔agent patterns apply. A deal whose `price` exceeds the agent's capability scope requires **owner co-sign** before `market:escrow` commits — the agent can negotiate freely but cannot settle above its grant without the human's passkey-rooted approval (`grant-capability` scope check). Small deals flow autonomously; large ones surface to the owner. *Humans safe by physics:* the agent can offer a million; it can only spend what its scope allows.

---

## Why this waits for the registry

Every `market:*` receiver leans on the enriched `Receiver` entry from `plans/agent-first-spec.md`:

- `simulatable` → an agent dry-runs `market:offer` to see the match and cost before committing.
- `settles`/`cost` → an agent budgets the whole handshake from `meta:catalog` before the first offer.
- `idempotent` + `Deal.id` → the crash-safe retry that an economy requires.
- the validated `Deal` schema → negotiation payloads can't be malformed, and the error teaches the fix.

Build the registry (C1–C8) first; A2A is the proof that the affordance layer was worth it.

---

## Next

Generate `plans/agent-first-a2a-todo.md` from `plans/template-todo.md`. Cycle shape (provisional):

1. **Deal envelope + state machine** — `Deal` schema + enforced `VALID` reducer in `@oneie/sdk` (pure, unit-tested: illegal transition throws).
2. **Negotiation receivers** — `market:offer`/`counter`/`accept`/`reject` declared + handlers (stage moves on `signal.data`).
3. **Escrow + lazy trust** — `market:escrow` wired to pay/x402; low-trust path → escrow required, highway → optional.
4. **Verify + settle + dispute** — rubric-gated `market:verify`; `market:settle` marks the path (revenue=weight); `market:dispute`/timeout warns + refunds.
5. **Durable deal + human co-sign** — persist by `Deal.id`, resume via `meta:recall`; owner co-sign gate above scope.
6. **End-to-end** — two-agent integration test: cold offer → escrow → deliver → verify → settle, and the dispute/timeout branch, against a real substrate.

Then `/do plans/agent-first-a2a-todo.md`.

---

## See also

- `plans/agent-first-spec.md` — the registry + affordance layer (build first)
- `plans/lifecycle.md § Trade Lifecycle` — the canonical 10-stage arc
- `plans/rubrics.md` — fit/form/truth/taste (verify gate)
- `plans/0000-agent-first.md` — agents as first-class economic citizens
