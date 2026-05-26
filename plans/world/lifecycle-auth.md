# Auth Lifecycle — one fingerprint, two outcomes

**Source of truth for everything called "sign in" or "sign up" in the ONE product.** Replaces `passkeys.md` (architecture deep-dive — keep that for the why), `one.ie/one/auth.md`, `one.ie/one/auth-integration.md`, `one.ie/one/auth-todo.md`, `one.ie/docs/wallet-link-plugin.md`, `one.ie/docs/wallet-wrap-backup.md` for the user-facing flow.

---

## The one-line truth

**User clicks "Sign in" → Touch ID prompt → they are signed in if they have an account, signed up if they don't. No email, no password, no second screen.** New accounts also see their 24-word recovery phrase exactly once.

**The unbreakable contract:** the same passkey always returns the same wallets. Sign out, clear all browser data, fly to another country, sign in on a fresh laptop — wallets reappear. See _The wallet-persistence guarantee_ below; if that ever fails, the product is broken.

Everything else in this doc is the receipt for those two sentences.

---

## Sessions are indefinite

Once signed in, the user stays signed in until they explicitly **Sign out** (or **Lock**). There is no automatic expiry.

- **Better Auth session cookie:** `expiresIn: 365 days` (browsers cap cookies at 400 days per RFC 6265bis; Better Auth rejects anything higher). Sliding-window refresh on every authenticated request — `updateAge: 24h` — issues a fresh cookie each day of activity. An active user stays signed in indefinitely; only a full 365-day idle gap signs them out.
- **Vault auto-lock:** disabled by default (`autoLockMs: 0`). The vault stays unlocked across page reloads until the user clicks **Lock** in the dropdown menu, signs out, or runs `Vault.lock()` programmatically.
- **Persistent vault session:** The unlocked master key (a non-extractable Web Crypto `CryptoKey`) is mirrored into IndexedDB store `one-vault > session`. Page reloads, route changes, and tab close-and-reopen all resume the unlock without a Touch ID prompt. `Vault.lock()` and Sign out clear the row.
- **Sign out closes both:** the dropdown's Sign out calls `Vault.lock()` then `authClient.signOut()`. There's no signed-in-but-vault-locked-after-signout state.

If a user wants idle auto-lock back, `Vault.setAutoLockMs(ms)` is still exposed (floor 1 min, `0` = never). Settings UI for this is future work.

## The single button

There is one button in the header (`src/components/Header.tsx`). Its label tracks one of three states:

| State | Label | Action |
| --- | --- | --- |
| Signed out | **Sign in** | `signInWithPasskey()` — full server flow (creates account if no credential) |
| Signed in, vault locked | **Unlock** | `Vault.unlockWithPasskey()` — local-only, no network |
| Signed in, vault unlocked | _identity chip_ | Address · wallet count · role · dropdown (Lock, Sign out, nav) |

There is no separate "Sign up". There is no separate "Vault unlock". There is no intermediate dialog. Clicking the button takes the user straight to the OS Touch ID / Face ID / Windows Hello prompt.

`signInWithPasskey()` (`src/components/u/lib/vault/passkey-cloud.ts`) does two things:

1. **Existing user:** WebAuthn assertion → server returns wrappedMaster + session cookie → vault unlocked from cloud blob → done.
2. **New user (server returns 401 "no credential registered" after a successful WebAuthn assertion):** **automatic pivot** to `createAccountWithPasskey()`. Server mints a Better Auth user, stores the credential, returns a session. Client generates a 24-word BIP-39 phrase, derives the master from it, wraps the master twice (server envelope + local enrollment), and the only post-success UI is `RecoveryPhraseDialog` showing the phrase once.

**Critical:** the pivot is server-driven only. We do **not** short-circuit to create-account based on client-side state, because a fresh browser with a synced iCloud passkey looks identical to a fresh browser with no account at all. Only the server can tell them apart by looking up the credential id. Skipping the assertion would mint a duplicate account on top of an existing identity.

The user never types an email, a password, or a phrase. **Touch ID counts:**
- **Existing user, signed-out, returning to the same browser (vault locked):** 1 (the local-unlock short-circuit, no network).
- **Existing user, fresh browser, synced credential:** 1 (the `.get` assertion; server resolves the credential and signs them in).
- **Brand-new user, fresh browser:** 1 if the platform returns PRF on `.create` (Apple Passwords, recent Chromium); 2 if it requires the fallback `.get`. Plus an OS picker dismissal if the user is presented with one for an empty credential set — that dismissal is not a biometric on Apple but may be on Windows Hello.

---

## The wallet-persistence guarantee

**The product contract:** a user who signs in with the same passkey gets back the same wallets, every time, on any device. Sign out, clear all browser data, fly to another country, sign in on a fresh laptop — wallets reappear. This is the single most important invariant of the system. Everything below exists to make it true.

How the guarantee chains together:

1. **Same passkey → same master.** Each credential is identified by its WebAuthn `cred_id`. The server stores `wrappedMaster` against that `cred_id` exactly once, at account creation, and never rotates it. Sign-in looks up the row, returns the ciphertext, the client unwraps it with PRF — and the recovered master is bit-identical to the one that originally encrypted the wallets. Same master, every time.
2. **Same master → same wallet blob.** Wallets are persisted as an AES-GCM envelope (`vault_blob`) keyed by `user_id`, encrypted under HKDF(master, "vault.sync.export.v1"). Sign-out and IDB wipe never touch this row — it's server-side. Decrypting with the recovered master returns the exact wallet set as before.
3. **Every wallet mutation is synced.** `saveWallet` and `deleteWallet` fire `notifyMutation()` → `syncToCloud()` → `PUT /api/vault/sync`. The client never considers a wallet "saved" without this round-trip — see the Sync watermark below.

**What sign-out does and doesn't touch:**

| Storage | Sign out | `Vault.wipeAll()` | Browser "Clear site data" | Server breach |
| --- | --- | --- | --- | --- |
| IndexedDB `one-vault > meta` (passkey enrollment) | unchanged | wiped | wiped | unaffected |
| IndexedDB `one-vault > wallets` | unchanged | wiped | wiped | unaffected |
| IndexedDB `one-vault > session` (unlocked CryptoKey) | wiped | wiped | wiped | unaffected |
| Cookie `better-auth.session_token` | wiped | unchanged | wiped | unaffected |
| D1 `vault_passkey_hints` (cred_id → user + wrappedMaster) | unchanged | unchanged | unchanged | exposed but useless without PRF secret |
| D1 `vault_blob` (encrypted wallet envelope) | unchanged | unchanged | unchanged | exposed but useless without master |

The two D1 rows are the durable backbone. Together with the user's authenticator (which holds the only thing that can produce the PRF secret), they regenerate the entire vault on demand.

**Sync watermark — close the race.** `saveWallet` resolving its Promise does NOT mean the cloud blob is up to date — it means the local IDB write succeeded and a PUT is in flight. If a user creates a wallet and immediately Signs out, the cloud envelope may still be the previous one. Two protections:

- The sign-out menu item should `await Vault.flushPendingSync()` before calling `authClient.signOut()`. (Helper to be added; tracked in Roadmap §0.)
- The recovery-phrase modal already gates the user before they can do anything mutating, so the first-ever sync isn't at risk.

---

## The architecture in 6 lines

```
Browser                                           Server                    Storage
─────────────────────────────────────────────────────────────────────────────────────
1. Touch ID → WebAuthn assertion + PRF output
2. Send assertion         →   verify + lookup     →   D1.vault_passkey_hints
3. ←  session cookie + wrappedMaster
4. PRF unwraps master     →   GET /api/vault/fetch →  D1.vault_blob
5. ←  encrypted vault blob (ciphertext only)
6. Decrypt → IndexedDB.one-vault → wallets live
```

The server stores **only ciphertext + a public key**. The master never leaves the device. The recovery phrase is the only path back if both passkey and cloud blob are lost.

---

## The eight files that matter

| File | What |
| --- | --- |
| `src/components/Header.tsx` | The button — calls `signInWithPasskey()` directly, no intermediate dialog |
| `src/components/auth/RecoveryPhraseDialog.tsx` | Post-success modal shown only on new-account creation |
| `src/components/u/lib/vault/passkey-cloud.ts` | `signInWithPasskey`, `createAccountWithPasskey` |
| `src/components/u/lib/vault/vault.ts` | `adoptMaster`, `exportRawMaster`, `importSyncBlobWithMaster` |
| `src/components/u/lib/vault/sync.ts` | Cloud blob upload/fetch/restore |
| `src/lib/auth-plugins/passkey-webauthn.ts` | All four server endpoints (register-anonymous, authenticate, etc.) |
| `src/pages/api/vault/sync.ts` + `fetch.ts` | The encrypted-blob endpoints |
| `src/lib/human-unit.ts` | `ensureHumanUnit` — TypeDB governance integration |

Three D1 tables: `vault_passkey_hints` (cred_id → user + wrappedMaster), `vault_blob` (user_id → encrypted vault), `wallet_backups` (legacy, **delete**).

---

## Code that must be deleted

The current shipping code carries leftovers from the pre-passkey-cloud era. They confuse users (the "two passkeys" problem from earlier sessions) and contradict this doc.

| File / table | Why dead |
| --- | --- |
| `src/components/u/VaultSetupWizard.tsx` | Local-only setup wizard. Creates a *second* passkey just for local unlock, with its own recovery phrase that doesn't match the BIP-39 phrase shown by the new flow. Replace every caller with the passkey-cloud path. |
| `Vault.setup({ enrollPasskey, password })` in `vault.ts` | The local-only setup function. After deleting the wizard, this is unused. |
| `migrations/0021_wallet_backups.sql` and the table | Created for a Firefox fallback that no client code writes to. Drop. |
| Password unlock paths in `vault.ts` (`unlockWithPassword`, `setPassword`) | Vault unlock is now via passkey only; password sign-in via Better Auth survives at the *account* layer for users without passkey hardware, not at the vault layer. |
| `SigninForm.tsx` "Continue with Sui wallet" button (`disabled`, "Soon") | Either ship it or delete the placeholder. |

`SigninForm.tsx` itself stays — it's the password fallback for Firefox-without-PRF users. `CloudRestorePanel.tsx` stays — it's the cold-restore-from-phrase path after a password sign-in on a fresh device.

---

## What survives from the old docs

These facts from the retired docs are still true and live in the code. They don't need their own doc.

- **Wallet derivation:** Every Sui keypair the user owns is derivable from the 32-byte master. The master is the BIP-39 phrase. (Today there's only one wallet per chain; agent-wallet derivation paths are future work.)
- **State 3 — Linked:** When the user signs in, `ensureHumanUnit(user.id, ...)` (`src/lib/human-unit.ts`) creates a TypeDB `unit(unit-kind="human")` + personal group + chairman membership. This is what makes the human a governance root for any future agent (`/Users/toc/Server/lifecycle.md`).
- **Cloud envelope:** Encrypted under `HKDF(master, info="vault.sync.export.v1")`. AES-GCM. Server holds ciphertext only.
- **Passkey wrap:** Master wrapped under `HKDF(prf_secret, info="vault.passkey-cloud.wrap.v1")` for the server hint, and under a domain-separated info string for the local enrollment record (`vault.v2.master.check.passkey.<credId>`). Same PRF secret, two subkeys, never cross-decrypt.
- **Browser compat:** Safari ≥ 17, Chrome ≥ 118 with platform authenticator + PRF. Firefox falls through to password sign-in + cold restore.

---

## Test plan — gate this doc behind passing all of these

Manual passes count. Where Vitest applies, write the test in `src/__tests__/integration/auth-passkey-lifecycle.test.ts`.

### A. New account, fresh browser

1. Clear all site data for `localhost:4321`.
2. Click **Sign in** in header.
3. Click **Sign in with passkey**. → OS picker shows nothing yet → server returns 401 → flow auto-pivots to create.
4. Touch ID confirms credential creation. Second Touch ID prompt confirms PRF capture.
5. Recovery-phrase screen appears with 24 words. **Copy** button works. **I've saved it** checkbox gates **Continue**.
6. Click Continue → page reloads. Header shows the unlocked vault chip with `0 wallets`.
7. Verify in DevTools:
   - `Application > Cookies > better-auth.session_token` exists, 30-day expiry.
   - `Application > IndexedDB > one-vault > meta` has one record with one entry in `passkeys[]`.
   - `D1 vault_passkey_hints` (or in-memory dev fallback) has one row with the user's id.
   - `D1 vault_blob` has no row yet (no wallets to sync).

### B. Same account, second sign-in same browser

1. Lock vault (chip → click Unlocked → Lock).
2. Click **Sign in** in header.
3. Click **Sign in with passkey**. → OS picker shows existing credential → Touch ID → vault unlocked.
4. Verify `signInWithPasskey()` short-circuited via `Vault.unlockWithPasskey()` (no network round-trip — check Network tab; nothing should hit `/api/auth/passkey-webauthn/authenticate`).

### C. Same account, fresh browser (cold restore via passkey)

1. Same passkey synced via iCloud Keychain to a second browser/device.
2. Click **Sign in** in header → Touch ID → server finds cred_id → returns wrappedMaster + session.
3. Vault is bootstrapped from cloud blob (`/api/vault/fetch` → 200 if any wallets existed, else `adoptMaster` only).
4. No recovery phrase shown — this is recognised, not new.

### D. Existing user, fresh browser, passkey not synced

1. Click **Sign in with passkey** → user cancels picker (no matching credential) → flow throws `passkey-cancelled`. Crucial: it does **not** silently create a new account.
2. User clicks **Sign in with password instead** → `SigninForm` → email + password.
3. After successful password sign-in, `hasCloudBlob() && !hasVault()` is true → `CloudRestorePanel` appears asking for the 24-word phrase.
4. User pastes phrase → `restoreFromCloud(phrase)` decrypts blob → vault seeded → wallets back. **No second Touch ID needed.**

### E. Browser data wiped, all phrases lost

1. Account is unrecoverable. Confirm: server has cred_id but cannot help — wrappedMaster only unwraps if the physical authenticator runs PRF. Phrase only useful if user wrote it down.
2. User must `createAccountWithPasskey()` again. Old cloud blob is orphaned (no longer reachable). This is correct: ONE cannot recover what only the user holds.

### F. Wallet creation while signed in

1. After test A, navigate to `/u`. Click **Create Wallet** for any chain.
2. New wallet appears. `Vault.saveWallet` fires → IndexedDB updated → `notifyMutation` → `syncToCloud` PUTs the new envelope to `D1 vault_blob`.
3. Sign out (or `Vault.lock()`), then go through test B → wallet is still there after unlock.

### F-bis. **The persistence guarantee** — _the most important test_

This is the contract from the "wallet-persistence guarantee" section above. If this test ever fails, the product is broken.

1. Sign in fresh (test A). Navigate to `/u`. Create three wallets across different chains (e.g. ETH, SUI, BTC).
2. Wait for the cloud sync to settle: open Network tab, confirm `PUT /api/vault/sync` returns 200 for each. Or query D1: `SELECT updated_at FROM vault_blob WHERE user_id = ?` should be within the last few seconds.
3. Click **Sign out** in the dropdown. Confirm the cookie is gone, IDB session row is gone, but `D1 vault_blob` and `D1 vault_passkey_hints` are still present.
4. Open DevTools → Application → Storage → **Clear site data** (everything: cookies, IndexedDB, cache, local storage). Reload.
5. Click **Sign in** in the header. Touch ID once.
6. Header shows the signed-in chip with the wallet count `3`.
7. Navigate to `/u`. **All three wallets are present** with the same addresses. No "Create Wallet" prompt, no missing chains.
8. Spot-check by signing a tx on one of the chains — keys decrypt correctly under the recovered master.

If step 7 shows fewer than three wallets, suspect the sync watermark race (Roadmap §0). If addresses differ from before, the master was not the same — investigate why `wrappedMaster` returned by the server didn't decrypt to the original 32 bytes.

### F-ter. Cross-device persistence

Sub-variant of F-bis. Same passkey synced to a second browser/device via iCloud Keychain.

1. After F-bis step 1 (three wallets on Device A), do nothing on Device A.
2. On Device B (different machine, same iCloud account), open `one.ie` for the first time. Click **Sign in** → Touch ID → land in the account with the same three wallets.
3. Create a fourth wallet on Device B. Within a few seconds, refresh on Device A — you should see four wallets after a `getStatus()` re-fetch (the WebSocket / refresh cycle for cloud-blob delta is future work; manual reload is the current path).

### G. Two-passkeys regression

This is a regression check: with the dead-code deletions complete, opening the OS passkey picker on `localhost` for ONE shows **at most one credential per account**. If you see "ONE Vault" and "ONE" both, `VaultSetupWizard` is still wired somewhere.

### H. ensureHumanUnit fires

After test A, query TypeDB: `match $u isa unit, has uid "<user_id>", has unit-kind "human"; select $u;` → one result. Personal group + chairman membership exist. Failing this means future agent spawn won't have a governance root.

### I. Migrations applied

In production, `bun wrangler d1 migrations apply <db>` shows `0022_vault_blob` and `0023_vault_passkey_hints` applied. `0021_wallet_backups` will be in the migration history but is documented as dead.

---

## Threat model

What we defend against, and what we accept.

| Attack | Defended? | How |
| --- | --- | --- |
| Server breach (D1 dumped) | ✅ | Server holds only `wrappedMaster` ciphertext + public key. The wrap key is HKDF(prf_secret); only the user's authenticator produces the prf_secret. The recovery phrase never crosses the wire. |
| Network MITM | ✅ | TLS + cookie. The cookie alone unwraps nothing. |
| Stolen device, encrypted disk (FileVault on) | ✅ | IndexedDB is wrapped by OS-level keys. No OS login = no IDB. |
| Stolen device, OS unlocked | ⚠️ partial | The browser opens our origin signed-in. **Step-up biometric on signing** (see Roadmap §1) reduces this to "the thief can read public state but cannot spend or export." Without step-up, the thief can spend up to whatever wallets are in the vault. |
| Malicious browser extension (broad host permissions) | ❌ | Extension JS runs as us. Step-up prevents auto-spending in the background but not deliberate abuse if user keeps approving. |
| XSS / script injection on our origin | ❌ | Same as extension. Mitigations: strict CSP, SRI on every CDN script, no `eval`, no inline `<script>`. **Audit pending.** |
| Compromised build pipeline (we ship a malicious bundle) | ❌ | Catastrophic. Defended only by build hygiene + code review — out of band. |

The non-extractability of the IndexedDB `CryptoKey` stops one specific thing: an attacker copying the IDB blob to disk and using the raw 32 bytes elsewhere. It does **not** stop attacker JS in our origin from *using* the key in place. That's why step-up matters.

---

## Roadmap (prioritised)

### 0. Sync watermark + `flushPendingSync()` — **highest priority**

Protects the persistence guarantee. Without this, a user who creates a wallet and Signs out within a second of clicking can lose the wallet on next sign-in (the in-flight `PUT` is cancelled when the cookie is wiped).

Spec:

- Add a counter `pendingSyncs` and a resolver list inside `vault/sync.ts`. Every `syncToCloud()` invocation increments before fetch, decrements on settle, and resolves any waiters once the counter hits zero.
- Export `Vault.flushPendingSync(timeoutMs = 5000): Promise<void>` — resolves when no syncs are in flight, or after the timeout (in which case the user is still allowed to sign out, but we surface a small toast: "Wallet sync still in progress; try again or check the device you'll sign in on next").
- Sign-out menu item awaits `flushPendingSync()` before `Vault.lock()` and `authClient.signOut()`.
- Test M: create a wallet, immediately click Sign out, watch Network — the `PUT /api/vault/sync` should complete before `POST /api/auth/sign-out`. After clearing site data and signing back in, the new wallet is present.

### 1. Step-up biometric on signing

Today: user taps Touch ID once at unlock. After that, every wallet read and every signing operation rides that authority forever (until lock).

Goal: the unlock authority gates **reading the vault state** (chip + wallet list). A separate, fresh PRF gates **anything that costs money or reveals a secret** — signing a tx, exporting a private key, revealing the recovery phrase.

Concrete spec:

- **Gated operations** (require fresh PRF):
  - `Vault.signTx(walletId, txBytes)` — new method, replaces direct seed access for transaction signing
  - `Vault.getMnemonic(walletId)` — already exists; add the gate
  - `Vault.getPrivateKey(walletId)` — already exists; add the gate
  - `Vault.revealRecoveryPhrase()` — new method (also closes the post-creation reveal gap)

- **Free operations** (no fresh PRF, just unlocked session):
  - `Vault.listWallets()` / `getWallet()` — public addresses + balances
  - `Vault.saveWallet()` — adding a chain entry doesn't sign anything
  - `Vault.deleteWallet()` — destructive locally but doesn't move funds; debate whether to gate

- **Implementation:**
  - Reuse `passkeyUnlock(enrollment)` from `vault/passkey.ts` — that's already a one-shot Touch ID that returns the PRF secret.
  - Cache the fresh PRF in memory for **15 seconds** so multi-step UI flows (build → review → sign) don't double-prompt; cache wiped on tx submit. **No persistence** — never goes to IDB.
  - On gated method, check cache; if expired or empty, prompt; on user cancel, throw `passkey-cancelled`, abort the operation.
  - UI: signing buttons show a fingerprint icon to set expectations.

- **Docs/test plan additions:**
  - Test J: signing requires a fresh Touch ID even with vault unlocked.
  - Test K: 15-second grace window — sign two txs in 5 seconds with one Touch ID; sign two 30 seconds apart needs two.
  - Test L: cancelling the step-up prompt aborts cleanly without locking the vault.

### 2. Strict CSP audit + SRI on CDN scripts

Audit `astro.config.mjs` and any inlined `<script>` tags. Goal: `Content-Security-Policy: default-src 'self'; script-src 'self' <hashes>; …` — no `unsafe-inline`, no `unsafe-eval`. Subresource integrity hashes on every third-party script. This closes the "compromised CDN ships malicious JS as us" hole.

### 3. Multi-device passkey enrollment UI

`registerPasskeyForSignin()` exists; needs a "Add another passkey" button in vault settings. Useful for users who want a YubiKey backup, or who switch ecosystems (iPhone → Windows).

### 4. Sign-out destination + post-signout state

Today Sign out goes to `/`. Better: take the user to a "Signed out — Sign in again" landing page so they don't get re-signed-in by an auto-redirect. Confirm: vault is locked, IDB session row is cleared, cookie deleted.

### 5. Decide: Sui wallet sign-in promotion

The `suiWallet` Better Auth plugin works but has no UI button. Either ship a "Sign in with Sui wallet" option (for users who already have a Sui wallet from elsewhere and want to bring it) or delete the plugin. Currently dead code.

### 6. Hardware key (State 4)

Scoped wallet on-chain via `scoped_wallet::create<T>`. Tracked in `lifecycle.md § 2`. Distant.

### Rejected (don't re-litigate)

- **Lock-on-window-close:** considered, rejected. Marginal security gain (only mitigates the "stolen unlocked-OS device" attack), real friction (every browser session costs a Touch ID). Step-up biometric on signing protects the actual high-value operations more cleanly.

---

## What this is *not*

- **Not the agent lifecycle** — see `lifecycle.md` for `Absent → Conceived → Live → Paused → Evolved → Retired`. That's about agents the user spawns. This doc is about the user themselves.
- **Not the on-chain wallet wrapping spec** — `passkeys.md` still owns the cryptographic deep-dive (PRF salt, HKDF info strings, AES-GCM envelope). Read this doc for what; read passkeys.md for why.
- **Not a feature roadmap** — it's the contract. If the code stops matching this doc, fix the code.

---

## See also

- [`lifecycle.md`](lifecycle.md) — agent lifecycle (this doc's downstream)
- [`passkeys.md`](passkeys.md) — cryptographic architecture (this doc's upstream)
- [`mac.md`](mac.md) — security threat model for the device root
- [`one.ie/CLAUDE.md`](one.ie/CLAUDE.md) — the implementation brief

---

*One button. One fingerprint. Two outcomes. Everything else is implementation.*
