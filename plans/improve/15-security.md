# 15-security — gap analysis

Source: `text/15-security.md`. Comparison against code at `web/`, `claw/`, `agents/`.

---

## Promise

What the marketing page sells:

1. **Keys you own.** Seed lives only on-device in the Secure Enclave / passkey. Server never sees seed material. PRF + AES-256-GCM unwrap; `extractable: false` import; seed bytes zeroed after each sign.
2. **5-state wallet lifecycle.** Ephemeral → Saved (Touch ID + largeBlob) → Linked (Google) → Multi-device → Recovered (BIP39). Same address across all states.
3. **BIP39 break-glass.** Words shown once at State 2, never stored by the platform. Platform only holds `bip39_shown_at` flag.
4. **Per-tenant KEK.** `HKDF(MASTER_KEK, gid)` → one KEK per agency client. `forget(uid)` deletes the KEK; data becomes ciphertext rubble instantly. Cross-tenant reads impossible "by absence of the decryption key."
5. **8-step PEP.** Every signal clears ABAC + RBAC + ReBAC + capability + budget + rate-limit + nonce-dedup + delivery before reaching an agent. Fails closed.
6. **Move-bound agent authority.** Scoped Wallet enforces caps + allowlists + pause + revoke at consensus. Biometric floor uncrossable.
7. **Dual-admin for destructive ops.** Owner transfer, tenant delete, bridge creation need two signed signals in 15 min.
8. **Quarterly canary tx.** Deterministic signing-chain verification, binary outcome.
9. **Tool approval gate** on every LLM tool call that touches state.
10. **WsHub revocation in <1s.**

---

## Code reality

| Area | What ships |
|---|---|
| Passkey | `web/src/lib/passkey.ts` + `web/src/pages/api/{provision,auth,commit}.ts`. Used as a **login gate**, not as a wallet wrap key. SimpleWebAuthn server lib; no PRF extension requested anywhere in the registration ceremony (`PasskeyCreate.tsx` lines 34-51 — no `extensions: { prf: ... }`). |
| Wallet | `web/src/pages/api/payments/wallet.ts` returns `address: null, balance: { sui: '0', eth: '0' }` and a `TODO: W5` for chain reads. No signer, no IndexedDB wallet, no `wrappings[]`, no `largeBlob`. The wallet specced in `passkeys.md` is unbuilt. |
| BIP39 | `web/src/pages/api/provision.ts` lines 213-225: `generateMnemonic()` runs **server-side**, words are transmitted over the wire in the response (`recoveryWords`), `PBKDF2(mnemonic, slug)` hash stored in `owners.recovery_hash`, client stashes the words in `sessionStorage`. |
| Tenant KEK | None. `web/src/lib/pii/vault.ts` uses **one platform-wide** `env.PII_ENVELOPE_KEY` to encrypt all PII rows. `seal()`/`unseal()` just check `env.DB && env.PII_ENVELOPE_KEY`; no `gid`-derived key. `shred(uid)` blanks `ciphertext = ''` and sets `shredded_at` — doesn't delete or rotate the master key. |
| 8-step PEP | Not present. No file enforcing ABAC/RBAC/ReBAC/capability/budget/rate-limit/nonce-dedup/delivery in order. Only rate limits exist (`wrangler.toml` `RATE_PROVISION/AUTH/DOMAIN/SETTINGS/RECOVER`) and basic slug-vs-session checks per endpoint. |
| Move scoped wallet | No on-chain Move module shipped. Agent-side signing not wired. `wallet.ts` is a stub. |
| Dual-admin destructive ops | No dual-signature path for owner transfer or tenant delete. `forget` flow runs as a single authenticated call. |
| Canary tx | No quarterly canary job. No cron entry verifying signing chain. The two production crons are `0 * * * *` and `0 2 * * *` (analytics), not security. |
| Tool approval | `claw/src/aitools.ts` sets `needsApproval: true` on `remember`, `summarize`, `pay_capability` (3 of N tools). UI flow that actually shows the approval prompt is not visible in the surveyed components; the AI SDK protocol exists but downstream wiring to user confirmation is unclear. |
| WsHub revocation | No revocation broadcaster found. Sessions live in KV with 7-day TTL; sign-out deletes the KV row, but a stolen cookie can still be used until the row is deleted from the device that holds it. No instant push-revoke to connected workers. |
| Roles | 4-tier `Viewer` model exists (`roles.md`, `src/lib/viewer.ts`). Cascade is documented; enforcement at the API layer is per-endpoint slug-comparison, not a uniform PEP. |
| Session | HMAC cookie (`one-session`) + KV-backed session cookie. `httpOnly`, `sameSite: 'lax'`, `secure` off for `localhost`. No CSP header observed in middleware; no SRI on script tags; no token binding to UA/IP. |
| TOS | Captured (`tos_hash = 'v1'` + `tos_signed_at`). Hash is a string literal, not a hash of the actual ToS text — version label only. |

---

## Threat model rows holding / not holding

| Row from `15-security.md` | Holds? | Reason |
|---|---|---|
| Phishing / credential reuse | Partial | Passkey is domain-bound (good). But registration uses no PRF, so there is no seed-wrap to phish — the only thing a phish gains is a session cookie. The "no password to phish" claim holds. |
| Stolen / lost device | Partial | Passkey is SE-bound (good). Session cookie on the stolen device is valid for 7 days with no fast-revoke. Wallet signing is not yet implemented, so no funds at risk yet — but the marketing claim implies there are. |
| Apple ID takeover | Partial | Out of ONE's control by design. Holds at the architectural-claim level. |
| Seed phrase exposure | **Broken** | Server generates the mnemonic and ships it back over HTTPS. PBKDF2 hash is stored in `owners.recovery_hash`. Three contradictions with the page: (1) "platform holds a flag" — platform holds a hash with 100k-iteration PBKDF2 that is offline-attackable if D1 leaks; (2) "never sent over the network" — it is sent in the registration response; (3) `sessionStorage.setItem('rc:words', ...)` writes the words to a JS-accessible storage on the client. |
| Supply chain | Partial | `bun.lock` committed. No evidence of `socket.dev` CI step, no SRI on script tags, no documented pinning policy in repo. |
| XSS / compromised JS | **Broken for the wallet claim** | The wallet doesn't exist on-device. The actual XSS surface is the session cookie (`httpOnly`, so not directly readable) + the `sessionStorage` recovery words during the registration session. Once the wallet ships, the "State 1 cap" doesn't exist either — there's no capping code. |
| Rogue on-chain agent | Not yet applicable | No on-chain agent path. Move module not shipped. The "biometric floor uncrossable" guarantee depends on a code path that isn't there. |
| Cross-tenant data probe | **Broken** | One `PII_ENVELOPE_KEY` for the whole platform. A compromised env, a leaked D1 backup, or a bug that returns the wrong `uid` reads every tenant. `forget(uid)` does not delete a per-tenant KEK; it blanks ciphertext rows whose D1 backups still hold the prior value. |
| Prompt injection | Partial | Zod schemas on tools (good). `needsApproval: true` on 3 tools (good). But: most tools don't gate, and the user-facing approval UI surface isn't verified. |
| Insider threat / destructive ops | **Broken** | No dual-signature requirement anywhere. Owner-transfer / tenant-delete / bridge-create are not gated. |
| GDPR deletion | **Broken** | `forget(uid)` rests on `shred(uid)` which sets a row flag and blanks ciphertext bytes. D1 backups retain the old ciphertext, which the platform-wide `PII_ENVELOPE_KEY` can still decrypt. "Effectively gone" overstates what the code does. |

---

## Gaps

1. **The wallet doesn't exist.** `passkeys.md`'s 5-state lifecycle, PRF wrapping, `largeBlob`, `wrappings[]`, `extractable:false` signing flow are not in the code. `wallet.ts` is a stub. The page's most-emphasised claim — "tap their finger, the payment goes through" — has no on-device signer behind it.
2. **BIP39 is server-generated and server-hashed.** Direct contradiction of three statements on the page. Either (a) move generation client-side and stop transmitting/storing the words, or (b) rewrite the page to say the platform holds a PBKDF2 hash for slug-recovery.
3. **Per-tenant KEK is absent.** The page leans heavily on `HKDF(MASTER_KEK, gid)` as the cross-tenant isolation primitive. Code has one master key for all PII. `forget()` is a row-flag, not a key-destruction.
4. **8-step PEP is absent.** No ordered policy chain. Enforcement is ad-hoc, per endpoint.
5. **Dual-admin destructive ops** unbuilt.
6. **Quarterly canary tx job** unbuilt; no signing chain to canary.
7. **No CSP / SRI.** The page promises hardened frontend with strict CSP, allowlisted origins, SRI on every script. Neither is present in `Layout.astro` headers nor in middleware (verify in `web/src/middleware.ts`).
8. **Session model is bearer-cookie**, not bound to passkey assertions per write. The page implies "every write requires a fresh WebAuthn assertion" (and `authentication.md` confirms that is the intent for `/api/commit`), but most state-mutating endpoints accept a session cookie alone.
9. **No revocation broadcast.** No WsHub-style push; 7-day KV TTL on sessions; no `version`/`generation` on tokens to fast-invalidate.
10. **No incident-response runbook in repo.** Page describes a 4-step ceremony; runbook file not present.
11. **Tool approval UX surface** unverified — `needsApproval: true` exists on a few tools but the user-facing confirmation flow needs end-to-end verification.
12. **`sessionStorage` recovery words** linger across the tab session — readable by any same-origin script during the window between `rc:words` set and the user landing on the recovery-codes page.

---

## Recommended improvements

**Cycle 1 — stop the bleeding (truth-in-marketing).**

- Either ship the BIP39 client-side (recommended) or remove the "never sent over the network / platform holds a flag" copy from `15-security.md`. Lowest-risk-fix: move `generateMnemonic` into `PasskeyCreate.tsx`, hash on the client, POST only the hash. Drop `sessionStorage` writes; pass words through a `BroadcastChannel` to the recovery-codes page once, then evict.
- Strip or rewrite the per-tenant KEK section until `pii/vault.ts` derives `HKDF(MASTER, gid)` and stores `kms_key_id` per row. Until then, the cross-tenant claim is aspirational.
- Soften the wallet narrative to "coming with State 2; today the wallet endpoint is a stub" — or accelerate `wallet.md`/`passkeys.md` implementation before the page goes live.
- Annotate the threat model with `status: shipped | planned | aspirational` per row.

**Cycle 2 — close the highest-impact gaps.**

- Implement on-device wallet per `passkeys.md` §State 1-2: IndexedDB seed, passkey + PRF wrap, largeBlob storage with server-side ciphertext mirror (per `passkeys.md` §Browser & device support resolved item). `extractable: false` import, `fill(0)` after sign.
- Per-tenant KEK in `pii/vault.ts`: derive `seal/unseal` key from `HKDF(env.PII_MASTER, gid)`. `forget(gid)` writes the master derivation to a tombstone table whose lookup fails after deletion. Document that D1 PITR backups retain ciphertext for the retention window.
- Add CSP (`default-src 'self'`, no `unsafe-inline`, no `unsafe-eval`) + SRI on every external `<script>` / `<link>`. Add to `web/src/middleware.ts` or `Layout.astro` head.
- Move state-mutating endpoints to require a fresh WebAuthn assertion via `/api/commit`-style ceremony (already implemented for one path; extend pattern).
- Implement the 8-step PEP in `web/src/middleware.ts` or `web/src/lib/security/pep.ts`: a single function `enforce(signal, ctx)` called from every route mutation. Today's ad-hoc checks become rows in a documented chain.
- Add dual-signature gate for owner-transfer / tenant-delete: D1 table `destructive_intents (id, op, args, signed_by, signed_at)`; require two distinct slugs within 15 min before execute.
- Cron a canary signing tx once on-chain signing exists. Until then, cron a canary `seal` → `unseal` round-trip + integrity audit log emit.

**Cycle 3 — verification & operations.**

- Add `web/runbook.md` with the 4-step incident response from the page.
- Add `socket.dev` / `pnpm audit` (here: `bun audit`) to CI.
- Pen-test scope doc per `15-security.md` §Pen-test cadence.
- Wire WsHub revocation: bump a per-session `gen` column on revoke; middleware rejects cookies whose `gen` doesn't match.
- Verify tool-approval UX end-to-end in `claw` chat surface; document which tools require approval and which intentionally don't.

---

## Files to touch

| Path | Action |
|---|---|
| `web/src/pages/api/provision.ts` | Stop generating BIP39 server-side. Accept client-generated `recovery_hash` only. Remove `recoveryWords` from response. |
| `web/src/components/auth/PasskeyCreate.tsx` | Generate mnemonic client-side; derive hash client-side; POST hash only. Replace `sessionStorage` with `BroadcastChannel` + immediate eviction. Request `extensions: { prf: ... }` in registration once wallet wrap exists. |
| `web/src/lib/pii/vault.ts` | Add `gid` parameter to `seal`/`unseal`. Derive key via `HKDF(MASTER, gid)`. Track `kms_key_id` per row. `shred(gid)` becomes per-tenant key destruction. |
| `web/src/lib/security/pep.ts` (new) | Implement the 8-step PEP. Export `enforce(signal, ctx)`. |
| `web/src/middleware.ts` | Add CSP + SRI helper headers. Call `pep.enforce()` on state-mutating routes. |
| `web/src/pages/api/payments/wallet.ts` | Replace stub. Read on-chain balance; wire signing flow once `passkeys.md` State 2 ships. |
| `web/src/lib/wallet/` (new) | IndexedDB schema (`wrappings[]`), `wrap()`, `unwrap()`, `sign()`, `restoreFromMnemonic()` per `passkeys.md` §Signing flow. |
| `web/src/pages/api/destructive.ts` (new) | Dual-signature gate for owner-transfer / tenant-delete / bridge-create. |
| `web/src/pages/api/canary.ts` (new) + `wrangler.toml` cron | Quarterly canary endpoint + cron entry. |
| `claw/src/aitools.ts` | Audit which tools should be `needsApproval: true`; today only `remember`, `summarize`, `pay_capability` are gated. |
| `claw/src/agents/builder.ts` | Verify `needsApproval: price > 0` mapping holds for all paid skills. |
| `web/runbook.md` (new) | Incident-response runbook per page §Incident response. |
| `web/threat-model.md` (new or fold into `authentication.md`) | Per-row `status: shipped | planned | aspirational` table. |
| `text/15-security.md` | Reconcile copy with shipped reality. Add status labels per claim. |
| `text/15-security.md` cross-refs | Mark `passkeys.md`, `agents.md`, `mac.md` claims as architecture intent until corresponding code lands. |
