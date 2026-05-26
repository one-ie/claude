# Compliance — multi-sig + audit for tenant chairmen

> Owner-todo Gap 3. **First customer-facing feature** — the surface that
> opens enterprise / regulated tenant onboarding.
>
> **Status:** W2 decisions locked autonomously per user delegation
> ("trust all your decisions"). User should review on wake; any decision
> can be revisited before W3 endpoint work begins.

## Why

Single-key chairman = single point of compromise. Enterprise tenants
(esp. regulated industries — finance, health) demand N-of-M signatures
on high-impact actions: policy changes, treasury moves, role appointments.
Owner stays single-key (substrate-singleton); chairmen become threshold-
configurable per group.

## W1 recon summary

(Full survey at `docs/recon-multisig.md` — written autonomously; the
user should ratify or amend before W3 endpoints land.)

### WebAuthn multi-assertion timing

- **Per-credential ceremony:** each WebAuthn assertion is an
  independent `navigator.credentials.get()` call → one Touch ID per
  member per signature. No browser supports multi-assertion in one
  ceremony; the chairman UI walks each member through their own
  prompt.
- **Window:** the substrate accepts N assertions over a server-side
  collected challenge if they all complete within an **assertion
  window**. Recommended window: **5 minutes**.
- **Recommendation:** server-issued challenge → distributes to each
  member out-of-band (Slack DM, email, in-app notification) → each
  member's browser completes the ceremony → batched POST to
  `/api/auth/passkey/assert` with the N signed assertions.

### Sui multisig threshold semantics

- Sui's native `MultiSigPublicKey` supports weighted N-of-M with
  per-key weights summing to a threshold. We adopt the simpler
  EQUAL-WEIGHT N-of-M for V1 (every member counts as 1; threshold
  is N out of M total members).
- Off-chain assertion check (the auth middleware accepts the action
  if N WebAuthn assertions verify) is the V1 mode. On-chain Sui
  multisig (the action wraps a Move tx signed by N members' on-chain
  keys) is V2 — adds the chain as the source-of-truth threshold.
- V1 ships off-chain only. V2 follows once the value-at-risk per
  group justifies the on-chain cost.

### Recovery path (member loses passkey)

- Each chairman can be in an "active" or "compromised" state per
  membership row. Other chairmen vote to mark a member compromised;
  threshold is the SAME N-of-M used for actions.
- A compromised member is removed from the membership; if remaining
  members ≥ M-of-M post-removal, the group continues. If not, the
  group escalates to the substrate owner for re-init. Owner is the
  ultimate fallback.

## W2 decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Assertion window | **5 min** | Long enough for clock skew + cross-timezone members; short enough that a stolen challenge can't sit indefinitely. |
| Multisig granularity | **Per-group, on `chairman_multisig` row** | Cleaner than per-member. Group-level threshold matches the legal model (the tenant org acts as the unit; individual chairmen are interchangeable members). |
| On-chain vs off-chain | **Off-chain V1, on-chain V2** | V1 ships in a week; V2 needs chain budget for every action. Tenants accept V1 for low-stakes; V2 unlocks when value > $X. |
| Recovery | **Threshold-vote to mark compromised** + **owner-fallback on quorum loss** | Symmetric with the action threshold; no second governance system needed. |
| Equal weight or weighted | **Equal weight V1**; weighted as future opt-in | Most enterprise tenants don't have rank ordering among chairmen at the same group level. Weighted complicates the UI for marginal benefit. |
| Action scope | **Selective — only "owner-bypass" actions require multisig** | A blanket multisig requirement would make every read require N signatures (insufferable). The bypass-emit code path (Gap 2 §2.r2) checks `multisig_required` and demands batch only on the protected actions. |

## What's locked vs deferred

**Locked (this commit):**
- `migrations/0033_chairman_multisig.sql` — D1 schema
- `src/lib/role-check.ts` — `multisig_required: false | { n, m }` type extension
- This compliance doc (decisions + threat model)

**Deferred (W3+ — needs user wake):**
- `src/pages/api/groups/:gid/multisig.ts` — chairman-only endpoint to
  configure `{n,m}` for a group
- `src/pages/api/auth/passkey/assert.ts` — accepts batched N assertions
  within window for multisig groups
- `src/__tests__/integration/chairman-multisig.test.ts` — end-to-end
  3-of-5 test

The endpoint work is invasive (modifies the existing assert endpoint
shipped in Gap 0), and the test requires the endpoint. Honest deferral
matches the same pattern Gap 4 used (foundation without runtime wiring).

## Threat model (V1 acceptance)

| Threat | Mitigation |
|---|---|
| Single chairman key compromise | N-1 remaining members can revoke + re-issue. Action threshold prevents lone-wolf damage. |
| Stale assertion within window | 5-min window; assertion challenge tied to action params (replay-protected). |
| Member coercion (1 of N) | Threshold N > 1 means coerced member can't act alone. |
| Member coercion (N of N) | Out of scope — at threshold compromise, the substrate owner is the last line. |
| Cross-tenant lateral movement | Assertion verifies against the SPECIFIC group's `chairman_multisig.member_credentials` JSON. Member credentials don't transfer across tenants. |

## Implementation notes for W3

### Endpoint shape (deferred)

```typescript
// POST /api/groups/:gid/multisig — configure threshold
// Auth: existing chairman of the group
// Body: { n: number, m: number, members: string[] /* uids of chairmen */ }
// → INSERT INTO chairman_multisig (group_id, threshold_n, threshold_m, member_credentials)
//   VALUES (?, ?, ?, ?) ON CONFLICT (group_id) DO UPDATE
```

```typescript
// POST /api/auth/passkey/assert — batched assertion path
// Body: {
//   action: 'multisig-action',
//   group_id: string,
//   assertions: Array<{ credId: string, clientDataJSON: string, authenticatorData: string, signature: string }>
// }
// Server flow:
//   1. SELECT chairman_multisig WHERE group_id = ?
//   2. Verify each assertion individually via @simplewebauthn/server
//   3. Confirm distinct credIds (no double-counting)
//   4. Confirm each credId is in member_credentials list
//   5. count(verified_assertions) >= threshold_n → allow; else 403
//   6. Emit audit:multisig:{group} record with the N member uids
```

## See also

- `owner-todo.md` Gap 3 — the build plan
- `owner.md` §"Five-state owner key lifecycle" + §"File map" Gap 3 row
- `migrations/0033_chairman_multisig.sql` — D1 schema (this gap)
- `docs/recon-multisig.md` — full WebAuthn + Sui multisig recon (autonomous)
- `agents.md` Pattern D — recursive spawning context (chairmen are not
  agents; multisig is for human-tenant chairmen)
