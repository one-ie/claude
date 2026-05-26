# 01-auth — gap analysis

Source promise: `/Users/toc/Server/one-ie/one/text/01-auth.md`
Design contract: `/Users/toc/Server/passkeys.md`

---

## Promise (from text/01-auth.md)

- **Four-tier cascade** — owner → agency → client → end_user, each tier creates accounts for the next; each tier is a TypeDB group with governance roles; higher tiers act on lower tiers' groups by explicit membership grant.
- **Five auth methods** — passkey, Google OAuth, magic link, email+password (PBKDF2 100k), Sui wallet (SIWE-style). All produce identical Better Auth sessions.
- **Passkey upgrade path** — start with Google or magic link, add passkey later; passkey then wraps the vault master and stores `wrapped_master` in D1.
- **`PasskeyUpgradePrompt`** — `client:idle` banner on every page that shows on biometric-capable devices with no passkey.
- **Invite system** — `POST /api/invites/create` (Bearer + cookie, Resend email, TypeDB permission check) + `POST /api/invites/accept` (idempotent, role from token, auto-downgrades agent chairman on human claim). `/join?token=...` landing page that redirects unauthenticated users to `/signin?redirect=...`.
- **`/signin` and `/signup` pages** with `?redirect=` passthrough; `/auth/link-expired` and `/auth/link-used` edge-case pages.
- **`InviteButton`** in workspace Actors tab — modal with email input → calls `POST /api/invites/create`.
- **Account linking** — Google + passkey + Sui wallet + magic link share one user; trusted providers (`google`, `sui-wallet`, `magic-link`) auto-merge on shared session/email.
- **Owner bypass** — `OWNER_ACTIONS` table in `role-check.ts`; `ownerBypass()` with mandatory `auditOwner()` before every bypass; fail-safe in `enforce` mode.
- **Agent self-registration** — `POST /api/auth/agent {}` returns `{uid, name, kind, wallet, apiKey, keyId, returning, group, quickstart}`; creates Actor with `actor-type "agent"`, personal group, chairman role of own space, 24h API key.
- **Sui-wallet SIWE for agents** — `GET /api/auth/sui-wallet/nonce` → sign → `POST /api/auth/sui-wallet/verify` returns Better Auth session + Bearer.
- **`grant-capability` signal** — `POST /api/signal/group:*` with `{action: "grant-capability", grantee, actions, expires}` writes to TypeDB; intercepted before ADL.
- **MCP OAuth 2.0** — `/.well-known/oauth-authorization-server` discovery; `POST /api/auth/mcp/register`; `/signin` handles consent step.
- **`ensureHumanUnit()` hook** — `databaseHooks.session.create.after` creates TypeDB Actor + Personal Group + Chairman Role on every new session.
- **Cross-subdomain cookies on `.one.ie`**, 365-day session with sliding refresh, 24h cookie cache, <10ms D1 verify, <200ms full sign-in.
- **Three custom Better Auth plugins** — `passkey-webauthn` (with PRF + `wrapped_master`), `sui-wallet`, `wallet-link`. Kysely + D1 adapter.
- **Envelope vault sync** — `PUT /api/vault/sync`, `D1 vault_blob (user_id PK, blob, version, updated_at)`, AES-GCM keyed by HKDF of master secret; restored on sign-in via `CloudRestorePanel` + 24-word phrase.

---

## Code reality

### What exists and works end-to-end

- **Single-method passkey auth** — `web/src/components/auth/AuthButton.tsx:78-133` calls `/api/auth` (GET challenge, POST assertion). `web/src/pages/api/auth.ts:30-100` verifies with `@simplewebauthn/server`, looks up `owners.credential_id`, issues `session` cookie (KV-backed, 7-day TTL) + HMAC `one-session` cookie.
- **Passkey registration** — `web/src/components/auth/PasskeyCreate.tsx:23-97` and `web/src/pages/api/provision.ts:20-253`. Creates `owners` row (slug, pubkey, credential_id, recovery_hash, display_name, tos_hash, tos_signed_at). Generates BIP39 mnemonic (`@scure/bip39`, 12 words via 128-bit entropy), PBKDF2-hashes it salted by slug, stores only the hash. Returns plaintext words exactly once → `/recovery-codes` page via sessionStorage.
- **Invite create + redeem** — `web/src/pages/api/provision.ts:38-168` handles `?action=create-invite` (writes `invites` row, 7-day expiry, optional Resend email via `templates.invite`) and `?action=redeem-invite` (verifies new passkey registration, writes `owners` row with `parent_slug`, marks invite redeemed, applies parent's `client_default_plan`). Schema in `migrations/0011_invites.sql`.
- **Invite redeem UI** — `PasskeyCreate.tsx` `mode='redeem'` calls the redeem endpoint. Lands on `/u/{slug}/onboarding`.
- **Magic-link skeleton** — `web/src/pages/api/recover.ts:8-55`. POST issues HMAC-signed token, 15-min TTL, stored in KV. GET verifies token → returns `{slug, action: 'begin-passkey-registration'}`. **No email send, no `/recover` UI page.** This is device-enrolment scaffolding, not a sign-in method.
- **CLI auth** — `cli/src/auth.ts:11-44`. `oneie auth login --key <key>` writes `~/.config/oneie/key` at 0600; `oneie auth logout` unlinks. No browser flow, no OAuth, no passkey path.
- **API key Bearer auth** — `web/src/lib/agent-auth.ts:18-36` checks `Authorization: Bearer <key>` against `SERVER_SECRET` or `api_keys` table (`migrations/0022_api_keys.sql`).
- **PasskeyKeepThis upgrade banner** — `web/src/components/auth/PasskeyKeepThis.tsx`. Component exists but `handleSave` posts to `/api/provision` with **no body** (line 17) — server requires `challenge`, `token`, `registration`, `tosTimestamp`; the call will 400. Not wired anywhere in `Layout.astro` as `client:idle`.
- **Session resolution** — `AuthButton.tsx:22-30` fetches `/api/auth` on hydration when SSR didn't inject `slug`. Cookie name `session` resolves via middleware → KV.

### What exists but does not work end-to-end

- `PasskeyKeepThis` component — body-less POST to `/api/provision` will fail.
- `/api/recover` — no UI surface calls it; no email transport for the link.

### What does not exist

- No Better Auth dependency in `web/package.json` — checked: only `@simplewebauthn/{browser,server}` for WebAuthn, no `better-auth`, no Kysely. The entire auth stack the promise describes (Better Auth core, plugins, Kysely+D1 adapter, social providers, MCP OAuth, session hooks) is absent.
- No `/signin`, `/signup`, `/join`, `/auth/link-expired`, `/auth/link-used`, `/recover` pages.
- No `/api/auth/passkey-webauthn/*`, `/api/auth/sui-wallet/*`, `/api/auth/mcp/*`, `/api/auth/agent`, `/api/invites/*`, `/api/vault/sync` routes. (The single `/api/auth.ts` endpoint is custom passkey, not Better Auth.) `find ... -path '*/api/auth/*'` returns nothing. Invite endpoints live under `/api/provision?action=` instead.
- No Google OAuth. `GOOGLE_CLIENT_ID` is not referenced anywhere in `web/src`. No `BETTER_AUTH_SECRET`, `BETTER_AUTH_TRUSTED_ORIGINS`, `INVITE_SECRET`, `WALLET_NONCE_SECRET`, `PASSKEY_CHALLENGE_SECRET` env vars — only `SERVER_SECRET`.
- No magic-link sign-in (the `recover.ts` skeleton is for device enrolment and has no email path).
- No email+password.
- No Sui wallet auth (SIWE). `grep -ril 'sui-wallet|siwe' web/src` → no hits.
- No `ensureHumanUnit()` / `ensureAgentUnit()` — `grep -ril` returns no hits. TypeDB Actor / Group / Chairman Role is not created on session start.
- No four-tier role system in code. `owners` table stores `slug, pubkey, credential_id, plan, parent_slug, recovery_hash, display_name, tos_*` (composite from migrations 0001/0002/0005/0009/0010). No `role`, no `tier`, no `chairman`. The "tier" is implied by `plan` (`agency`/`enterprise` gate invite creation in `provision.ts:62-65`).
- No `role-check.ts`, no `OWNER_ACTIONS`, no `ownerBypass()`, no `auditOwner()`. `grep` returns no hits.
- No agent self-registration endpoint. `web/src/pages/api/agents/` has CRUD endpoints but no `POST /api/auth/agent {} → {uid, apiKey, ...}` flow.
- No `grant-capability` signal handler. No `/api/signal/group:*` interception.
- No MCP OAuth — no `/.well-known/oauth-authorization-server`, no `POST /api/auth/mcp/register`.
- No vault envelope sync (`/api/vault/sync`, `vault_blob` table, `CloudRestorePanel`). No migration for it.
- No `wrapped_master`, `vault_passkey_hints`, or any vault-related column in `owners` / `owners_keys`. Passkey is the auth credential; there is no encrypted-seed wrapping in D1.
- No 365-day session — KV TTL is 7 days (`SESSION_TTL = 60 * 60 * 24 * 7` in both `auth.ts:15` and `provision.ts:13`); HMAC fallback is 30 days. Not 365, no sliding refresh, no 24h cookie cache.
- No cross-subdomain cookie scope — `cookies.set` omits `domain`, so cookies are host-bound (e.g. `dev.one.ie` only).
- No account linking. `owners` is keyed by `(slug, credential_id)`. Two passkeys on different devices for the "same user" would mean two `owners_keys` rows; cross-method linking (Google + passkey) is structurally impossible because there is no Google.
- No "auto-register on no-account" flow as advertised — `AuthButton.tsx:114-117` catches `no-account` and calls `register()`, but `register()` then calls `/api/provision` which always allocates a **new** slug. So a passkey-authenticated user with no slug never resolves to an existing identity; they always become a new owner. The "linking" promise has no implementation surface.

---

## Gaps

1. **The auth stack named in the doc does not exist.** Better Auth + Kysely + D1 adapter + three custom plugins (`passkey-webauthn`, `sui-wallet`, `wallet-link`) — zero lines of any of it ship. What ships is a hand-rolled `@simplewebauthn` + HMAC-cookie system keyed off a `slug`. Calling that "Better Auth" in marketing is a category error.
2. **Five methods promised, one ships.** Only passkey works. Google, magic-link, email+password, Sui wallet — none implemented. The `recover.ts` "magic-link" skeleton has no email transport, no UI, no session issuance. CLI is API-key only — no `oneie auth login` browser flow.
3. **Four-tier cascade has no schema.** `owners` has `parent_slug` (single edge to parent agency) and `plan`. No tiers, no roles, no governance, no TypeDB groups, no chairman/operator/agent distinction. The cascade described as "cryptographic" is just a foreign key.
4. **No TypeDB substrate hook.** `ensureHumanUnit()` does not exist; new sessions do **not** create Actor + Group + Chairman Role in TypeDB. The premise "the substrate knows everyone from the first request" is unimplemented for auth-created users.
5. **No owner bypass, no audit.** `role-check.ts` doesn't exist. No `OWNER_ACTIONS` matrix. No `auditOwner()` log row before bypass. The "documented, audited capability" is undocumented and unaudited.
6. **No agent self-registration auth endpoint.** Agents authenticate via Bearer keys stored in `api_keys`, allocated through other paths. The `POST /api/auth/agent {} → {uid, apiKey, wallet, group}` self-onboarding endpoint does not exist; the "agent builds, human claims" inversion has no entry point.
7. **No MCP OAuth.** Discovery doc, register endpoint, consent UI — none of it. Claude Desktop / Cursor cannot OAuth into this substrate today; they'd need a static API key.
8. **No vault wrapping, no envelope sync.** `wrapped_master` column, `vault_blob` table, `CloudRestorePanel`, `PUT /api/vault/sync` — all missing. The "passkey wraps the vault master" mechanism described as the heart of the upgrade path is not implemented. The system stores a PBKDF2 *hash* of the BIP39 phrase (`provision.ts:213-220`) — useful only to verify recovery, not to decrypt anything.
9. **`PasskeyUpgradePrompt` does not load globally.** No `client:idle` mount in `Layout.astro`. `PasskeyKeepThis.tsx` exists but is unwired and its single POST is broken.
10. **Session config undersells what the marketing promises.** 7-day KV TTL (not 365), no sliding refresh, no `.one.ie` domain on cookies, no cross-subdomain. A user signing in on `dev.one.ie` is not signed in on `one.ie` or `pay.one.ie`.
11. **Invite endpoints live under the wrong path.** Marketing says `POST /api/invites/create` and `POST /api/invites/accept`. Code uses `POST /api/provision?action=create-invite` and `?action=redeem-invite`. External consumers reading the spec will 404.
12. **Account linking is structurally impossible.** `owners` has no user concept above credential — every passkey is a new account; every method (if it existed) would be a new account. The "trusted providers auto-merge" claim has no merge primitive.
13. **No `/join?token=...` page.** The redeem flow only works if a UI somewhere calls `PasskeyCreate mode='redeem'` with the token; there's no landing route. The invite URL written into `provision.ts:73` is `/u/{childSlug}?invite={token}` — pointing into a workspace route that doesn't appear to consume it.
14. **No `/signin` or `/signup` page.** All sign-in lives inside `AuthButton.tsx` in the sidebar. No `?redirect=` plumbing, no dedicated route to deep-link unauthenticated users into.
15. **No agent capability-grant signal.** No `grant-capability` action handler, no `change-role` action handler, no group-receiver interceptor.

---

## Recommended improvements

In order, smallest blast radius first:

1. **Rewrite or retire `text/01-auth.md`.** The current copy describes a different product. Two paths:
   - **Honest narrow:** rewrite to the truth — passkey-only, single workspace, BIP39 recovery, 7-day session, no Google/magic-link/wallet/MCP-OAuth yet. List the rest as roadmap.
   - **Stay aspirational, ship to match:** keep the doc, do the work below. Either way, ship the doc and the code in the same commit so the gap doesn't grow.
2. **Fix `PasskeyKeepThis.tsx`** — pass the full registration payload (challenge, token, registration, tosTimestamp) before posting, or delete the component if the upgrade flow isn't real yet.
3. **Add `/signin.astro` and `/join.astro`** that wrap `AuthButton`/`PasskeyCreate` and honor `?redirect=` and `?token=`. Change `provision.ts:73` invite URL to `/join?token={token}`.
4. **Rename invite endpoints** — move logic to `/api/invites/create.ts` and `/api/invites/accept.ts` (re-export from current `provision.ts` to avoid breakage). Aligns with the doc and with the project's `.claude/rules/api.md` resource-bound family.
5. **Extend `owners` schema** — add `role` (`owner` | `chairman` | `member`), keep `parent_slug`. Promote the owner of `one.ie` to `role='owner'`. Add `role-check.ts` with the action matrix and `ownerBypass()` with an `owner_audit` table-backed log. **Don't skip the audit row** — the marketing claim is load-bearing for trust.
6. **Wire `ensureHumanUnit()`** — hook the session-creation path in both `/api/auth.ts:84-86` and `/api/provision.ts:229-240` to write Actor + Group + Chairman Role to TypeDB (or D1 equivalent if TypeDB isn't reachable from web). Without this, the "substrate knows everyone" claim across the doc cluster is false.
7. **Add Google OAuth.** Smallest end-to-end second-method. Either pull in `better-auth` properly (matches the doc) or write a focused PKCE flow. Either way, introduce a `users` table that `owners.user_id` can FK to, so account linking has a primitive.
8. **Make session multi-subdomain** — set `domain: '.one.ie'` on prod cookies, bump TTL to the 365 days promised, implement sliding refresh on authenticated requests.
9. **Magic-link end-to-end** — give `recover.ts` a real outbound email via `lib/email.ts`, a `/recover.astro` consume page, and have it issue a session (not just return a slug).
10. **Agent self-registration** — `POST /api/auth/agent {}` returning `{uid, apiKey, wallet, group}`. Reuse `api_keys` table; allocate slug; create agent Actor; return once-shown plaintext key. This unlocks the "agent builds, human claims" pattern referenced across `agents.md` / `passkeys.md`.
11. **MCP OAuth** — publish `/.well-known/oauth-authorization-server`; `POST /api/auth/mcp/register`; minimal consent screen. Without this, Claude Desktop / Cursor users cannot reach `@oneie/mcp` tools through OAuth — only via static keys.
12. **Vault envelope sync** — only after a real upgrade-to-passkey flow with `wrapped_master` exists. Marketing leads with this; it's the highest-value differentiator and currently fictional.
13. **Sui wallet SIWE** — last because it's a niche second-method until x402/wallet flows are live; build when an agent or developer surface actually needs it.

---

## Files to touch

Spec:
- `/Users/toc/Server/one-ie/one/text/01-auth.md`

Code (existing — to extend or fix):
- `/Users/toc/Server/one-ie/one/web/src/pages/api/auth.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/provision.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/recover.ts`
- `/Users/toc/Server/one-ie/one/web/src/lib/passkey.ts`
- `/Users/toc/Server/one-ie/one/web/src/lib/agent-auth.ts`
- `/Users/toc/Server/one-ie/one/web/src/components/auth/AuthButton.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/auth/PasskeyCreate.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/auth/PasskeyKeepThis.tsx`
- `/Users/toc/Server/one-ie/one/web/src/layouts/Layout.astro` (wire `PasskeyUpgradePrompt` as `client:idle`)
- `/Users/toc/Server/one-ie/one/web/package.json` (add `better-auth` + Kysely if going that route)

Code (new):
- `/Users/toc/Server/one-ie/one/web/src/pages/signin.astro`
- `/Users/toc/Server/one-ie/one/web/src/pages/signup.astro`
- `/Users/toc/Server/one-ie/one/web/src/pages/join.astro`
- `/Users/toc/Server/one-ie/one/web/src/pages/recover.astro`
- `/Users/toc/Server/one-ie/one/web/src/pages/auth/link-expired.astro`
- `/Users/toc/Server/one-ie/one/web/src/pages/auth/link-used.astro`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/invites/create.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/invites/accept.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/auth/google/start.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/auth/google/callback.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/auth/agent.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/auth/mcp/register.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/.well-known/oauth-authorization-server.ts`
- `/Users/toc/Server/one-ie/one/web/src/pages/api/vault/sync.ts`
- `/Users/toc/Server/one-ie/one/web/src/lib/role-check.ts`
- `/Users/toc/Server/one-ie/one/web/src/lib/human-actor.ts`
- `/Users/toc/Server/one-ie/one/web/src/lib/agent-actor.ts`
- `/Users/toc/Server/one-ie/one/web/src/components/auth/PasskeyUpgradePrompt.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/auth/CloudRestorePanel.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/auth/InviteButton.tsx`
- `/Users/toc/Server/one-ie/one/web/migrations/0049_users.sql` (users table for linking)
- `/Users/toc/Server/one-ie/one/web/migrations/0050_owner_role_audit.sql` (`role`, `owner_audit`)
- `/Users/toc/Server/one-ie/one/web/migrations/0051_vault_blob.sql` (`wrapped_master`, `vault_blob`)
