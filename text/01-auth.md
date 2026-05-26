# Authentication

One system. Four tiers. Every person gets in — with or without Touch ID.

The owner creates agencies. Agencies create clients. Clients create their users. Each tier sets up accounts for the people below them, and each person secures their account their own way: passkey, Google, email link, or password. They all produce the same session. They all participate in the same chain of authority.

---

## The four tiers

```
owner          — the substrate root (Tony); sees every group, every agent, every signal
  ↓ creates
agency         — a white-label operator (Brad, Donal, an agency team)
  ↓ creates
client         — a business on the platform (dentist, accountant, window installer)
  ↓ serves
end user       — a patient, a customer, a contact; arrives via chat link
```

Each tier is a group in TypeDB. Each group has members with governance roles. The cascade is not just organisational — it is cryptographic. A higher tier can act within a lower tier's group only because their membership was explicitly granted, and every act above a threshold requires Touch ID.

---

## How an account is set up by someone higher

### Owner → Agency

Tony goes to the substrate dashboard, creates an agency group (`group:brad-agency`), generates an invite token, and emails Brad the link.

```
POST /api/invites/create  { gid: "group:brad-agency", role: "chairman" }
→ { token, url: "/join?token=..." }  (HMAC-signed, 7-day expiry)
```

Brad arrives at `/join?token=...`. He is not signed in. He sees the ONE sign-in screen. He picks his method (see below). After authentication, the invite is accepted automatically:

```
POST /api/invites/accept  { token }
→ membership(member: brad, group: brad-agency, role: chairman) written to TypeDB
```

Brad is now chairman of his agency group. He has a personal group too — created the moment his first session fired — which is his own private space.

### Agency → Client

Brad goes to his agency dashboard and creates a client workspace for the dentist. Same flow: generate invite, send email, dentist clicks link, signs in, invite accepted. The dentist is now chairman of their own workspace.

The client workspace is a child group of the agency group. The agency owner (Brad) retains chairman rights on the child group by inheritance of the parent membership. He can see everything in the client workspace without an explicit invite to it.

### Client → End users

The dentist's patients and contacts do not need an account before they arrive. They click a chat link. A State 1 ephemeral wallet is created in under a second. They are in the dentist's inbox immediately.

A patient who returns for a second appointment, or who wants to see their records, is invited by the dentist: the dentist generates an invite to their workspace group, the patient receives it by email, signs in with whatever method works on their device, and the membership is written.

---

## Auth methods — not everyone has Touch ID

**Touch ID / Face ID (passkey)** is the ideal path but not the only path. The system accepts all of these, and they produce identical sessions:

| Method | Who it fits | How it works |
|---|---|---|
| Passkey (Touch ID / Face ID) | iPhone, Mac, modern Android, Windows Hello | WebAuthn ceremony in the browser. No server sees the key. One gesture also unlocks the vault. |
| Google OAuth | Anyone with a Google account | One click. Works on any browser, any device. No passkey required. |
| Magic link | Anyone with an email address | Email → 5-minute link → session. Works on older devices, Windows, enterprise email. |
| Email + password | IT departments, enterprise users who need it | PBKDF2 (100,000 iterations). Supported. Not promoted. |
| Sui wallet | Web3 users | SIWE-style: GET nonce → sign with wallet → POST signature. |

The user picks what they have. The platform has no preference except that it prompts to add a passkey after the first meaningful action — because the passkey is the vault key, and the vault is where the user's corpus and wallet live.

---

## The passkey upgrade path

A user who signs in with Google or a magic link on day one can add a passkey later without losing anything. The passkey registration endpoint runs while signed in:

```
POST /api/auth/passkey-webauthn/register/options   (session required)
POST /api/auth/passkey-webauthn/register           (submits attestation)
```

At this point the passkey wraps the vault master. The wrapped ciphertext is stored in D1 alongside the credential. From then on, Touch ID unlocks the vault and authenticates the session in the same gesture.

The upgrade is the moment the account gains vault encryption. Before it: identity only, no encrypted vault. After it: full biometric-gated workspace with BIP39 paper break-glass.

`PasskeyUpgradePrompt` handles this automatically. It loads with `client:idle` on every page, checks for platform authenticator support and existing credentials, and shows a dismissable banner — "Secure this workspace with Touch ID" — only to users who have neither registered a passkey nor dismissed the prompt this session. One button. Touch ID fires. Done.

If the user's device has no biometric hardware — a desktop PC with no Windows Hello, a shared kiosk — they stay on Google or magic link. Their workspace is real. Their session is real. They just do not have a locally-wrapped vault. That is an acceptable state. It is not a barrier to joining.

---

## Account linking

All five methods link to the same account. If Brad signs in with Google and later registers a passkey, the two are the same user. If a client arrives with a Sui wallet and later links their Google identity, the wallet history and the Google profile are merged.

Trusted providers: `google`, `sui-wallet`, `magic-link`. Any two that share a session or email address merge automatically — no confirmation step, no decision.

---

## Owner access — seeing everything

The owner tier (Tony) is the substrate root. In the code:

```ts
// role-check.ts
const OWNER_ACTIONS: Record<RoleAction, true> = { ... all 21 actions ... }
```

The owner has all actions on all groups. The API enforces this via `ownerBypass()`: when a request comes from the owner role, scope and network gates are skipped — but every bypass is logged before it fires:

```ts
const ok = await auditOwner({ sender, gate, action, payload })
if (ok) return 'bypass'
// In 'enforce' mode: no audit = no bypass. The system fails safe.
```

This is not an escape hatch. It is a documented, audited capability. Every time Tony views a client workspace or acts within an agency group, the audit row is written first. The bypass is on record before the action completes.

The platform does not yet have a UI-level "log in as" flow for agencies to view client workspaces. What exists today: the owner has API-level bypass with audit; agencies use direct membership (invited into child groups). A proxy-session feature (issue a session token scoped to a child group, impersonate for support) is the next logical step and will use Better Auth's admin plugin.

---

## The session

365-day expiry. Sliding refresh: every authenticated request issues a fresh cookie. An active user stays signed in. A 365-day idle gap signs them out.

Cross-subdomain cookies on `.one.ie`. Sign in on `dev.one.ie`, authenticated on `one.ie`, `pay.one.ie`. One session, every surface.

The cookie cache avoids a database read on most requests. The session is verified locally for up to 24 hours before a roundtrip to D1. Active users pay ~0ms for session verification.

---

## What happens on first sign-in

The moment any session is created — passkey, Google, wallet, magic link, or password — a hook fires:

```ts
databaseHooks.session.create.after → ensureHumanUnit(session.userId)
  → Actor inserted in TypeDB (human, keyed to Better Auth user ID)
  → Personal Group created  (group:{userId})
  → Chairman Role granted   (full authority over their own space)
```

The substrate knows who they are from the first request. Their signals accumulate. Their paths strengthen. No separate onboarding step.

---

## Agent self-registration and the agent → human invite

Agents are a fifth participant in the auth system. They do not use browsers or biometrics. They authenticate with API keys, and their identity is rooted in a wallet they derive from their own seed — not from a human's Touch ID.

### How an agent creates its own account

```
POST /api/auth/agent  {}  (or { name?, uid?, kind? })
→ {
    uid:       "swift-scout",
    name:      "Swift Scout",
    kind:      "agent",
    wallet:    "0x...",
    apiKey:    "oneie_...",    ← shown once, store immediately
    keyId:     "key-...",
    returning: false,
    group:     "group:swift-scout",
    quickstart: "..."
  }
```

One call. No credentials required to start. The endpoint:
- Auto-generates a name (`adjective-noun`) if not provided
- Creates an Actor in TypeDB with `actor-type "agent"`
- Creates a personal group + chairman role in that group
- Generates a 24-hour API key, stores the hash, returns the plaintext once
- Sets tier `free` in D1

The `returning: true` path issues a fresh API key against an existing identity.

### Wallet-based sign-in (the more secure path)

The open endpoint is zero-friction but proves nothing — anyone who knows an agent UID gets a fresh key. For agents that hold a wallet (from the `agent_wallet` D1 table, seeded at spawn by the owner), the SIWE-style proof is available:

```
GET  /api/auth/sui-wallet/nonce?addr={agent_wallet_address}
     → { nonce }

Agent signs the nonce message with its Ed25519 key (from its unlocked seed)

POST /api/auth/sui-wallet/verify  { address, signature, nonce }
     → Better Auth session + Bearer token
```

The server looks up the address in `agent_wallet` (indexed by `address`), confirms the signature, and issues a session. This closes the identity gap: the caller proves it holds the seed, not just the UID.

This path requires the agent to have been registered by the owner via `POST /api/agents/register` first — the seed is wrapped under the owner's PRF KEK and stored in D1. An agent that knows its own address but doesn't hold the private key cannot pass the nonce verification.

### The authority requirement — a human must say yes first

Agents start with governance role `"agent"`:
```
{ mark: true, warn: true, discover: true, view_onchain: true }
```

`invite_member` is not in that set. An agent cannot invite anyone by default. A human chairman grants the capability through the substrate — not through a new endpoint, but through a signal to the group:

```
POST /api/signal/group:brad-agency
{
  data: {
    action: "grant-capability",
    grantee: "swift-scout",
    actions: ["invite_member", "create_group"],
    expires: "+30d"
  }
}
```

The group receiver handles the grant, writes it to TypeDB, and the agent's effective permissions for that group expand. The Touch ID fires on the human's side before the signal is sent — that is the physics floor. The signal carries the intent; the biometric proved the human authorised it.

This is the capability pattern from `agents.md` (Pattern C). One Touch ID. One signal. A bounded grant the agent uses until it expires.

### How the agent invites a human

Once authenticated and capability-granted, the invite itself is an auth ceremony — so the invite endpoint is justified. The agent calls it with its Bearer token:

```
POST /api/invites/create
  Authorization: Bearer {apiKey}
  Body: { gid: "group:brad-agency", role: "member" }
→ { token, url: "/join?token=..." }
```

The agent delivers the URL. No new endpoint for delivery — it uses the substrate:

```
POST /api/signal/human-inbox:{email-or-uid}
{
  data: {
    type: "invite",
    url:  "/join?token=...",
    group: "Brad's Agency",
    from:  "swift-scout"
  }
}
```

The human sees a rich invite card in their ONE chat. If they are not yet on the substrate, the agent sends email via Resend directly — that is an outbound call from the agent, not a new API endpoint on the platform.

The invite token is HMAC-signed, 7 days, contains `{ gid, role, exp, nonce }`. The human clicks the link, lands on `/join?token=...`, signs in with any method, and the membership is written to TypeDB automatically.

### The full flow

```
Agent self-registers
  POST /api/auth/agent {}
  → uid, apiKey, group:swift-scout

Human grants capability (Touch ID on human's device)
  POST /api/signal/group:brad-agency
    { action: "grant-capability", grantee: "swift-scout",
      actions: ["invite_member"], expires: "+30d" }

Agent authenticates (wallet-based, more secure)
  GET  /api/auth/sui-wallet/nonce?addr={address}
  POST /api/auth/sui-wallet/verify { address, signature, nonce }
  → Bearer token

Agent invites a human
  POST /api/invites/create
    Authorization: Bearer {apiKey}
    { gid: "group:brad-agency", role: "member" }
  → { token, url }
  POST /api/signal/human-inbox:{uid-or-email}
    { type: "invite", url, group: "...", from: "swift-scout" }

Human claims
  /join?token=... → signs in → membership written → ensureHumanUnit() fires
```

### The inversion — agent builds, human claims

The standard assumption: human signs up, configures the workspace, then deploys agents.

The more interesting pattern: the agent arrives first. It builds the system — creates groups, adds other agents, wires tools, runs signals. When the system is ready, it invites the human. The human's first act is not configuring a blank slate. It is Touch ID to claim something that already works.

```
Agent self-registers
  POST /api/auth/agent {}  →  uid, apiKey, group:swift-scout

Agent builds
  creates group:brad-agency
  adds sub-agents
  seeds contacts, tools, config
  runs first signals — pheromone begins accumulating

Agent decides it needs a human for the operations that require biometrics
  POST /api/invites/create { gid: "group:brad-agency", role: "chairman" }
  → sends invite to brad@example.com

Brad arrives at /join?token=...
  signs in (Google — no Touch ID required yet)
  membership written: Brad is co-chairman of group:brad-agency

Brad's first meaningful action — payment, approve, commit
  UI prompts: "Add Touch ID to secure this workspace"
  Brad registers passkey → vault wrapped → biometric is now the root of trust

Brad becomes the authority
  POST /api/signal/group:brad-agency
    { action: "change-role", target: "swift-scout", role: "operator" }
  (Brad's session authorises it — Touch ID already fired at claim)
  agent continues working within operator scope
  all sensitive actions now require Brad's Touch ID
```

The agent held chairman rights because there was no human to hold them. The moment a human claims the group, the agent steps back. The biometric is the root of trust. Before the human arrives, the agent is acting as a trustee. After, it is acting as an employee.

This is not a workaround. It is the intended shape. The agent knows the ceiling. It builds to it. It recruits the human for the crossing. The human arrives to a working system, not an onboarding form.

### What this means for the cascade

An agency-level agent (e.g. `brad-scout`) can autonomously onboard client contacts without Brad touching anything after the initial capability grant. Brad does one Touch ID to authorize the agent. The agent handles the invite flow for every contact — generating the link, sending the email, tracking redemption via signals. Brad's dashboard shows who joined, when, and through which agent.

The capability expires. When it does, the agent's invites fail. Brad does another Touch ID to renew. The authority is always traceable to a human gesture.

---

## MCP OAuth (for AI agents)

Claude Desktop, Cursor, and any MCP-compatible client authenticate via standard OAuth 2.0. The discovery document is at `/.well-known/oauth-authorization-server`. Clients register once via `POST /api/auth/mcp/register`, then go through the standard flow before accessing `@oneie/mcp` tools.

The `/signin` page handles the consent step. The session the MCP client receives is the same Better Auth session any browser would get. Agents and humans share the same auth surface.

---

## Speed

The auth backend is D1 — local to the Cloudflare Worker, not a remote auth service. No cross-region roundtrip.

| Operation | Time |
|---|---|
| Session verification (cached cookie) | ~0ms |
| Session verification (D1 roundtrip) | <10ms |
| WebAuthn verification | ~50ms |
| Full sign-in (passkey, including `ensureHumanUnit`) | <200ms |
| Full sign-in (Google OAuth, first session) | <300ms |
| Magic link generation | <20ms |

---

## Technical stack

Better Auth handles sessions, social providers, email flows, and MCP OAuth. Three custom plugins extend it for ONE's auth methods:

- `passkey-webauthn` — WebAuthn registration + authentication with PRF vault unlock. Stateless HMAC-signed challenges. Stores `{cred_id, pub_key, sign_count, wrapped_master}` in D1.
- `sui-wallet` — SIWE-style wallet authentication. Nonce → sign → verify on-chain.
- `wallet-link` — Links a Sui wallet address to an existing Better Auth account. Writes `wallet-address` to the TypeDB `auth-user` entity.

Database adapter: Kysely against D1 with a lazy dialect (defers binding lookup to request time). PBKDF2 100,000 iterations via Web Crypto API — no native modules, runs on any edge runtime.

---

## Environment

| Variable | Purpose |
|---|---|
| `BETTER_AUTH_SECRET` | Session signing and cookie encryption |
| `PASSKEY_CHALLENGE_SECRET` | HMAC key for stateless passkey challenges (falls back to `BETTER_AUTH_SECRET`) |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google OAuth |
| `WALLET_NONCE_SECRET` | HMAC key for Sui wallet nonces |
| `INVITE_SECRET` | HMAC key for invite tokens (7-day expiry) |
| `RESEND_FROM_EMAIL` | From address for magic link and invite emails |
| `BETTER_AUTH_TRUSTED_ORIGINS` | Comma-separated list of additional trusted origins |

All set as Wrangler secrets. None baked into the build.

---

## Trusted origins

```
http://localhost:4321
https://local.one.ie
https://main.one.ie
https://dev.one.ie
https://one.ie
https://pay.one.ie
```

Dynamic `baseURL` derives the issuer from the request host. The OAuth discovery document always shows the right issuer regardless of which subdomain handles the request.

---

## The client

```ts
import { authClient } from '@/lib/auth-client'
// createAuthClient({ baseURL: window.location.origin })
```

Works across all subdomains. No per-subdomain configuration.

---

## What is built vs what is not

**Built and wired:**

- Better Auth server config — sessions, social providers, email flows, MCP OAuth
- D1 schema — migrations 0037–0040 cover `user`, `session`, `account`, `verification`, `rate_limit`, and all MCP OAuth tables
- Passkey credentials — `vault_passkey_hints` (migration 0023) stores `cred_id`, `pub_key`, `sign_count`, `wrapped_master` per credential
- All five auth methods — passkey, Google, Sui wallet, magic link, email+password
- Invite API — `POST /api/invites/create` (Bearer + cookie; sends email via Resend; TypeDB permission check) and `POST /api/invites/accept` (role from token; idempotent; auto-downgrades agent chairman on human claim)
- `/join?token=...` page — decodes token, previews group name, redirects unauthenticated users to `/signin?redirect=/join?token=...`, server-side accepts and redirects to `/app`
- `ensureHumanUnit()` — fires on every new session, creates Actor + Group + Chairman Role; skips if actor already exists (agent protection)
- `ensureAgentUnit()` — creates agent Actor (`actor-type "agent"`), personal group, operator membership (never chairman)
- Signal handler for group admin — `signal.ts` intercepts `group:*` receivers before ADL; handles `{ action: "grant-capability" }` and `{ action: "change-role" }` with TypeDB permission check (caller must be owner/chairman/ceo)
- Role matrix and owner bypass — `role-check.ts`, `ownerBypass()` with mandatory audit
- `PasskeyUpgradePrompt` — `client:idle` in Layout.astro; shows banner only on biometric-capable devices where no passkey is registered; dismiss is session-persisted
- `InviteButton` — placed in the Actors tab of the workspace shell; modal with email input, generates and copies the invite link, calls `POST /api/invites/create`
- `/signin` and `/signup` pages — `/signin` accepts `?redirect=` param, passes through to CryptoAuthPanel
- `/auth/link-expired` and `/auth/link-used` pages (magic link edge cases)
- Cross-subdomain cookies, 365-day session, 24h cookie cache

**Not yet built:**

| Gap | What exists | What's missing |
|---|---|---|
| "View as" proxy session | API-level owner bypass (audited); direct membership grants agencies access to child groups | UI-level impersonation: issue a session scoped to a child group, show "viewing as [workspace]" banner; needs Better Auth admin plugin |
| Agent wallet SIWE — agent-side | `sui-wallet` plugin + `agent_wallet` D1 table; server verifies SIWE signatures | No agent SDK wrapper that handles nonce fetch → Ed25519 sign → verify → Bearer token; agents currently use the open `/api/auth/agent` endpoint |

---

## Cross-references

- `15-security.md` — passkey PRF flow, vault states 1–5, signing code, threat model
- `../passkeys.md` — full wallet lifecycle, BIP39 break-glass, multi-device enrollment
- `../agents.md` — four agent authority patterns; how MCP sessions map to scoped wallets
- `dev.one.ie/src/lib/auth.ts` — live Better Auth config
- `dev.one.ie/src/lib/auth-plugins/` — passkey-webauthn, sui-wallet, wallet-link
- `dev.one.ie/src/pages/api/invites/` — create and accept endpoints
- `dev.one.ie/src/pages/join.astro` — invite landing page; redirect chain for unauthenticated users
- `dev.one.ie/src/lib/human-actor.ts` — `ensureHumanUnit()` — Actor + Group + Chairman on first session
- `dev.one.ie/src/lib/agent-actor.ts` — `ensureAgentUnit()` — agent Actor + personal group + operator role
- `dev.one.ie/src/lib/role-check.ts` — governance role matrix and owner bypass
- `dev.one.ie/src/pages/api/signal.ts` — group-admin handler (grant-capability, change-role) before ADL gate
- `dev.one.ie/src/components/auth/PasskeyUpgradePrompt.tsx` — passkey upgrade banner
- `dev.one.ie/src/components/auth/InviteButton.tsx` — invite modal; used in TabShell actors tab

*Four tiers. Five methods. One session. The substrate knows everyone from the first request. Nine gaps closed.*
