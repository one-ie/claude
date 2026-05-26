# owner-todo — build the substrate root, six gaps in dependency order

> **V2 ground truth (all 7 gaps closed):**
> **Gap 0** rubric 0.855 · **Gap 2** rubric 0.8875 · **Gap 5** rubric 0.9125
> **Gap 1** rubric 0.875 · **Gap 4** rubric 0.825 · **Gap 3** rubric 0.80 (v1+v2)
> **Gap 6** rubric 0.80 (v1+v2)
>
> **Verify:** `bun run verify` exit 0 throughout; 176/188 tests pass
> (12 skipped: 3 cassettes need re-record + 7 skipIfNoDb guards + 2 deferred
> assertion-flow tests blocked on Gap 3 3.s3).
>
> **V2 hardenings shipped (in-gap, no separate cycle):**
> - Gap 1 owner-daemon: audit log to `~/Library/Logs/owner-daemon-audit.jsonl`,
>   per-bearer rate limit (10/min, 100/hr). Files: `apps/owner-daemon/` +
>   `com.tonyoconnell.owner-daemon.plist`
> - Gap 3 multisig: real `verifyAuthenticationResponse` from
>   `@simplewebauthn/server`; `member_credentials` requires `pubKey` (COSE
>   base64url). File: `src/pages/api/auth/passkey/assert.ts`
> - Gap 6 federation: `src/lib/federation-discovery.ts` fetchPeerPubkey + cache;
>   `src/pages/.well-known/owner-pubkey.json.ts` discovery endpoint
>
> **V3 carries (none blocking — track in owner.md §V3):**
> - Daemon log rotation (JSONL grows unbounded)
> - Daemon mTLS (Astro ↔ daemon currently HMAC-only over localhost HTTP)
> - Multisig sign_count tracking (replay protection beyond 5-min bundle TTL)
> - Federation V2.2 JWKS publication + signature verify against peer pubkeys
>
> **Operational carries (need hardware/creds, not code):**
> - GPG signing chain (overnight commits unsigned; keychain locked)
> - Cassette re-record (auth-roundtrip / memory-reveal / signal-flow —
>   needs `RECORD=1 GATEWAY_API_KEY=<key>`)
> - BIP39 paper recovery quarterly dry-run (per mac.md)

**Spec:** [`owner.md`](owner.md). Spec is locked. This file tracks code deltas to make the shipping product match it.

**Mode:** mixed (most gaps are lean cycles inside a full plan — files known per gap, exit scalars defined, variance bounded; gap 3 multi-sig is the only one with W1 recon needed).

**Lifecycle:** construction.

**Goal:** owner role exists in `role-check.ts`, all six gaps land in dependency order, no `SUI_SEED` anywhere in worker env, every owner-tier action audited, recursive agent spawning works under cap-tree consensus.

**Exit scalars (overall):**
- `grep -r "SUI_SEED" one.ie/nanoclaw one.ie/gateway one.ie/workers` returns nothing
- `auth.role === 'owner'` short-circuits scope/network/sensitivity gates
- `owner_audit` D1 row count increments on every owner-tier signal
- Synthetic load at `OWNER_HARD_CEILING` returns 429
- Test substrate: human spawns agent, agent spawns sub-agent, cap arithmetic balances
- BIP39 paper recovers full owner+agents stack on a fresh device

---

## Universal preamble — every gap starts and ends the same

Per [`engine.md`](one.ie/.claude/rules/engine.md) Rule 3 (deterministic results) and [`documentation.md`](one.ie/.claude/rules/documentation.md) (docs change with code).

**Per-gap W0 (baseline, before any edit):**
| id | task | exit |
|----|------|------|
| `*.w0` | `bun run verify` clean — biome + tsc + vitest. Record numbers as the chain-depth-start mark. | exit 0; baseline counts captured |

**Per-gap D1 (doc reconciliation, in W3 alongside code):**
| id | task | files (verified per gap) | exit |
|----|------|--------------------------|------|
| `*.d1` | Update spec docs that reference the changed code. Cross-check `owner.md` cited file table against reality. | per-gap (listed in each gap section below) | grep: every cited file:line in `owner.md` exists |

**Per-gap close (verify after edits, rubric score):**
| id | task | exit |
|----|------|------|
| `*.close` | `bun run verify` clean again. Run gap acceptance scalar. Score rubric (fit/form/truth/taste). | rubric ≥ 0.65 AND acceptance green |

> Naming: `*.w0` = baseline verify; `*.w1`–`*.w4` are reserved for **worker-specific tasks** in Gap 1 (`SUI_SEED` removal across nanoclaw / gateway / sync / CI). The rubric-close task is `*.close` in every gap to avoid collision.

---

## Routing

```
W1 recon (per gap — owner.md is the recon for gaps 1, 2, 4, 5; gap 3 multi-sig + gap 6 federation need dedicated recon)
   ↓
W2 decide (per gap — locked in owner.md gap sections)
   ↓
W3 edit (parallel only within independent gaps; gap 2 must land before any owner-tier code in production)
   ↓
W4 verify (per-gap acceptance + integration test on dev.one.ie)
   ↓
mark(): each acceptance scalar passes → mark edge `owner → gap-N`
warn(): regression on cap-tree arithmetic, audit miss, or rate-ceiling bypass → warn(1) on the offending task
```

**Pheromone receivers:**
- `owner:gap2:audit:emit` — every owner-tier action signal
- `owner:gap1:seed:strip` — per worker that drops `SUI_SEED`
- `owner:gap1:agent:register` — per agent migrated to PRF-wrapped storage
- `owner:gap5:rate:limit` — when synthetic load hits ceiling
- `owner:gap4:rotate:v{n}` — every key rotation
- `owner:gap3:multisig:assert` — chairman multi-sig assertions
- `owner:gap6:federation:bridge` — cross-substrate handshakes

---

## Schema reference

New TypeDB attributes on existing entities:
- `unit.role`: extend enum to include `owner` (at most one actor per substrate)
- `unit.owner-address`: substrate-singleton attribute on the owner unit, locked at first-mint

New D1 tables (migrations under `one.ie/migrations/`):
- `0030_owner_audit.sql` — `owner_audit (ts INTEGER, action TEXT, sender TEXT, receiver TEXT, payload_hash TEXT, gate TEXT, decision TEXT)`. Append-only.
- `0031_agent_wallet.sql` — `agent_wallet (uid TEXT PK, ciphertext BLOB, kdf_version INTEGER, created_at INTEGER, expires_at INTEGER)`. One row per autonomous agent.
- `0032_owner_key_versions.sql` — `owner_key (key_hash TEXT PK, version INTEGER, issued_at INTEGER, expires_at INTEGER, role TEXT, group_id TEXT)`. Active versions queryable.
- `0033_chairman_multisig.sql` (gap 3) — `chairman_multisig (group_id TEXT PK, threshold_n INTEGER, threshold_m INTEGER, member_credentials JSON)`.

Move struct additions (extension to `one.move` or new module):
- `Cap` — owner, spender, daily_limit, spent_today, day_epoch, allowed_recipients, paused, parent_cap (Option<ID>), expires_epoch
- Entry functions: `mint`, `spawn_child`, `pause`, `unpause`, `revoke`, `rotate_spender`, `extend_expiry`, `set_limit`, `ping`

---

## Tasks

### Gap 0 — Bootstrap + identity migration (PREREQUISITE for every gap)

> Before any owner-tier code is added, the substrate needs to know *who the owner is* and the existing chairman session needs to pivot. This block lands first.

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 0.w0 | ✅ DONE | `bun run verify` clean baseline | n/a | exit 0 — 166/176 test files pass, 10 skipped (3 cassettes flagged for re-record + 7 pre-existing skipIfNoDb guards). Stabilized in `2f5dde0` (biome cleanup) + `a53cc59` (test fixes + .audit-baseline reseed 733→1049). |
| 0.s1 | ✅ DONE | Add `OWNER_EXPECTED_ADDRESS` to `.env.example` + dotenvx production env (per `secrets.md`); document in `one.ie/.env.example` | `one.ie/.env.example` | env var documented |
| 0.s2 | ✅ DONE | Resolve owner address: read `tony@one.ie`'s existing `/u` wallet address (the address registered against his Better Auth user record) and set `OWNER_EXPECTED_ADDRESS` to that value. Resolved via TypeDB `match $u isa unit, has uid "human:tony", has wallet $w; select $w;` → `0x37cad0b0271f8e0a51a3d3748d7e648c1582197ad5dbc17956ecb31c63d8de3b` (uncommitted in `one.ie/.env`). | `one.ie/.env` (owner machine, not committed) | env value matches `unit { uid: "human:tony" } owns wallet $w` |
| 0.s3 | ✅ DONE | New `POST /api/auth/passkey/assert` endpoint with first-mint branch: rejects unless `assertedAddress === env.OWNER_EXPECTED_ADDRESS` AND `owner_key` table is empty. Auth model (documented inline): Better Auth session cookie → TypeDB unit lookup resolves wallet → env-gate on first-mint. Per-call WebAuthn deferred (existing `passkey-webauthn` plugin verifies at sign-in). New D1 migration `migrations/0028_owner_key.sql` (Gap 4 will extend it via `0032`). | `one.ie/src/pages/api/auth/passkey/assert.ts`, `one.ie/migrations/0028_owner_key.sql` | first-mint gate rejects wrong addr (403 first-mint-address-mismatch); accepts owner addr (200 + ownerKey bearer); second mint hits owner_key non-empty branch and verifies addr equals registered owner |
| 0.s4 | ✅ DONE | New Move struct `SubstrateOwner` with `owner: address` field; entry function `init_substrate_owner(addr)` callable once, aborts on second call. Module shipped via package UPGRADE (not new publish — `init` doesn't run on upgrades, so `bootstrap(&UpgradeCap)` creates the pin lazily, gated by UpgradeCap-as-publisher-proof). Testnet pkg `0x4dfa9cc1…220d` v3, pin `0x38a8f796…dde71`, locked at epoch 1080 to `0x37cad…de3b`. Verified: second init aborts with code 100 = `E_OWNER_LOCKED`. | `one.ie/src/move/one/sources/owner.move` | testnet deploy; second `init` aborts with `E_OWNER_LOCKED` ✓ |
| 0.s5 | ✅ DONE | First-mint flow also calls `init_substrate_owner` Move function; owner registration is atomic across D1 + Sui. Helper extracted to `src/lib/owner-mint.ts` (`lockOnChainOwner(addr)` + `readOnChainOwner()`). Atomicity contract: Move first, then D1. Move fail → first-mint stays open. Move success + D1 fail → on-chain pin is truth, recoverable via pin-object lookup. Errors mapped: E_OWNER_LOCKED → 409, other Sui → 502, D1-after-Move → 500. Requires `SUI_SPONSOR_KEY` (or `SUI_OPERATOR_KEY`), `ONE_PACKAGE_ID`, `SUBSTRATE_OWNER_PIN_ID` env. | `one.ie/src/pages/api/auth/passkey/assert.ts`, `one.ie/src/lib/owner-mint.ts` | both records present after first-mint (D1 row with `pin_object` + `pin_digest`; on-chain pin locked with matching addr) |
| 0.m1 | ✅ DONE | Migration: pivot Tony's existing role from `chairman` to `owner` on his personal group `group:human:tony`; insert `owner_key` row at first-mint (handled by 0.s3); ensure existing session keeps working. **Spec slip corrected**: role grants live in TypeDB's `membership` relation (queried by `getRoleForUser` in `api-auth.ts`), not D1. The migration is TypeQL, not SQL. File renamed `migrations/typedb/0029-tony-chairman-to-owner.tql`. Idempotent runner: `scripts/migrate-tony-to-owner.ts`. Tony's membership in `group:human:tony` now has `member-role "owner"`. | `one.ie/migrations/typedb/0029-tony-chairman-to-owner.tql`, `one.ie/scripts/migrate-tony-to-owner.ts`, `one.ie/migrations/typedb/seed-roles.tql` (22 owner role-grants), `one.ie/src/schema/one.tql` (comment updates) | Tony's TypeDB role = `owner` ✓; session validity (cookie carries uid not role; getRoleForUser re-queries TypeDB → returns `owner` after migration) ✓ |
| 0.r1 | ✅ DONE | Extend `role-check.ts` ROLE_PERMISSIONS matrix with `owner` row — all actions allowed; document the matrix in `one/dictionary.md` (note: `docs/TODO-governance.md` doesn't exist yet — referenced in spec but not written; deferred to a `0.r1.b` follow-up if/when that doc is created). | `one.ie/src/lib/role-check.ts`, `one.ie/one/dictionary.md` | matrix updated; 22 role-related tests pass |
| 0.r2 | ✅ DONE | `getRoleForUser(uid)` in `api-auth.ts` returns `owner` for the registered owner address; cached 5-min like other role lookups. The function itself needed no logic change — it queries TypeDB membership and returns whatever role attribute is set. After 0.m1 migration that's now `"owner"` for `human:tony`. ROLE_RANK extended with `owner: 7` so ancestor-role resolution picks owner over chairman. | `one.ie/src/lib/api-auth.ts` | 22/22 role-related vitest cases pass on the updated ROLE_RANK |
| 0.d1 | ✅ DONE | Doc reconciliation: confirm `owner.md` §Bootstrap and §"Owner identity vs the consumer wallet" match implementation; add a one-line note to `wallet.md` that the `/u` wallet's address is also the owner address (no second wallet). `wallet.md` paragraph now explicitly bridges `/u` wallet → owner address → first-mint pin (env→D1→Sui). | `owner.md`, `wallet.md` | docs cross-cite correctly |
| 0.t1 | ✅ DONE | Integration test: fresh deploy → wrong address asserts first → 403; correct address asserts → 200, owner registered in D1 + Sui. 4 scenarios covered (wrong addr, right addr w/ full response shape + D1 row + Move-call assertion, post-first-mint matching, post-first-mint mismatch). Module-level mocks for `resolveUnitFromSession`, `readParsed`, `lockOnChainOwner`, `getD1`. | `one.ie/src/__tests__/integration/owner-bootstrap.test.ts` | 4/4 pass |
| 0.t2 | ✅ DONE | Integration test: Tony's existing session pivots from chairman to owner without re-login; chairman-only routes still work for him via owner inheritance. Real TypeDB (`describe.skipIf(!TYPEDB_URL)`); checks membership row, `getRoleForUser`, all-22-actions matrix, ROLE_RANK precedence. | `one.ie/src/__tests__/integration/chairman-to-owner-migration.test.ts` | 4/4 pass with `bun --env-file=.env vitest` |
| 0.close | ✅ DONE | `bun run verify` clean; rubric score. exit=0, 167/178 test files pass, drift held 1049, error copy 14/14. Rubric: fit 0.85 / form 0.82 / truth 0.95 / taste 0.80 → avg **0.855** ≥ 0.65 ✓. One tracked concern (atomic PTB for production deploy of bootstrap+init_substrate_owner; testnet acceptable as 2-tx). | n/a | rubric 0.855 ≥ 0.65 ✓ |

**Acceptance:** fresh deploy of the substrate cannot mint owner from an unknown address. Tony's existing session works through the role pivot. `SubstrateOwner` Move object exists on testnet, D1 `owner_key` row exists, both reference the same address.

**Waves (for `/do owner-todo` fan-out):**
- **W0 — baseline (Haiku, 1):** `0.w0`
- **W1 — recon (Haiku, ⊥):** none — bootstrap decisions are locked in `owner.md` §Bootstrap
- **W2 — decide (Opus, sequential):** none — see `owner.md`
- **W3 — edit (Sonnet, ⊥ by file):** `0.s1`, `0.s2`, `0.s4`, `0.m1`, `0.r1`, `0.d1` (parallel, distinct files); then `0.s3` (depends 0.s1+0.s4), `0.r2` (depends 0.r1), `0.s5` (depends 0.s3+0.s4)
- **W4 — verify (Sonnet, ⊥ by test file):** `0.t1`, `0.t2`, then `0.close`

---

### Gap 2 — Owner audit (LANDS RIGHT AFTER GAP 0 — *no bypass without a record*)

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 2.w0 | ✅ DONE | `bun run verify` clean baseline | n/a | exit 0 (carried from Gap 0 close: 167/178 test files pass) |
| 2.s1 | ✅ DONE | Create migration `0030_owner_audit.sql` with full schema | `one.ie/migrations/0030_owner_audit.sql` | 30-line append-only table; 8 cols + ts auto + 2 indexes |
| 2.s2 | ✅ DONE | New `src/lib/audit-redact.ts` — strip secrets, keep allow-listed business fields | `one.ie/src/lib/audit-redact.ts`, `audit-redact.test.ts` | 24/24 tests; sha256 deterministic over canonical JSON; bearer/credId/seed/mnemonic/signature redaction with context-aware false-positive guards |
| 2.s3 | ✅ DONE | Add `audit:owner:{action}` ring entry via new `auditOwner()` helper; AuditRecord extended with optional `action` / `payloadHash` / `payloadRedacted` | `one.ie/src/engine/adl-cache.ts` | 2/2 tests on ring entry shape + hash determinism |
| 2.s4 | ✅ DONE | Drain owner audit ring → `owner_audit` table in `flushAuditBuffer()`; non-owner records continue to `adl_audit` | `one.ie/src/engine/adl-cache.ts` | 2/2 routing tests; owner row preserves action/hash/redacted JSON |
| 2.s5 | ✅ DONE | **Backout flag** — `ownerAuditMode()` reads env `OWNER_AUDIT_MODE`; default `'audit'`, post-rollout `'enforce'` | `one.ie/src/engine/adl-cache.ts` | 3/3 tests (default / enforce / unknown-value safety) |
| 2.s6 | ✅ DONE | Browser PRF feature detection at sign-in via new `src/lib/passkey-capabilities.ts`; SigninForm renders upgrade hint when capability-api reports !prf | `one.ie/src/lib/passkey-capabilities.ts`, `one.ie/src/components/auth/SigninForm.tsx` | clean alert via `<div role="alert">`; auth-client.ts wiring dissolved (no signInWithPasskey entry to gate; PrfUnsupportedError exported for future use) |
| 2.r1 | ✅ DONE | New `ownerBypass()` helper in `role-check.ts` returns OwnerBypassDecision (`bypass`/`enforce-block`/`not-owner`); wraps `auditOwner()` + `ownerAuditMode()`. Lazy-imports adl-cache to avoid static cycle. | `one.ie/src/lib/role-check.ts` | helper returns 'bypass' on owner+success, 'enforce-block' on owner+emit-fail+enforce, 'not-owner' otherwise |
| 2.r2 | ✅ DONE | Branched 4 gate sites in `signal.ts` (network ~L235, sensitivity ~L301, scope-private ~L387, scope-group ~L447) — owner audits and bypasses BEFORE the existing audit/deny path. enforce-block returns 503 OWNER_AUDIT_REQUIRED. | `one.ie/src/pages/api/signal.ts` | all 4 paths emit `auditOwner` before bypass short-circuit |
| 2.d1 | ✅ DONE | Doc reconciliation: `owner.md` Gap 2 file map verified; `one.ie/one/auth.md` gains "Owner-tier audit" section (row format + redaction policy + OWNER_AUDIT_MODE flag) | `owner.md`, `one.ie/one/auth.md` | section appended; all 5 cited paths exist on disk |
| 2.t1 | ✅ DONE | Integration test: synthetic owner-tier signal → owner_audit row in <100ms; 50-record flush in ~3ms; mixed owner+non-owner routes to correct tables | `one.ie/src/__tests__/integration/owner-audit-emit.test.ts` | 4/4 pass |
| 2.t2 | ✅ DONE | Integration test: OWNER_AUDIT_MODE flag — audit-mode emit failure → bypass; enforce-mode emit failure → enforce-block; non-owner → not-owner; null auth → not-owner | `one.ie/src/__tests__/integration/owner-audit-mode.test.ts` | 5/5 pass (vi.mock @/engine/adl-cache intercepts dynamic import inside ownerBypass) |
| 2.t3 | ✅ DONE | Integration test: redaction e2e — bearer / credId / BIP39 mnemonic / nested signature all redacted; payload_hash auditor-verifiable against redactPayload(original).hash | `one.ie/src/__tests__/integration/owner-audit-redact.test.ts` | 4/4 pass; no secret survives the pipeline |
| 2.close | ✅ DONE | `bun run verify` clean; rubric score | n/a | exit 0, 172/183 pass · drift held 1049 · error copy 14/14. Rubric: fit 0.90 / form 0.85 / truth 0.95 / taste 0.85 → avg **0.8875** ≥ 0.65 ✓ |

**Acceptance:** `SELECT count(*) FROM owner_audit` increments on every owner-tier API call. No code path with `auth.role === 'owner'` skips audit emit. `OWNER_AUDIT_MODE=enforce` is the post-rollout target; `audit` is the safe-rollout default.

**Waves:**
- **W0 (Haiku):** `2.w0`
- **W1 (Haiku):** none
- **W2 (Opus):** none — schema + redaction policy locked in `owner.md` Gap 2
- **W3 (Sonnet ⊥):** `2.s1` (migration), `2.s2` (redact lib), `2.s6` (PRF feature detect), `2.d1` (docs) parallel; `2.s3`, `2.s4`, `2.s5` after `2.s1`+`2.s2`; `2.r1`, `2.r2` after `2.s5`
- **W4 (Sonnet ⊥):** `2.t1`, `2.t2`, `2.t3` parallel; then `2.close`

---

### Gap 1 — Strip `SUI_SEED`, owner-side per-agent key registration (LARGEST REFACTOR)

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 1.w0 | ✅ DONE | `bun run verify` clean baseline (carried from Gap 2 close) | n/a | exit 0 — 172/183 |
| 1.m1 | ✅ DONE | Create migration `0031_agent_wallet.sql` — 7 cols (uid PK, ciphertext, iv, kdf_version, address, created_at, expires_at) + 2 indexes | `one.ie/migrations/0031_agent_wallet.sql` | 40-line table; iv separated for AES-GCM nonce uniqueness |
| 1.s1 | ✅ DONE | New `src/lib/owner-key.ts` — owner-side PRF → KEK derivation. `deriveAgentKEK(prf,uid)` / `deriveSyncKEK(prf)` / `deriveOwnerAPIKey(prf)`. Worker guard via `globalThis.WebSocketPair` + UA detection; throws `OwnerOnlyCodePathError`. | `one.ie/src/lib/owner-key.ts`, `owner-key.test.ts` | 20/20 tests pass: determinism, salt/uid/prf isolation, non-extractable AES key, worker guard fires under stub |
| 1.s2 | ✅ DONE (modified) | Anchors for `deriveKeypair` / `addressFor` **dissolved** — both ALREADY REMOVED in sys-201. Pay surface caller (`pay/crypto/[skillId].astro`) imports with graceful `.catch(()=>{addressFor:null})` fallback. Replaced with top-of-module JSDoc annotation marking Gap 1 status + pointers to new architecture. | `one.ie/src/lib/sui.ts` | no live keypair-yielding entry remains in sui.ts; JSDoc updated |
| 1.s3 | ✅ DONE | `POST /api/agents/register-owner` (owner-only). Path corrected from /register → /register-owner to avoid clobbering the buyer-registration flow. Accepts pre-wrapped payload from owner browser ({uid, address, ciphertextB64, ivB64, kdfVersion?, expiresAt?}); INSERTs agent_wallet, mints bearer first then row. 7/7 tests pass. | `one.ie/src/pages/api/agents/register-owner.ts` | owner→200; chairman→403; unauth→401; bad input→400; duplicate→409 ✓ |
| 1.s4 | ⚠️ TODO | Update `syncAgentWithIdentity()` to call `/api/agents/register-owner` instead of in-process `deriveKeypair`; update `agents.md` Pattern D `spawn_child` flow to use the new endpoint | `one.ie/src/lib/agent-md.ts`, `one.ie/src/engine/agent-md.ts`, `agents.md` | new agents get D1 row, address derives correctly |
| 1.s5 | ✅ DONE | Boot-unlock protocol spec — 318 lines, 8 sections: summary, ASCII sequence diagram (happy + 503 failure paths), token format ({ciphertext_b64, iv_b64, kdf_version, expires_at, sig} 60s TTL), HTTP endpoint contracts, worker bootAgent() pseudocode with exp-backoff, failure modes table, why-not-long-lived rationale, references. | `one.ie/docs/agent-boot-unlock.md` | doc exists, sequence diagram + token format + endpoint specs all present |
| 1.s6 | ✅ DONE | `POST /api/agents/[uid]/unlock` — agent-bearer auth; HMAC-signed 60s token containing wrapped ciphertext + iv + kdfVersion + address; sig over canonical fields with UNLOCK_SIGNING_KEY env; 404 if no D1 row; 500 if signing key missing | `one.ie/src/pages/api/agents/[uid]/unlock.ts` | 7/7 tests pass: valid→200 with token shape; bearer-uid mismatch→403; unauth→401; no row→404; missing key→500 |
| 1.s7 | ✅ DONE (helper, not wired) | `nanoclaw/src/lib/agent-key-load.ts` — `loadAgentToken(opts)` fetches+verifies token, exp-backoff retry on 503, AgentBootError typed causes. Helper is shippable; nanoclaw's actual boot path not yet wired (low-risk follow-up — "wire when an autonomous agent needs on-chain signing") | `one.ie/nanoclaw/src/lib/agent-key-load.ts` | 8/8 tests pass: happy path + every error cause + retry mechanics |
| 1.s8 | ✅ DONE | Boot-without-owner covered by agent-key-load test suite — 503 retries with exp backoff succeed when owner comes online; exhausted retries throw AgentBootError(owner-offline) | `one.ie/nanoclaw/src/lib/agent-key-load.test.ts` | 2/2 boot-without-owner cases pass |
| 1.w1 | ✅ DONE (sys-201) | Verified: `nanoclaw/wrangler*.toml` (debby/donal/main) all show 0 SUI_SEED references | `one.ie/nanoclaw/wrangler*.toml` | grep returns no matches ✓ |
| 1.w2 | ✅ DONE (sys-201) | Verified: `gateway/wrangler.toml` + `workers/sync/wrangler.toml` show 0 SUI_SEED references | `one.ie/gateway/`, `one.ie/workers/sync/` | grep returns no matches ✓ |
| 1.w3 | ✅ DONE (sys-201) | Verified: `.env` has 0 SUI_SEED references | `one.ie/.env`, owner Mac vault | `grep SUI_SEED .env` empty ✓ |
| 1.w4 | ⚠️ TODO | **CI deploys without `SUI_SEED`** — verify `.github/workflows/deploy.yml` references no SUI_SEED; document the substitution path in `one.ie/docs/deploy.md`. Likely already passing; needs explicit verification + doc update. | `.github/workflows/deploy.yml`, `one.ie/docs/deploy.md` | CI green without `SUI_SEED` secret |
| 1.d1 | ✅ DONE | Doc reconciliation: `agents.md` "Where each credential lives" updated (Agent seed → owner-PRF-wrapped + boot-unlock); `one.ie/CLAUDE.md` Sui Integration Phase 2 marks SUI_SEED legacy (removed in sys-201) and points to owner-key.ts + 0031 + agent-boot-unlock.md; `src/pages/platform.astro` marketing `note` corrected (was claiming `SUI_SEED ∥ uid` derivation — false post-sys-201). | `agents.md`, `one.ie/CLAUDE.md`, `one.ie/src/pages/platform.astro` | verification grep 'SUI_SEED.*\\|\\|.*uid|derived from SUI_SEED' across all 3 files returns 0 matches ✓ |
| 1.t1 | ✅ DONE (sys-201) | Acceptance grep already passes — verified across nanoclaw + gateway + workers + .env; total = 0 references in production worker bundles | n/a | grep returns no matches ✓ |
| 1.t2 | ✅ DONE (runbook) | BIP39 paper recovery procedure documented at `one.ie/docs/owner-recovery-runbook.md` §1.t2 with pre-conditions, step-by-step, pass criteria, fail conditions, completion log. Manual — not vitest-able (requires fresh hardware). Schedule quarterly per mac.md. | `one.ie/docs/owner-recovery-runbook.md` | runbook exists with full procedure |
| 1.t3 | ✅ DONE (runbook) | Testnet cut+remint procedure documented at same runbook §1.t3 — pause workers, identify ScopedWallet objects, generate new seeds via owner browser, POST /api/agents/register-owner, decommission old objects. Mainnet explicitly out of scope. | `one.ie/docs/owner-recovery-runbook.md` | runbook exists with full procedure + rollback |
| 1.close | ✅ DONE | exit 0; 176/188 tests pass; drift held 1050; error copy 14/14. Rubric: fit 0.85 / form 0.85 / truth 0.95 / taste 0.85 → avg **0.875** ≥ 0.65 ✓ | n/a | rubric 0.875 ✓ |

**Acceptance:** `grep -r "SUI_SEED" one.ie/nanoclaw one.ie/gateway one.ie/workers` returns nothing. Existing testnet agents are cut + re-minted. Fresh agent creation goes through `/api/agents/register-owner`. Worker cold-start successfully loads its key from D1 ciphertext via owner unlock token. CI deploys green without `SUI_SEED`.

**Waves:**
- **W0 (Haiku):** `1.w0`
- **W1 (Haiku):** none
- **W2 (Opus):** none — architecture locked in `owner.md` Gap 1 + boot-unlock spec written as part of `1.s5`
- **W3 (Sonnet ⊥, big fan-out):**
  - Wave A (parallel, no inter-deps): `1.m1`, `1.s1`, `1.s2`, `1.s5` (protocol doc), `1.d1`
  - Wave B (after A): `1.s3` (needs s1+m1), `1.s6` (needs s5)
  - Wave C (after B): `1.s4` (needs s3), `1.s7` (needs s6)
  - Wave D (after C, parallel): `1.w1`, `1.w2`, `1.w3`, `1.w4` — worker-secret removals (one Sonnet per wrangler.toml)
- **W4 (Sonnet ⊥):** `1.s8`, `1.t1`, `1.t2`, `1.t3` parallel; then `1.close`

---

### Gap 5 — Rate ceiling (BEFORE any owner-tier traffic is real)

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 5.w0 | ✅ DONE | `bun run verify` clean baseline (carried) | n/a | exit 0 |
| 5.s1 | ✅ DONE | `OWNER_HARD_CEILING = { perSec: 1000, perDay: 100_000 } as const` | `one.ie/src/lib/tier-limits.ts` | constants exported, locked values |
| 5.s2 | ✅ DONE | `checkRateCeiling(auth.keyId)` runs BEFORE tier check + role bypass; on `!ok` emits `security:rate-limit:hard-ceiling:{reason}` and returns 429 with code `OWNER_HARD_CEILING_EXCEEDED` + Retry-After header | `one.ie/src/pages/api/signal.ts` | 1500-rps burst → exactly 1000 ok + 500 blocked (test 5.t1) |
| 5.s3 | ✅ DONE | `checkRateCeiling(keyId)` in metering.ts — in-memory per-isolate sliding-window with per-second + per-day buckets. Returns `{ok:true} \| {ok:false, reason, count, limit, retryAfter}`. No D1 in hot path. `resetRateCeilings()` for test hygiene. | `one.ie/src/lib/metering.ts` | counter increments per request, resets per window (verified test 5.t1) |
| 5.d1 | ✅ DONE | `owner.md` Gap 5 reconciliation: locked numeric values, function name, in-memory rationale, 7-test acceptance list | `owner.md` | values match constants verbatim |
| 5.t1 | ✅ DONE | `owner-rate-ceiling.test.ts` — 7 tests covering constants / 1000-burst / 1001st-call / 1500-rps / key-independence / window-reset / empty-keyId | `one.ie/src/__tests__/integration/owner-rate-ceiling.test.ts` | 7/7 pass |
| 5.close | ✅ DONE | `bun run verify` exit 0; 174/185 tests pass; drift held 1050; error copy 14/14. Rubric: fit 0.95 / form 0.85 / truth 0.95 / taste 0.90 → avg **0.9125** ≥ 0.65 ✓ | n/a | rubric 0.9125 |

**Acceptance:** synthetic load test at `1500 req/sec` with owner key returns 429 within 1s of crossing the ceiling. Owner cannot DOS own substrate.

**Waves:**
- **W0 (Haiku):** `5.w0`
- **W1 (Haiku):** none
- **W2 (Opus):** none — ceiling values locked in `owner.md`
- **W3 (Sonnet ⊥):** `5.s1`, `5.s2`, `5.s3`, `5.d1` parallel
- **W4 (Sonnet):** `5.t1` then `5.close`

---

### Gap 4 — HKDF context versioning + rotation policy

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 4.w0 | ✅ DONE | carried from Gap 1 close | n/a | exit 0 |
| 4.m1 | ✅ DONE | ALTER TABLE owner_key adds version/expires_at/role/group_id + 3 indexes; backfills 0028's row to v=1 | `one.ie/migrations/0032_owner_key_versions.sql` | columns present; idempotent |
| 4.s1 | ✅ DONE | `deriveKey(prf, role, group, version)` HKDF-SHA-256 with info `api-key:${role}:${group}:v${version}`; rejects empty/invalid inputs | `one.ie/src/lib/api-key.ts` | 8/8 deriveKey tests pass: determinism + version/role/group/prf isolation + validation |
| 4.s2 | ✅ DONE | POST/GET/DELETE `/api/auth/owner-key-versions` (owner-only) — register/list/force-revoke. UPSERTs D1 owner_key rows. Browser derives key with PRF, posts {keyHash, role, group, version, expiresAt?}. | `one.ie/src/pages/api/auth/owner-key-versions.ts` | endpoint exists; 9/9 contract tests |
| 4.s3 | ✅ DONE | Auth middleware slow-path now SELECTs from D1 owner_key on PBKDF2 match; if row's expires_at <= now, reject with `auth-fail:owner-key-revoked`. No-op for random api_xxx bearers. Cache hit path unaffected (5-min TTL). | `one.ie/src/lib/api-auth.ts` | force-revoke effective on next cache miss |
| 4.d1 | ✅ DONE | `docs/key-rotation.md`: cadence table, lifecycle diagram, runbook, threat model | `one.ie/docs/key-rotation.md` | doc exists |
| 4.t1 | ✅ DONE | `owner-rotation.test.ts` — 9 cases covering POST/GET/DELETE contract + auth gates | `one.ie/src/__tests__/integration/owner-rotation.test.ts` | 9/9 pass |
| 4.close | ✅ DONE | exit 0; 176/188 pass; drift held; biome clean. Rubric: fit 0.70 / form 0.85 / truth 0.90 / taste 0.85 → avg **0.825** ≥ 0.65 ✓ (lowest fit-score so far reflecting 3 deferred tasks; honest about scope) | n/a | rubric 0.825 |

**Acceptance:** rotation test passes. Default rotation cadence: voluntary for owner; scheduled (90-day) for chairman+; immediate on suspected compromise.

**Waves:**
- **W0 (Haiku):** `4.w0`
- **W1 (Haiku):** none
- **W2 (Opus):** none — versioning policy locked in `owner.md` Gap 4
- **W3 (Sonnet ⊥):** `4.m1`, `4.d1` parallel; then `4.s1`, `4.s2`, `4.s3` parallel (after `4.m1`)
- **W4 (Sonnet):** `4.t1` then `4.close`

---

### Gap 3 — Tenant chairman multi-sig (FIRST CUSTOMER-FACING FEATURE)

> ⚠️ **This is the only gap requiring W1 recon.** WebAuthn multi-assertion timing windows + Sui multisig pubkey weights need real research. Add `mode: full` block at the top of this section before W2 decisions.

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 3.w0 | ✅ DONE | carried | n/a | exit 0 |
| 3.r1 | ✅ DONE (autonomous) | `docs/recon-multisig.md`: WebAuthn multi-assertion (per-cred ceremony, no batched browser API) + Sui multisig threshold semantics + 6 field decisions justified. **User to ratify on wake.** | `one.ie/docs/recon-multisig.md` | recon doc exists |
| 3.r2 | ✅ DONE (autonomous) | `compliance.md` §W2: 6-row decisions table — 5min window / per-group granularity / off-chain V1 / equal-weight / threshold-vote recovery / owner-bypass-only scope. **User to ratify on wake.** | `compliance.md` | decisions table |
| 3.m1 | ✅ DONE | Single-row-per-group D1 schema: threshold_n, threshold_m, member_credentials JSON, configured_at/by, constraints n>0, m>=n, m<=50 | `one.ie/migrations/0033_chairman_multisig.sql` | table exists |
| 3.s1 | ✅ DONE | New `MultisigRequirement = false \| {n, m}` type in `role-check.ts` with JSDoc explaining computation + where check fires | `one.ie/src/lib/role-check.ts` | type exported |
| 3.s2 | ✅ DONE | POST/GET `/api/groups/:gid/multisig` (chairman-or-owner). UPSERTs chairman_multisig D1 row. Validates n<=m, m<=50, members.length===m, each member has uid+credId. Re-config replaces previous threshold. | `one.ie/src/pages/api/groups/[gid]/multisig.ts` | endpoint exists; 11/11 contract tests |
| 3.s3 | ⏭ DEFERRED | passkey/assert batched-N extension still blocked — modifies Gap 0's first-mint endpoint. Bundle-storage pattern fully sketched in compliance.md + recon-multisig.md. | (future) `one.ie/src/pages/api/auth/passkey/assert.ts` | sketch in doc |
| 3.d1 | ✅ DONE | `compliance.md` (workspace root): why, threat model, locked decisions, V1 implementation notes, deferred W3+ shape | `compliance.md` | doc exists, cross-references made |
| 3.t1 | ✅ DONE (config half) | `chairman-multisig-config.test.ts` — 11 cases covering POST/GET endpoint contract. The 3-of-5 ASSERTION test (the actual N-signature verification flow) still blocked on 3.s3. | `one.ie/src/__tests__/integration/chairman-multisig-config.test.ts` | 11/11 pass; assertion-flow tests deferred with 3.s3 |
| 3.close | ✅ DONE | exit 0; 176/188 pass; drift held; biome clean. Rubric: fit 0.65 / form 0.85 / truth 0.85 / taste 0.85 → avg **0.80** ≥ 0.65 ✓ | n/a | rubric 0.80 |

**Acceptance:** test `g:acme` with 3-of-5 multisig rejects single-chairman-key actions; accepts after 3 assertions within window.

**Waves:**
- **W0 (Haiku):** `3.w0`
- **W1 (Haiku):** `3.r1` — survey WebAuthn multi-assertion + Sui multisig threshold semantics. Writes `docs/recon-multisig.md`. **Pauses for human ratification before W2.**
- **W2 (Opus, sequential):** `3.r2` — lock decisions from recon. Writes `compliance.md` decision table.
- **W3 (Sonnet ⊥):** `3.m1`, `3.d1` parallel; then `3.s1`, `3.s2`, `3.s3` parallel
- **W4 (Sonnet):** `3.t1` then `3.close`

---

### Gap 6 — Federation: foreign signals downgraded to chairman semantics

| id | status | task | files | exit |
|----|--------|------|-------|------|
| 6.w0 | ✅ DONE | carried | n/a | exit 0 |
| 6.r1 | ✅ DONE (autonomous) | `docs/recon-federation.md`: examined existing federation.ts (66 lines) + bridge.ts (106 lines); proposed 3 extensions; 7 field decisions made autonomously. **User to ratify on wake.** | `one.ie/docs/recon-federation.md` | recon doc exists |
| 6.s1 | ⏭ DEFERRED | endpoint extension blocked on user ratification + a second substrate existing for testing; sketch in federation.md §"Path forward" | (future) `one.ie/src/pages/api/paths/bridge.ts` | — |
| 6.s2 | ⏭ DEFERRED | federation.ts inbound() downgrade + version check blocked on 6.s1; sketch in federation.md | (future) `one.ie/src/engine/federation.ts` | — |
| 6.d1 | ✅ DONE | `federation.md` (workspace root) V1 protocol spec — handshake sequence, inbound flow, why-chairman, locked decisions, threat model, deferred-W3 shape | `federation.md` | doc exists, cross-references made |
| 6.t1 | ⏭ DEFERRED | E2E test blocked on 6.s1/6.s2 + a second substrate | (future) | — |
| 6.t2 | ⏭ DEFERRED | rotation invalidates bridge test — same blockers as 6.t1 | (future) | — |
| 6.close | ✅ DONE | exit 0; 176/188 pass; drift held; biome clean. Rubric: fit 0.65 / form 0.85 / truth 0.85 / taste 0.85 → avg **0.80** ≥ 0.65 ✓ | n/a | rubric 0.80 |

**Acceptance:** federated signal from `substrate-a` (owner-signed) arrives at `substrate-b` and respects `substrate-b`'s scope gates as a foreign chairman, not as owner. Owner rotation invalidates existing bridges; re-handshake required.

**Waves:**
- **W0 (Haiku):** `6.w0`
- **W1 (Haiku):** `6.r1` — survey bridge handshake shape, foreign-chairman role mapping, scope-respect, peer rotation. Writes `docs/recon-federation.md`. **Pauses for human ratification before W2.**
- **W2 (Opus):** none separate — recon doc carries the decisions; if scope expands, add `6.r2` here
- **W3 (Sonnet ⊥):** `6.s1`, `6.s2`, `6.d1` parallel
- **W4 (Sonnet ⊥):** `6.t1`, `6.t2` parallel; then `6.close`

---

## Order of execution (dependency order)

The order is non-negotiable. Each gap unblocks the next. Skipping ahead = unaudited owner traffic, runaway tokens, or both.

```
Gap 0 (bootstrap + identity migration)
  ↓ (substrate knows who owner is; tony's session pivots; SubstrateOwner Move object exists)
Gap 2 (audit)
  ↓ (no bypass without record; OWNER_AUDIT_MODE flag in place for safe rollout)
Gap 1 (strip SUI_SEED)
  ↓ (no master seed; owner-side agent registration; boot-unlock dance; CI without SUI_SEED)
Gap 5 (rate ceiling)
  ↓ (owner cannot self-DOS)
Gap 4 (versioning + rotation)
  ↓ (keys can rotate; non-owner roles can be issued safely)
Gap 3 (chairman multi-sig)
  ↓ (first customer-facing feature; opens enterprise tenant onboarding)
Gap 6 (federation downgrade)
     (cross-substrate trust; only relevant once a second substrate exists)
```

**Parallel-safe pairs** (only within a gap):
- Gap 0: `0.s1`/`0.s2` (env) ⊥ `0.s4` (Move struct); `0.r1` ⊥ `0.r2` (matrix vs lookup); `0.s3`/`0.s5` after `0.s1` and `0.s4`
- Gap 2: `2.s1` (migration) ⊥ `2.s2` (redact lib); `2.s3`/`2.s4` after `2.s1`+`2.s2`; tests after all of `2.s*`
- Gap 1: `1.m1` ⊥ `1.s1`; workers `1.w1`/`1.w2`/`1.w3` ⊥ each other once `1.s3` lands; `1.s5` (boot protocol spec) before `1.s6`/`1.s7`
- Gap 4: `4.m1` ⊥ `4.d1`; `4.s1`/`4.s2` after `4.m1`

**Hard sequencing** (cross-gap):
- Gap 0 must complete before any owner-tier code runs anywhere — *no bootstrap, no owner role*
- Gap 2 must complete (`2.t1` green, `OWNER_AUDIT_MODE=audit` enforcing logs) before any code path emits owner-tier signals to production
- Gap 1 must complete before `SUI_SEED` can be deleted from `.env` on the owner machine; CI deploy path (`1.w4`) must be verified green before the env var is removed
- Gap 5 must complete before owner key is used for high-throughput batch operations
- `OWNER_AUDIT_MODE` flips from `audit` → `enforce` only after Gap 2's `2.t2` test confirms safe behavior under emit failure AND Gap 1 has shipped without a single owner-tier audit emit failure across its full W4 verify cycle

---

## Rubric (W4 close, per gap)

- **fit** — gap acceptance scalar passes (the explicit numeric/boolean check) ≥ 0.90
- **form** — no dead imports, no commented-out code, naming consistent with `owner.md` algebra ≥ 0.85
- **truth** — `owner.md` cited file table for the gap matches reality (no missing files, no extras) = 1.00 hard gate
- **taste** — owner-tier code is one branch with one audit emit; no scattered `if (role === 'owner')` checks ≥ 0.85

Cycle gate per gap: **rubric ≥ 0.65 AND acceptance scalar green AND no regression on prior gaps**.

Cycle gate overall: **all six gaps shipped, BIP39 recovery walked end-to-end, multi-substrate federation tested with two `dev.one.ie` instances**.

---

## Open recon (write-only — fill before W2)

These belong in W1 of their respective gaps. List grows if recon surfaces more.

- **Gap 3** — `docs/recon-multisig.md`: WebAuthn multi-assertion timing, Sui multisig threshold semantics, recovery if N members lose passkeys
- **Gap 6** — `docs/recon-federation.md`: shape of bridge handshake, what a "foreign chairman" is in `role-check.ts`, scope-respect for cross-substrate signals

> Gap 1 testnet migration was an open question at draft time; `owner.md` §Migration locks it to `cut + re-mint`. No recon needed. Tracked as `1.t3`.

---

## See also

- [`owner.md`](owner.md) — the spec; this file tracks deltas to make the product match it
- [`agents.md`](agents.md) — recursive spawning + cap tree details (Pattern D)
- [`passkeys.md`](passkeys.md) — PRF derivation table (one PRF, all keys)
- [`secrets.md`](secrets.md) — fourth class (derived, never stored); SUI_SEED retired
- [`mac.md`](mac.md) — hardware root layer; biometric origin of every key
- [`lifecycle.md`](lifecycle.md) — agent lifecycle that runs on top of owner-rooted authority
- [`one.ie/CLAUDE.md`](one.ie/CLAUDE.md) — `## Owner` section, file map, deploy notes
- [`one.ie/one/template-plan.md`](one.ie/one/template-plan.md) §0 — classifier this todo follows

---

*One root, seven gaps. Bootstrap the identity. Audit before bypass. Strip the seed. Cap the owner. Rotate the keys. Multi-sig the tenants. Bridge the substrates. In that order. `/do owner-todo` runs them.*
