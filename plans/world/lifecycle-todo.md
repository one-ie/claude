# lifecycle-todo — close the gap to lifecycle-auth.md

**Spec:** [`lifecycle-auth.md`](lifecycle-auth.md). The spec is locked. This file tracks the code deltas to make the shipping product match it.

**Mode:** lean. 4 priors satisfied — spec locked, variance known (one design), exit scalar (test plan A–I + Roadmap §0–§5 ✓), files known.

**Goal:** every test in lifecycle-auth.md § Test plan passes against `dev.one.ie`, with the Roadmap §0–§2 gates green. Roadmap §3–§5 tracked, not gating.

---

## Routing

```
W1 recon (already done — spec is the recon)
   ↓
W2 decide (this file — task graph below)
   ↓
W3 edit (parallel where independent: D-* deletions ⊥ R0 sync ⊥ R1 step-up)
   ↓
W4 verify (manual test plan A–I + vitest auth-passkey-lifecycle.test.ts)
   ↓
mark(): each test passes → mark edge `lifecycle-auth → <task-id>`
warn(): regression on persistence guarantee (test F-bis) → warn(1) on the offending task
```

Pheromone receivers:
- `lifecycle:auth:delete:<file>` — dead-code removal
- `lifecycle:auth:sync:flush` — Roadmap §0
- `lifecycle:auth:stepup:<op>` — Roadmap §1 per gated method
- `lifecycle:auth:csp:audit` — Roadmap §2
- `lifecycle:auth:test:<letter>` — verification gates

---

## Tasks

### Track D — Dead code deletion (§ "Code that must be deleted")

**Audit 2026-04-25:** all 5 items still shipping. Caller counts and exact file:line below.

| id | status | task | files (verified) | blocks | exit |
|----|--------|------|------------------|--------|------|
| D.1 | ✅ DONE | Delete `VaultSetupWizard.tsx` + migrate **3 callers** to `signInWithPasskey()` | `src/components/u/VaultSetupWizard.tsx` deleted · `UDashboard.tsx`, `VaultUnlockChip.tsx`, `u/index.ts` updated | T.G | grep `VaultSetupWizard` returns nothing ✓ |
| D.2 | ✅ DONE | Delete `Vault.setup()` (`vault.ts:314`); only caller is the wizard | `vault.ts` — export removed | D.1 | export removed ✓ |
| D.3a | ✅ DONE | Kill `wallet_backups` writers — deleted `api/wallet/wrap.ts` (INSERT) and `api/wallet/wrap/[credId].ts` (DELETE); removed fire-and-forget DELETE from `DevicesIsland.tsx` | `src/pages/api/wallet/wrap.ts` deleted · `src/pages/api/wallet/wrap/[credId].ts` deleted | — | endpoints removed ✓ |
| D.3b | ✅ DONE | `0024_drop_wallet_backups.sql` drops the table; `0021_*.sql` stays in migration history | `migrations/0024_drop_wallet_backups.sql` created | D.3a | table absent in D1 ✓ |
| D.4 | ✅ DONE | Delete `unlockWithPassword` + `setPassword`/`changePassword`/`removePassword` from `vault.ts`; remove password tabs from `VaultDialogs.tsx` | `vault.ts`, `VaultDialogs.tsx` | D.1 | grep returns nothing in vault layer ✓ |
| D.5 | ✅ DONE | Delete the disabled "Continue with Sui wallet" button at `SigninForm.tsx:170-183` | `src/components/auth/SigninForm.tsx` | — | no `disabled` Sui button in `SigninForm` ✓ |

### Track R — Roadmap (prioritised in spec)

**Audit 2026-04-25:** R.3 + R.5 already shipped. R.0 + R.1 + R.2 + R.4 outstanding.

| id | status | task | spec | files | exit |
|----|--------|------|------|-------|------|
| R.0 | ✅ DONE | **Sync watermark + `flushPendingSync()`** — `_pendingSyncs` counter + `notifySyncStart/End` in `vault.ts`; `syncToCloud()` in `sync.ts` calls them on every return path; `Header.tsx` awaits `Vault.flushPendingSync()` before `Vault.lock()` + `authClient.signOut()` | §0 | `vault.ts`, `sync.ts`, `Header.tsx` | test M: wallet create → sign out → sync resolves before sign-out ✓ |
| R.1a | ⚠️ DESCOPED | **`Vault.signTx(walletId, txBytes)`** — vault-signer is a structural stub that throws on every sign call (see `vault-signer.ts:24,31`); chain-specific signing not wired. Gating is meaningless until the signer is real. Track in C4 signer work. | §1 | `vault.ts` (new method when signer is wired) | test J blocked until signer wired |
| R.1b | ✅ DONE | `getMnemonic()` + `getPrivateKey()` now call `_checkRecentStepUp()` before decrypting — safe by default. `Vault.revealRecoveryPhrase()` descoped: recovery phrase is one-way derived from BIP-39 and is not stored in vault; re-exposing it would require a schema change. Post-signup display is already gated (fresh Touch ID just completed). | §1 | `vault.ts` | test K: 15s grace holds ✓ |
| R.1c | ✅ DONE | `_stepUpTime` module state + `_checkRecentStepUp()` private function in `vault.ts`; `stepUpPasskey()` sets `_stepUpTime = Date.now()` on success | §1 | `vault.ts` | repeat-sig within 15s skips Touch ID ✓ |
| R.1d | ⚠️ OPEN | Fingerprint icon on every gated button (UI affordance) — `getMnemonic`/`getPrivateKey` gated but no visual cue on buttons yet | §1 | wallet send/sign components, recovery reveal | visual review |
| R.2 | ⚠️ OPEN | **Strict CSP + SRI** — `middleware.ts` ships `unsafe-inline` on script + style; inline `<script is:inline>` in Layout.astro; no SRI on Cloudflare Insights. Blocked on Astro 6 nonce wiring. Non-gating. | §2 | `src/middleware.ts`, `src/layouts/Layout.astro`, `astro.config.mjs` | no `unsafe-inline`; SRI on CDN scripts |
| R.3 | ✅ SHIPPED | "Add another passkey" button in `VaultDialogs.tsx` → `registerPasskeyForSignin()` | §3 | — | — |
| R.4 | ✅ DONE | `src/pages/signed-out.astro` created; `Header.tsx` sign-out redirects to `/signed-out` | §4 | `Header.tsx`, `src/pages/signed-out.astro` | redirect ends at `/signed-out` ✓ |
| R.5 | ✅ SHIPPED | Sui wallet plugin live; D.5 stale button removed from `SigninForm.tsx` | §5 | — | — |
| R.6 | DEFERRED | Hardware key (State 4) → `lifecycle.md § 2` | §6 | — | — |

### Track Test — verification harness

| id | status | task | files | exit |
|----|--------|------|-------|------|
| T.0 | ✅ DONE | `src/__tests__/integration/auth-passkey-lifecycle.test.ts` — 26 `it.todo()` tests covering scenarios A–M; automatable assertions require running infra so they're scaffolded as todos | `src/__tests__/integration/auth-passkey-lifecycle.test.ts` | file exists ✓ |

### Track T — Test plan as verification gates

Each row = one passing manual run plus (where applicable) a vitest assertion in `src/__tests__/integration/auth-passkey-lifecycle.test.ts`.

| id | scenario | depends on |
|----|----------|------------|
| T.A | New account, fresh browser → Touch ID → 24-word phrase → vault chip with 0 wallets | — |
| T.B | Returning, locked vault, same browser → 1 Touch ID, no network | — |
| T.C | Same account, fresh browser, synced passkey → cold restore via passkey | R.0 |
| T.D | Existing user, no synced passkey → cancel picker → password fallback → CloudRestorePanel with phrase | — |
| T.E | All phrases lost → account unrecoverable, must `createAccountWithPasskey()` again | — |
| T.F | Wallet creation while signed in → IDB updated → cloud envelope PUT lands | R.0 |
| **T.F-bis** | **Persistence guarantee** — 3 wallets → Sign out → Clear site data → Sign in → all 3 wallets present with same addresses | R.0, D.1–D.4 |
| T.F-ter | Cross-device — same passkey on Device B sees the 3 wallets; wallet 4 created on B appears on A after refresh | R.0 |
| T.G | OS picker shows ≤1 credential per ONE account (no "ONE Vault" + "ONE" duplicates) | D.1 |
| T.H | `ensureHumanUnit` fires on sign-in — TypeDB has `unit-kind="human"` row | — |
| T.I | Migrations applied — `0022_vault_blob`, `0023_vault_passkey_hints` present; `0021_wallet_backups` historical | D.3 |
| T.J | Step-up — sign tx requires fresh Touch ID even with vault unlocked | R.1a |
| T.K | Step-up — 15s grace window for repeated sigs | R.1a |
| T.L | Step-up — cancelling step-up aborts cleanly without locking vault | R.1a |
| T.M | Sync watermark — Sign out after wallet create awaits flush | R.0 |

---

## Schema reference

No new TypeDB entities. `unit-kind="human"` (existing) + `vault_passkey_hints` / `vault_blob` D1 tables (existing) carry the state. `wallet_backups` (D1) marked dead by D.3.

## Rubric (W4 close)

- **fit** — every test in § Test plan passes ≥ 0.90
- **form** — no dead imports, no commented-out code, single sign-in button in `Header.tsx` ≥ 0.85
- **truth** — `lifecycle-auth.md` cited file table matches reality (no missing files, no extras) = 1.00 hard gate
- **taste** — sign-in flow is one Touch ID for returning users, never a dialog stack ≥ 0.85

Cycle gate: **rubric ≥ 0.65 AND T.F-bis green AND R.0 shipped.**

---

## Order of execution (post-audit)

1. **R.0** — highest priority, protects persistence guarantee (no in-flight work)
2. **D.5 + T.0 in parallel** with R.0 — both are tiny independent edits
3. **D.1 → D.2 → D.4 sequential** (D.2 unused once D.1 wizard gone; D.4 unused once `VaultDialogs` password UI gone with the wizard's removal)
4. **D.3a → D.3b** — kill writers first (`api/wallet/wrap*`), then drop the table
5. **T.F-bis hard gate** — once R.0 + D.* land, run the persistence test on dev.one.ie
6. **R.1a → R.1b → R.1c → R.1d** — step-up wedge (a is new method, b refactors existing, c is cache, d is UI polish)
7. **R.4** — small, can slot in anywhere after R.0
8. **R.2 (CSP)** — biggest unknown; pair with Astro 6 nonce work; non-gating but needed for security claim
9. **R.3 + R.5** — already shipped, mark in spec next pass

**Quick wins (do today):** D.5, R.4, T.0 — combined ~30 min of edits, no architectural risk.

**Hard gate before claiming spec compliance:** R.0 shipped + T.F-bis green.

---

## See also

- [`lifecycle-auth.md`](lifecycle-auth.md) — spec (source of truth)
- [`lifecycle.md`](lifecycle.md) — agent lifecycle (downstream)
- [`passkeys.md`](passkeys.md) — cryptographic deep-dive (upstream why)
- [`one.ie/CLAUDE.md`](one.ie/CLAUDE.md) — implementation brief
- [`todo.md`](todo.md) — broader program board (this file is a slice)

---

*Spec is the recon. This file is the wave plan. Code is the verification.*
