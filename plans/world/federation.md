# Federation — cross-substrate trust + foreign signal semantics

> Owner-todo Gap 6. **Last gap** in dependency order. Only relevant
> when a second substrate exists; until then, the protocol is documented
> but no live cross-substrate traffic.
>
> **Status:** W2 decisions locked autonomously per user delegation.
> Foundation shipped (recon doc + decisions); W3 endpoint extensions
> deferred for user review on wake.

## The problem

Each substrate has exactly one owner (per `owner.md`). When two
substrates federate (cross-link via a bridge path), the foreign owner
arrives at our gates with their full owner role. Naïve handling:
foreign owner gets owner-tier bypass on actions in our substrate.
This is wrong — they're not OUR owner.

The fix: **foreign signals are downgraded.** Owner role → chairman role
at the receiving substrate's gates. The foreign owner is just one more
tenant chairman from the local substrate's perspective.

## Architecture

### Bridge handshake

```
Substrate A (owner: 0xAAA...)              Substrate B (owner: 0xBBB...)
  │                                           │
  │  POST /api/paths/bridge                   │
  │   { peerOwnerAddress: 0xBBB,              │
  │     peerOwnerVersion: 3,                  │
  │     peerAssertion: { ... } }              │
  │ ────────────────────────────────────────► │
  │                                           │
  │           ◄ verify peerAssertion against  │
  │           ◄ peer's published owner pubkey │
  │           ◄ local owner asserts in turn   │
  │                                           │
  │  INSERT bridge path with                  │
  │   peer_owner_address, peer_owner_version  │
  │  (both sides have a row)                  │
  │                                           │
```

**V3 challenge issuance.** Before submitting a bridge POST, the initiator GETs
`/api/paths/bridge/challenge?peer=<their-host>` from THEIR OWN substrate (not
the peer's). The returned `challenge` field is included in the bridge POST as
`bridgeChallenge`. The challenge is single-use, peer-bound, and 5-min-TTL.
This closes the replay window on the peer assertion: an attacker who captures
one bridge handshake cannot replay it because the challenge is consumed on first
use. V2.2 substrates without challenge support continue to work via the fallback
warning header (`X-Bridge-Challenge-Missing: true`).

### Inbound signal flow

```
                      ┌───────────────────────────────┐
Foreign signal ─────► │ engine/federation.ts inbound()│
   role: 'owner'      │                               │
                      │  1. Look up bridge path by    │
                      │     foreign sender address    │
                      │  2. Compare peer_owner_version│
                      │     in signal vs bridge       │
                      │     mismatch → reject 403     │
                      │     reason='federation:bridge:│
                      │             stale'            │
                      │  3. Downgrade role:           │
                      │     'owner' → 'chairman'      │
                      │  4. Audit: 'federation:       │
                      │             downgrade'        │
                      │  5. Continue normal routing   │
                      └───────────────────────────────┘
```

### Why downgrade to chairman (not lower)

- **Owner**: substrate-singleton, bypasses scope/network/sensitivity.
  Reserved for the local human apex.
- **Chairman**: per-group, full action set, no gate bypass.
  Foreign owner is a "chairman" of the foreign-owned tenant within
  our substrate.
- **Lower roles** (board / operator / etc.): too restrictive — foreign
  owner needs to actually do things via the bridge.

Chairman is the right level: same action set, but subject to local
scope/network/sensitivity gates (owner's privileges don't transit).

## Locked decisions (autonomous)

| Decision | Choice | Reasoning |
|---|---|---|
| Foreign role at receiver | **chairman** | Safe default; respects local gates. |
| Bridge versioning | Track `peer_owner_version` | Detect peer rotation; force re-handshake. |
| Version mismatch | Reject `federation:bridge:stale` | Surface stale keys explicitly. |
| Re-handshake | Manual | Auto-handshake is abuseable; manual is auditable. |
| Foreign identity | `<remote>:<uid>` namespacing | Existing pattern; no new vocabulary. |
| Discovery | `/.well-known/owner-pubkey.json` per substrate | Standard well-known pattern; pinned at handshake. |
| Multisig federation | V2 deferred | Single-key foreign owner V1; multisig later. |

## Threat model

| Threat | Mitigation |
|---|---|
| Foreign owner abuses owner-tier locally | Downgrade to chairman; subject to local gates. |
| Stale key after peer rotation | Version mismatch → 403. Re-handshake required. |
| Bridge spoofing | WebAuthn assertion binds bridge to specific Sui address. |
| Replay of handshake | Nonce + `created_at` rejection of duplicates within window. |
| Bridge floods receiver | Gap 5 rate ceiling applies (bridge has a key id). |

## What's locked vs deferred

**Locked (this commit):**
- `docs/recon-federation.md` — full recon with autonomous decisions
- This `federation.md` doc — V1 protocol spec
- (No schema needed — bridge path uses existing `path` entity in TypeDB
  with new attributes `peer-owner-address` + `peer-owner-version`. Schema
  extension can land alongside the W3 endpoint work.)

**Deferred (W3+ — needs user wake):**
- `src/pages/api/paths/bridge.ts` — extend body + verification path
- `src/engine/federation.ts` — extend inbound() with downgrade + version check
- `src/__tests__/integration/federation.test.ts` — A→B downgrade test
- `src/__tests__/integration/federation-rotation.test.ts` — rotation
  invalidates bridge test
- Schema extension for `peer-owner-address` + `peer-owner-version`
  attributes on `path` entity in `src/schema/one.tql`

## Path forward

Until a second substrate exists, this gap stays at the foundation
level. When the user wakes, they can:

1. Ratify the autonomous decisions (or override any field)
2. Approve the W3 endpoint extensions sketched above
3. Plan the multi-substrate test setup (two `dev.one.ie`-style
   instances bridged) needed for `t1` + `t2`

## See also

- `owner-todo.md` Gap 6 — task list
- `owner.md` §"Federation across substrates needs naming" — parent spec
- `docs/recon-federation.md` — full W1 recon with autonomous decisions
- `compliance.md` — Gap 3 multisig (similar deferred-foundation pattern)
- Existing: `src/engine/federation.ts`, `src/pages/api/paths/bridge.ts`
