# one.ie Wallet — `/u/*` implementation of ephemeral-first wallet

Concrete plan for the `/u/*` pages in `one.ie`. Implementation of the five-state lifecycle from `passkeys.md` on the existing codebase. Target: one Ed25519 signer, one address, zero Mysten backend dependency, ≈ −900 lines.

---

## One-line summary

**Arrive → wallet exists (IndexedDB). Tap "Save" → passkey wraps the seed. Sign in with Google (existing Better Auth) → identity linked. One address forever.** No zkLogin. No Enoki. No salt. No multisig for the common path.

---

## Same pattern, same surface as `passkeys.md`

| Surface | Secret | Gate | Host |
| --- | --- | --- | --- |
| Mac personal | age identity | Touch ID | Secure Enclave + `age-plugin-se` |
| Dev secrets | vault key | Touch ID | `~/.vault.age` + SE |
| Substrate owner role (apex) | owner API key + owner wallet seed | Touch ID | WebAuthn PRF — see `owner.md` |
| Wallet seed | Ed25519 seed | Touch ID (after Save) | WebAuthn passkey PRF + IndexedDB largeBlob |
| Sui agents | agent keypair (owner-PRF-wrapped) | consensus | Move module + D1 ciphertext |

Private key never in JS memory except for microseconds during `sign()`. Biometric gates every signature after State 2. Agent authority is cryptographically bounded by Move — "can't," not "shouldn't." The same PRF that wraps this seed also derives the substrate-owner API key and every agent wallet KEK (different salts, same root). One Touch ID, every key in the substrate. See `owner.md` for the apex role.

**The Sui address derived from this `/u` wallet seed is also the substrate's owner address — there is no second wallet.** First-mint pins it via `OWNER_EXPECTED_ADDRESS` (env) → `owner_key` (D1) → `SubstrateOwner` Move object (Sui). Owner-tier assertions verify a passkey whose derived address equals the registered owner address. See `owner.md` §Bootstrap.

---

## Target

| Need | Tool | State of the codebase today |
| --- | --- | --- |
| Wallet creation | `crypto.getRandomValues(32)` → Ed25519 seed in IndexedDB | DIY 295-line zkLogin plugin in `src/lib/auth-plugins/zklogin.ts` |
| Identity | Better Auth + Google OAuth | **already installed and working** |
| Signing gate | Passkey PRF wrapping the seed | Stub that throws (`src/components/u/lib/signer/zklogin-signer.ts:23`) |
| Address | `Ed25519PublicKey.toSuiAddress()` — single signer | 1-of-2 multisig {zkLogin, passkey} — not wired, now unnecessary |
| Client | `@mysten/dapp-kit` providers at `/u/` root | Installed; unused in `/u/*`; three duplicate `SuiClientProvider` wrappers elsewhere |
| Gas | Our sponsor Worker (CF) | Not wired |
| Recovery | BIP39 (`@scure/bip39`) | Not wired |

---

## Four decisions (confirm before coding)

1. **State 1 balance cap** — default $20. Deposits above cap get refused by sponsor Worker to protect unprotected wallets. Tune later.
2. **Nag-to-Save cadence** — after first tx, then dismissable daily until Saved.
3. **largeBlob fallback** — server-held duplicate ciphertext from day one, so Firefox users don't break.
4. **BIP39 timing** — show at State 2 enrollment. Copy: *"This is your last-resort backup. Write it down."*

---

## Product quality bar

Apple-caliber means the user never reads the word "crypto." The engineering phases below execute *against* this bar — not alongside it. If a phase ships code but misses the bar, it hasn't shipped.

### The first 30 seconds

1. **Land.** `/u` loads. No login. No button. The wallet is **already there** — balance ($0.00), Receive, Send. Address shown in a SuiNS-like short form.
2. **First action.** Receive or small sponsored Send — works instantly. No Touch ID (State 1, no gate).
3. **After first tx.** Soft prompt: *"Save this wallet with Touch ID?"* One tap enrolls the passkey and shows the BIP39 phrase, *"write these down — last-resort backup."*
4. **Later, at leisure.** *"Sign in with Google to follow your wallet to other devices."* — sign-in happens when the user is ready, not as a gate.
5. **Done.** No seed-phrase modal at arrival, no chain picker, no "create account." The product never says "testnet."

Every PR that adds a screen or prompt to `/u/*` has to fit inside this storyboard or justify in writing why it's an exception.

### Money language, not crypto language

Same as before — dollars primary, SUI under disclosure, contacts by name, tx summaries rebuilt from bytes in `src/components/u/lib/money.ts`. No raw addresses without a tap, no `epoch`, no `signature type`.

### Recovery — five journeys, all walked

| Journey | What the user does | What the system does |
| --- | --- | --- |
| **Lost phone, same Apple ID** | Open on iPad / Mac | iCloud Keychain carries passkey + largeBlob ciphertext; Touch ID → wallet live |
| **Lost all Apple devices** | New device, type BIP39 | seed restored → new passkey enrolled → same address live |
| **Never saved, cleared browser** | — | wallet lost by design; State 1 cap limits exposure |
| **Moved to Windows** | Google login → type BIP39 on Windows | new Windows Hello passkey wraps seed; both ecosystems now live |
| **Compromised passkey** | *Settings → Devices → Revoke* | wrapping removed; if exfil suspected, BIP39-restore to a fresh seed at a new address |

**Requirements on the build:**
- Better Auth Google OAuth kept (already works). Apple OAuth optional (add when worth it).
- *Devices* screen in Phase 3 — lists each enrolled passkey credId with revoke.
- `wrappings.ts` helper: add/remove/rotate wrappings in IndexedDB + mirror in largeBlob + mirror in server duplicate.
- BIP39 restore page (`/u/restore`) — one input, one button.

### Peer agents — same primitives, human surface stays human

Unchanged from the prior plan. `/u/*` is the human surface. Peer-agent ownership (see `agents.md` Pattern D) calls ScopedWallet Move entry functions directly. `/u/fleet` (Phase 7) sums transitive exposure across every ScopedWallet rooted in the user's address. Agent-owned ScopedWallets where the user is spender show *"Cap set by <agent-name>"*.

### Error copy

| Technical state | User sees |
| --- | --- |
| Sponsor Worker 5xx | *"Couldn't reach the network. Try again."* |
| Sponsored tx epoch expired mid-sign | *"Took a moment too long — tap Send again."* |
| Sponsor rate limit hit | *"One moment — finishing a previous action."* (auto-retry) |
| WebAuthn user-cancelled | nothing — return silently |
| WebAuthn `NotAllowedError` | *"Touch ID didn't register. Try once more."* |
| Deposit exceeds State 1 cap | *"Save this wallet first to receive larger amounts."* — with Save as the CTA |
| PRF extension unsupported | *"This browser can't save wallets yet. Use Safari 17+ or Chrome 118+."* |
| largeBlob unsupported | *silent* — fallback to server-held ciphertext; log for ops |
| BIP39 entry malformed | *"Those words don't match a wallet. Check each one."* |
| Network timeout >5s | *"Slow connection. Still trying."* with a cancel |

### Perf budget

| Surface | Budget |
| --- | --- |
| `/u` cold paint (to first meaningful balance) | ≤ 400 ms warm, ≤ 1.2 s cold |
| Touch ID prompt after Send tap | ≤ 200 ms |
| Sponsored-tx round trip (Send → confirmed) | ≤ 3 s |
| Agent-approve render | ≤ 500 ms |
| Route change inside `/u/*` | ≤ 100 ms |

Measured with the Performance API → Cloudflare Logpush → p95 alert.

### No vendor on the hot path

This used to be a risk budget for Enoki outages. Now: **the only external dep on the wallet hot path is Sui RPC.** Our sponsor Worker is the only service we operate, and it's ~100 lines. If it goes down, users can still sign — they'd just need to pay their own gas (power-user path, not default).

### Sensory polish + accessibility

Unchanged from prior plan: 200 ms ease-out motion, `prefers-reduced-motion`, no sound, VoiceOver on every button, `aria-live` on balance, Dynamic Type 100–200%, WCAG AA / AAA on primary actions, full keyboard path.

---

## Phases

Each phase is an independently mergeable slice.

### Phase 1 — Root providers + ephemeral wallet

- **Add** `src/components/u/providers.tsx` (~40 lines): `<SuiClientProvider>` + `<WalletProvider>`. No Enoki context.
- **Add** `src/components/u/lib/seed.ts` (~60 lines): generate-or-load seed from IndexedDB, derive Ed25519 keypair, derive address. Idempotent: same seed → same keypair → same address.
- **Add** `src/components/u/lib/idb.ts` (~20 lines): thin wrapper over `idb-keyval` for the `wallet` record.
- Wrap the `/u/*` layout once.
- **Delete** duplicate `SuiClientProvider` in `ChairmanPanel.tsx`, `CryptoAuthPanel.tsx`, `PayPage.tsx`.

**Outcome:** `/u` loads → wallet exists → balance queryable → Receive works. Zero prompts.

### Phase 2 — State 2 enrollment (Save with Touch ID)

- **Add** `src/components/u/lib/wrap.ts` (~80 lines):
  - `enrollPasskey()` — `navigator.credentials.create()` with PRF + largeBlob
  - `wrapSeed(seed, prfOut)` — HKDF → AES-GCM → ciphertext
  - `writeWrapping(credId, ciphertext, iv)` — IndexedDB + largeBlob write + server duplicate write
  - `unwrapSeed(wrapping, prfOut)` — inverse
- **Add** `src/components/u/SavePrompt.tsx` (~50 lines): the soft prompt shown after first tx; runs enrollment; shows BIP39 once.
- **Add** `src/components/u/lib/bip39.ts` (~20 lines): wrap `@scure/bip39` for entropyToMnemonic / mnemonicToEntropy.
- **Add** `src/pages/api/wallet/wrap.ts` (~30 lines): server endpoint to receive the duplicate ciphertext. Stores against Better Auth session if present; stores keyed by credId if anonymous.

**Outcome:** wallet can graduate from State 1 → State 2. Same address. Every sign op from here on fires Touch ID.

### Phase 3 — Signing path + sponsored tx

- **Add** `src/components/u/lib/signer.ts` (~60 lines): unified `sign(txBytes)` that reads wrappings, prompts Touch ID, unwraps, imports non-extractable, signs, wipes. Used by every `/u/*` page.
- **Add** `src/pages/api/sponsor/build.ts` (~40 lines): receive `transactionKindBytes`, wrap with our hot-key gas payment, return `{ bytes, digest }`. Enforces `allowedMoveCallTargets` and per-address rate limits.
- **Add** `src/pages/api/sponsor/execute.ts` (~30 lines): receive `{ digest, signature }`, add sponsor signature, submit to Sui RPC.
- **Add** `src/components/u/lib/send.ts` (~80 lines): client state machine (build → sponsor → sign → execute). Handles epoch expiry retry.

**Outcome:** Send works. Sponsored from our hot key. No Mysten fees.

### Phase 4 — Rewire `/u/*` pages through dapp-kit

Each page becomes a thin view over seed-derived address + the signer.

| Page | Change |
| --- | --- |
| `SignPage.tsx` | Delete mock sig. Real `personalMessage` signing via `signer.ts`. |
| `SendPage.tsx` | Delete localStorage wallet read. Address from `seed.ts`. Send flow via `send.ts`. |
| `WalletsPage.tsx` | Delete localStorage. Single-account view from `seed.ts`. |
| `TransactionsPage.tsx`, `SwapPage.tsx`, `ReceivePage.tsx` | Address from `seed.ts`. |
| `KeysPage.tsx` | Repurpose as *Devices* — list every wrapping (credId + createdAt), revoke action. |
| **New** `/u/save` | SavePrompt host. |
| **New** `/u/restore` | BIP39 entry. |
| **New** `/u/devices` | Wrappings list + revoke. |

### Phase 5 — Better Auth link (State 3)

Session ownership is the existing Better Auth + TypeDB adapter. Google OAuth plugin already in place.

- **Add** `src/lib/auth-plugins/wallet-link.ts` (~40 lines): Better Auth plugin that, after Google OAuth succeeds, reads `walletAddress` + `credId` from the client (sent in a header from the `/u` page), calls `ensureHumanUnit(uid, { id: walletAddress, email, name })`, writes `identity-link(subject: unit, front-door: "google")` and records the credId on the user.
- **No wallet state leaves the browser.** The seed, ciphertext, PRF output — none of it goes to the server through this plugin.
- **Delete** `src/lib/auth-plugins/zklogin.ts` (295 lines). No replacement.
- **Delete** Enoki plugin scaffolding (never shipped).

### Phase 6 — Delete the old machinery

- **Delete** `src/components/u/lib/vault/` (7 files, ~400 lines) — old AES + PBKDF2 + PRF-derived-AES + IndexedDB-blob soup. Replaced by `wrap.ts`.
- **Delete** `zklogin-signer.ts` stub, `dapp-kit-signer.ts` placeholder, `metamask-snap` kind from `types.ts`.
- **Delete** the whole zkLogin code path: `src/components/u/lib/signer/zklogin-*`, any `jwtToAddress` imports.

### Phase 7 — Agent co-sign (no Move yet)

Plain Sui multisig over Ed25519 signers, no zkLogin involved.

- **Add** `src/components/u/lib/agent-sign.ts` (~60 lines): `MultiSigPublicKey.combinePartialSignatures()` over `{agent_ed25519, user_ed25519}` — both plain Sui Ed25519 signers. User's side goes through `signer.ts` (Touch ID).
- **Add** `src/pages/u/approve/[id].astro` + React island (~80 lines): pending-tx view, human summary rebuilt from bytes, Touch ID on Approve.
- **Add** pending-tx store — Cloudflare KV, ~40 lines. Agent POSTs, user retrieves, 5-min TTL.
- **Add** notification trigger — push / email / webhook to the approve URL.
- Agent wallets: `2-of-2 multisig { user_ed25519, agent_key }`. Agent key = scoped age identity per `agents.md`.

### Phase 8+ — Scoped autonomy and capabilities

Same as before. Deploy `ScopedWallet<T>` Move module (≈ 60 lines). Agent signs alone; consensus enforces cap + allowlist + pause + revoke. Client wrapper ~120 lines. See `agents.md`.

---

## Line-count ledger

| | Estimate |
| --- | --- |
| Delete | ~1300 (zkLogin plugin 295, vault 400, signer stubs 100, localStorage wallets 100, duplicate providers 80, metamask-snap 50, zkLogin Move/client scaffolding 100, Enoki wiring attempts 50, any salt/prover stubs 125) |
| Add, Phases 1–4 | ~390 (providers 40, seed 60, idb 20, wrap 80, SavePrompt 50, bip39 20, wrap API 30, signer 60, sponsor build/execute 70, send 80, page rewires 50) |
| Add, Phase 5 | ~40 (wallet-link plugin) |
| Phase 6 | pure deletion |
| Add, Phase 7 | ~210 (agent-sign 60, approve page 80, pending-tx store 40, notifications 30) |
| Add, quality bar | ~210 (money.ts 60, errors.ts 40, Devices screen 60, SavePrompt nag logic 20, BIP39 restore page 30) |
| Add, peer agents | ~100 (Fleet view 70, agent-set cap disclosure 20, `spawn_child` Move 15) |
| **Net** | **≈ −350 lines — *and* real signing, sponsored gas, full 5-state lifecycle, Google-linked identity, BIP39 recovery, agent co-sign, fleet view, peer-agent spawning, zero Mysten backend dep** |

---

## Security properties preserved

- Seed never in JS memory outside `sign()` window (microseconds); imported `extractable: false`
- Origin-bound passkeys — phishing-resistant by the browser
- State 1 balance capped at $20 until Saved — blast radius bounded
- Paper break-glass (BIP39) for catastrophic recovery
- Multi-device via iCloud Keychain / Google Password Manager + WebAuthn largeBlob — OS-level backup, free
- Deploy gated by the root SE identity from `mac.md`
- Hot-path secrets (sponsor hot key) in Cloudflare Workers secrets, not client bundle
- Transaction preview in human terms before Touch ID (per `passkeys.md` §security)

---

## Testnet before mainnet

Unchanged from before. Every phase runs on testnet first via `staging.one.ie`. Consumer `one.ie` ships against mainnet or doesn't ship — no toggle in the production app.

Promotion gate to flip a phase to production:
1. No unresolved error-path bugs for 14 days
2. Sponsored-tx success rate ≥ 99% on the testnet build for that period
3. Self-audit items below all pass on testnet
4. Product quality bar met — first-30-seconds storyboard walked, five recovery journeys exercised, perf budget held at p95, error-copy live

---

## Observability

| Signal | Source | Alert if |
| --- | --- | --- |
| Wallet creation rate | Client beacon on State 1 creation | Sudden drop → front-end broken |
| Save-to-State-2 conversion | Beacon on enrollment success | <X% after N days → SavePrompt UX failing |
| Sponsored-tx success rate | Sponsor Worker return codes | <99% → check hot-key balance, RPC, epoch path |
| Passkey enrollment | Beacon on `wrappings.push` | New enrollment from unusual country / device → email the user |
| BIP39 restore frequency | Beacon on `/u/restore` success | Spike → investigate retention issue |
| Agent action events | Sui `queryEvents` on agent address | Burst outside historical pattern → notify owner |
| `AgentAlive` heartbeat | Move event polled | No event >72 h → stale; >30 d → prompt retirement |

Cloudflare Logpush for server; on-chain indexer (one Worker + KV) for agent heartbeat.

---

## Testing

- **Unit** — plain Bun, mock `crypto.subtle` and IndexedDB at module boundary. Wrap/unwrap round-trips, seed determinism.
- **Integration** — extend `src/lib/api-auth.test.ts` to cover the wallet-link plugin end-to-end against test TypeDB.
- **End-to-end (browser)** — Playwright with WebAuthn virtual authenticator (`addInitScript` + mocked `navigator.credentials`). Walks State 1 → 2 → sign → 3 → 4 (simulated cross-device) → 5 (BIP39 restore).
- **Agent co-sign (Phase 7)** — Playwright with two authenticated contexts.

CI secrets (sponsor hot-key, TypeDB test creds) via platform secret store — not `envr`. See `secrets.md` §dotenvx for the team repo + CI pattern.

---

## Production hardening (close before mainnet)

- **CSRF on sponsor routes** — nonce cookie + header; otherwise open billing vector
- **Per-sender rate limit** — KV rolling window on sponsor calls
- **Epoch expiry** — detect rotation between build and execute; reconstruct tx with explicit error path
- **`allowedMoveCallTargets`** — centralised in `src/lib/sui/allowed-targets.ts`, imported by every sponsor call
- **Sponsor hot-key rotation runbook** — quarterly, or immediate on suspected compromise. Cap balance to limit blast radius
- **largeBlob failure path** — server-held ciphertext duplicate from day one
- **Supply chain** — CSP, SRI, `socket.dev`, pnpm audit in CI
- **Error wrapping** — never leak internal keys, RPC URLs, or raw response bodies to the client

### Sponsor hot-key rotation runbook

**Routine (quarterly):**
1. Generate a new Ed25519 keypair; fund it from cold reserve.
2. `wrangler secret put SPONSOR_KEY_NEW` with the new value; deploy with dual-key support.
3. Verify sponsored-tx success on the new key for 24 h.
4. Rotate `SPONSOR_KEY` to the new value; deploy; drain the old hot key to cold reserve.
5. Update `~/.vault.age [one.ie]` to the new value.

**Suspected compromise:**
1. Drain the hot key to cold reserve immediately (old key should be near-empty by design).
2. Put the replacement key into the Workers secret; deploy.
3. Audit sponsor-route logs for the leak window.

---

## What this replaces

- Mock signing flows
- `localStorage` plaintext wallet state
- Custom AES + PBKDF2 vault with scattered PRF ceremony
- zkLogin plugin (295 lines gone)
- Enoki dependency (never shipped)
- Salt server, prover, JWT / JWKS infrastructure (never built)
- 1-of-2 multisig address machinery — simple one-address model replaces it

---

## Self-audit (when phases done)

- [ ] `/u` cold-loads to a live wallet with zero prompts — measured
- [ ] Seed never appears in logs, network, or persistent state except as ciphertext
- [ ] State 1 balance cap enforced in sponsor Worker
- [ ] SavePrompt fires exactly once after first tx, dismissable, re-nagged per session until Saved
- [ ] BIP39 phrase shown on Save; confirm-one-word required before Save completes
- [ ] Every sign op fires Touch ID in State 2+; never in State 1
- [ ] Seed imported `extractable: false` every sign op; raw bytes wiped after import
- [ ] `src/components/u/lib/vault/` gone
- [ ] `src/lib/auth-plugins/zklogin.ts` gone
- [ ] Zero `SuiClientProvider` outside `src/components/u/providers.tsx`
- [ ] Zero `localStorage` wallet or key reads in `src/components/u/**`
- [ ] Every `/u/*` page reads its address via `seed.ts` (derived deterministically from IndexedDB seed)
- [ ] First `/u/send` triggers Touch ID (if Saved) and produces a real Sui tx on testnet
- [ ] Sponsored tx works end-to-end — user balance 0 SUI, tx still succeeds
- [ ] Cross-device: same BIP39 on a second browser restores the same address
- [ ] largeBlob path tested on Safari 17+ and Chrome 118+; server-duplicate fallback tested by disabling largeBlob
- [ ] WebAuthn `rpId` pinned to `one.ie`; no wildcard subdomain
- [ ] Strict CSP + SRI on built client
- [ ] Sponsor route: CSRF nonce, per-sender rate limit, epoch-expiry error path tested
- [ ] `allowedMoveCallTargets` centralised; every sponsor call references the one config
- [ ] Sponsor hot-key never in client bundle (audited build output)
- [ ] Testnet-first: each phase live on staging ≥14 days before production flip
- [ ] No user-visible `testnet` label, chain-picker, or real/fake toggle in the `one.ie` bundle
- [ ] Observability: wallet-create, Save conversion, sponsored-tx success, passkey enrollment alerts, agent heartbeat
- [ ] Playwright + WebAuthn virtual authenticator covers States 1 → 2 → 3 → 4 → 5 in CI
- [ ] Sponsor hot-key rotation runbook dry-run executed once on staging
- [ ] First-30-seconds storyboard: land → wallet live → first tx → Save prompt → Touch ID enrolled, walked end-to-end with no extra screens
- [ ] Every `/u/*` surface displays USD primary, SUI under disclosure; raw addresses only on tap; tx summaries rebuilt from bytes via `money.ts`
- [ ] All five recovery journeys exercised on a real device
- [ ] `Devices` screen lists every wrapping with a working revoke path
- [ ] Google OAuth (existing Better Auth) still works end-to-end through `wallet-link` plugin
- [ ] `errors.ts` covers every row in the error-copy table; no raw WebAuthn / RPC error reaches the user
- [ ] Perf budget held at p95: `/u` paint ≤ 400 ms warm, Touch ID prompt ≤ 200 ms, sponsored-tx ≤ 3 s, approve render ≤ 500 ms, route change ≤ 100 ms
- [ ] Accessibility: VoiceOver labels on every signing surface, `aria-live` on balance, Dynamic Type 200% passes in CI, `prefers-reduced-motion` honoured, full keyboard path
- [ ] `/u/fleet` shows transitive exposure across every ScopedWallet rooted in the user's address
- [ ] Agent-owned ScopedWallets display *"Cap set by <agent-name>"*; scope changes surface once in `/u/` without alarming the user
- [ ] Peer-agent `spawn_child` tested: parent agent spawns a child at machine speed under its own cap, no human Touch ID in the path
