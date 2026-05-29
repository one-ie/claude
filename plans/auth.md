# auth — the core

> One identity. Four tiers. Five methods. Every surface.
> Better Auth runs sessions. TypeDB runs reality. The bridge is `ensureHumanUnit`.

**Source promise:** `text/01-auth.md`
**Gap analysis:** `plans/improve/01-auth.md`
**Reference implementation:** `apps/dev.one.ie/` — strong reference, 2,743 lines of working code
**Substrate ontology:** `schema/one.tql` — `actor`, `group`, `membership`, `role-grant`, `identity-link`, `hierarchy`
**Target:** `one.ie/web/`

---

## 0. Classifier

| Prior | Answer |
|---|---|
| Spec locked | Yes — `text/01-auth.md` |
| Variance known | Yes — `apps/dev.one.ie/` proves the shape |
| Exit scalar | Yes — 14-row verify matrix in §14 |
| Files known | Yes — port map in §8 |

**Mode:** `mixed`. Each cycle is lean where mechanical (passkey port, route sweep), full where it crosses subsystems (cascade, whitelabel, MCP).

**Lifecycle:** `construction`. Pre-launch; existing `owners` records are dropped at cutover.

---

## 1. Why this is the core

Auth is the seam between **who** and **can**. Every other surface depends on it:

- **BaaS** — third-party developers reach the platform through API keys keyed on this system
- **Multitenancy** — every signal, path, hypothesis is scoped to a group resolved here
- **Whitelabel** — the agency's branding is loaded from the group resolved on the first request
- **Billing** — plan-tier gates fire on actions resolved here
- **Audit** — every privileged action writes a row resolved here
- **Federation** — `world`-as-actor signals cross trust boundaries resolved here
- **Agent economy** — humans grant scoped capabilities to agents through writes resolved here

Get this right once: tenancy, audit, branding, rate-limiting, capability grants — all of them become free. Every feature inherits them.

Get it wrong: every feature reimplements them, inconsistently, with bugs that compound.

This plan is one rewrite to delete the per-feature reimplementations forever.

---

## 2. The three questions auth must answer

| Question | Owned by | Storage |
|---|---|---|
| **Who are you?** | Better Auth | D1 (`user`, `session`, `account`, `verification`, `rate_limit`) |
| **What groups are you in?** | Substrate | TypeDB (`membership`, `hierarchy`) |
| **What can you do?** | Substrate | TypeDB (`role-grant` × `member-role`) |

Better Auth owns **authentication state** (credentials, sessions, account linking). It runs in D1 because OAuth needs <10ms verification-record reads.

The substrate owns **authorization state** (group hierarchy, role grants, capability scopes, audit). It runs in TypeDB because authority is a graph, not a row.

The bridge is one function: **`ensureHumanUnit(slug, user)`** writes the substrate actor + personal group + owner membership the first time a session is created. Idempotent. Same shape for agents via `ensureAgentUnit`.

---

## 3. The two layers

```
┌────────────────────── Better Auth (D1) ──────────────────────┐
│ user(id=UUID, slug, email, name, image, user_id_pub)         │
│ session(user_id, token, expires_at)                          │
│ account(user_id, provider_id, access_token)                  │
│ verification(identifier, value, expires_at)                  │
│ rate_limit(key, count, last_request)                         │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             │ ensureHumanUnit(slug, user)
                             │ (databaseHooks.session.create.after)
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                    Substrate (TypeDB)                        │
│                                                              │
│  actor(aid=slug, actor-type, auth-hash?, wallet?, …)         │
│   ├─ identity-link(subject, external, front-door)            │
│   └─ membership(group, member, member-role)                  │
│                                                              │
│  group(gid, group-type, plan, brand, visibility, …)          │
│   ├─ hierarchy(parent, child)                                │
│   └─ membership(group, member, member-role)                  │
│                                                              │
│  role-grant(governance-role, role-action)                    │
│  signal(sender, receiver, payload, scope, ts, …)             │
└──────────────────────────────────────────────────────────────┘
```

**Critical:** the substrate `actor` is keyed by `slug`, not by Better Auth's UUID. The UUID never leaves D1. Every external surface — URLs, SDK, CLI, MCP, TypeDB — speaks slug.

**OAuth provider IDs live in D1 only.** Better Auth's `account` table (`provider_id`, `account_id`, `user_id`) is the authoritative store for OAuth links. The substrate's `identity-link` relation stays defined-but-unused in v1; we mirror nothing. Substrate-side, the only external identifier `actor` carries is `wallet` (Sui address). Two stores, no overlap, no sync logic.

---

## 4. The unifying primitives

Four primitives. Every other concept in this system reduces to them.

### 4a. `slug` — the universal identifier

```
user.id      ┃ UUID, server-generated  ┃ D1 only           ┃ Never leaves the auth layer
user.slug    ┃ kebab-case, user-chosen ┃ D1 + everywhere   ┃ The only identifier the world sees
actor.aid    ┃ = user.slug             ┃ TypeDB             ┃ The substrate identity
group.gid    ┃ = "group:{slug}"        ┃ TypeDB             ┃ The personal group of a slug
```

All existing D1 tables stay slug-keyed (`threads.slug`, `messages.slug`, `workspace_settings.workspace_id`, etc.). No re-keying sweep. The migration only renames `owners.slug` → `user.slug` and drops the rest of `owners`.

**Agents follow the same pattern.** `user.slug = "swift-scout"` → `actor.aid = "swift-scout"`. One identifier, two kinds of actor.

### 4b. `Principal` — what flows through every request

```ts
interface Principal {
  user:    User            // Better Auth user (UUID, email, image)
  slug:    string          // = actor.aid; the universal identifier
  group:   Group           // active workspace (group.gid), with plan, brand, visibility
  role:    MemberRole      // owner | admin | member | viewer | agent | auditor
  actions: Set<RoleAction> // resolved from role-grant matrix at session start
  bypass:  boolean         // role === 'owner'; gates owner-only actions; requires auditOwner() first
}
```

**The six roles — same set at every level of the hierarchy. Locked 2026-05-20 in `schema/one.tql:165, 270` to match.**

| Role | Who | Within-group authority |
|---|---|---|
| `owner` | Accountable party — created or was granted the group. Multiple actors can hold this (co-founders, partners). | All 28 actions. `bypass = true` in Principal; every bypass is audited before the action commits. Inherits downward via `ancestors-of`. |
| `admin` | Trusted manager — runs operations on behalf of the owner(s). | Invite, configure, change roles up to `admin`. Cannot delete or transfer the group. |
| `member` | Full participant — does the work of the group. | All feature actions within the group's plan limits. |
| `viewer` | Read-only — served by or observes the group. | `chat_read`, `read_highways`. Cannot write, act, or see billing. |
| `agent` | AI actor. | 4 base actions (`mark`, `warn`, `discover`, `view_onchain`). Elevated for specific actions via capability grants. |
| `auditor` | Compliance reader. | Reads signals and audit log. Cannot act on anything else. |

The pre-2026-05-20 role set (`chairman / board / ceo / operator`) is retired. `schema/one.tql:189-193` `role-grant` entity now references this 6-role enum. T1 seed (`scripts/seed-roles.ts`) writes the matrix verbatim.

Built once per request by middleware. Passed by reference to every route, SDK call, and TypeDB write.

**The Principal is the unit of trust.** Auth is "construct a Principal"; authorization is "does this Principal hold this action?"; audit is "log every Principal × action pair where `bypass` was true".

### 4c. `requireAuth(action)` — the only auth helper routes call

```ts
// lib/api-auth.ts
export async function requireAuth(
  request: Request,
  action: RoleAction,
): Promise<Principal>
```

Internally it:

1. Resolves session from cookie OR `Authorization: Bearer …` (Better Auth handles both)
2. Hydrates `Principal.actor`, `Principal.group`, `Principal.role`, `Principal.actions` from TypeDB (KV-cached, 60s TTL keyed on `{slug}:{groupId}`)
3. Checks `action ∈ Principal.actions`
4. If `Principal.role === 'owner'`, runs `auditOwner({ slug, group, action })` before returning; failed audit = thrown 403
5. Enforces `quota-bucket` rate-limit (Better Auth's `rate_limit` table + `actor.quota-bucket`)

Every route becomes one line:

```ts
export const POST: APIRoute = async ({ request }) => {
  const principal = await requireAuth(request, 'chat:write')
  // … business logic, naturally scoped to principal.slug + principal.group.gid
}
```

The 30-route sweep is a grep-and-replace. Picking the right `RoleAction` per route is the only thinking.

#### Active group — the write path (C8)

`Principal.group.gid` is `session.user.activeGroupId ?? personalGroupOf(slug)`.
Reads scope by the URL; **writes** authorize by `activeGroupId`. If nothing
writes `activeGroupId` after login, "switch to Marketing" moves the URL but a
write still resolves your role in the login group — the read/write split.

`POST /api/groups/active { gid }` closes it: it is **membership-gated**
(`decideActiveSwitch` — staff may switch anywhere, your personal group is always
allowed, otherwise a membership/ancestor-authority row must exist; fails closed),
then writes `active_group_id` on the D1 `user` row. `GroupSwitcher.navigate()`
calls it before redirecting, so read-context (URL) and write-context
(`activeGroupId`) always agree. `capabilities` fold against `activeGroupId` too,
so this also fixes the act-as scope caveat (C7).

### 4d. Action namespace — frozen at 28 actions, snake_case

The vocabulary is finite, queryable, and audited. Each `RoleAction` is a snake_case `verb_resource` literal. **22 inherited verbatim** from `apps/dev.one.ie/src/lib/role-check.ts:1-22`; **6 added** for new surfaces this plan introduces.

**Substrate verbs (22):**
```
add_unit, remove_unit, mark, warn, tune_sensitivity, read_highways,
read_revenue, read_toxic, appoint_role, read_memory, delete_memory,
discover, create_group, update_group, delete_group, invite_member,
change_role, customize_vocabulary, edit_schema, mint_capability,
add_attribute, view_onchain
```

**New (6):**
```
chat_read, chat_write, vault_sync, mcp_register, verify_domain, grant_capability
```

The `role-grant` matrix in TypeDB enumerates which `governance-role` holds which `role-action`. Seeded on first deploy from `lib/role-check.ts`; mutable thereafter via substrate writes.

```tql
# What can a member do?
match $rg isa role-grant, has governance-role "member", has role-action $a;
select $a;
```

**Freeze gate:** the 28 actions lock at cycle 8. Adding a 29th requires a plan amendment and a new seed migration.

---

## 5. The four-tier cascade in TypeDB

```
owner          (Tony)              role: owner of group:one
  │ creates
  ▼
agency         (Brad's agency)     role: owner of agency group
  │ creates                         membership granted INTO agency group
  ▼
client         (Dentist)           role: owner of client group
  │ serves                          agency owner inherits via hierarchy(parent: agency, child: client)
  ▼
end_user       (Patient)           role: viewer (or no membership — visitor)
```

**The cascade is structural in TypeDB.** No new schema; everything below uses entities already in `one.tql`:

```tql
# Tony creates Brad's agency
insert $g isa group,
  has gid "group:brad-agency",
  has group-type "agency",
  has plan "agency",
  has brand "brad-agency",
  has visibility "private";

# Tony is owner of the substrate; his membership predates this
# Brad's user is created on signin; ensureHumanUnit gives him personal group
# An invite then writes:
match $g isa group, has gid "group:brad-agency";
      $brad isa actor, has aid "brad";
insert (group: $g, member: $brad) isa membership, has member-role "owner";

# Brad creates a client workspace
insert $c isa group,
  has gid "group:dentist-smile",
  has group-type "client",
  has plan "growth",
  has brand "dentist-smile",
  has visibility "private";
insert (parent: $brad-agency, child: $dentist-smile) isa hierarchy;
```

Now Brad's owner role on `brad-agency` propagates to `dentist-smile` via `ancestors-of` (the recursive function already defined in `one.tql:30-37`). `requireAuth` uses this to compute the effective role on any descendant group.

**The cascade is also the whitelabel.** `dentist-smile.com` resolves to `group:dentist-smile` (see §6). The dentist's clients sign in at the dentist's domain, see the dentist's branding, never see ONE. Brad's agency dashboard sees every dentist workspace because of hierarchy traversal.

### 5a. Agent membership — member by default, owner only as trustee

Agents follow a deliberately asymmetric pattern that may read as a contradiction in `text/01-auth.md`:

| Group | Agent's role | Why |
|---|---|---|
| Its own personal group (`group:{agent-slug}`) | **member** | `ensureAgentUnit` writes member; agents never own their own group |
| A group the agent creates *for an absent human* | **owner**, until claim | The "agent builds, human claims" inversion: agent acts as trustee |
| Same group, post-claim | **member** (auto-downgraded) | Human's `/api/invites/accept` writes owner membership; signal handler downgrades the agent in one transaction |

The biometric is the root of trust. Before the human arrives, the agent holds the keys to a workspace the human will own. The moment the human's Touch ID fires on `/join`, the substrate flips the roles atomically.

### 5b. Agent self-registration is open by design

`POST /api/auth/agent {}` returns `{uid, apiKey, wallet, group}` for any caller. Zero friction. The blast radius is bounded:

- New agent gets governance role `agent` (4 actions: `mark`, `warn`, `discover`, `view_onchain`)
- No `create_group`, no `invite_member`, no spend authority
- API key TTL = 24h; revocable
- `actor.valid-to` enforces hard expiry independent of D1

The **secure upgrade path** is SIWE: an agent that holds a wallet (seeded by the owner via `agent_wallet`) proves possession via `POST /api/auth/sui-wallet/verify`. SIWE is the second tier; open registration is the first. Both produce identical Better Auth sessions.

**Key rotation** — `POST /api/auth/agent/{uid}/rotate` (bearer-authenticated with the current key). Issues a new key with a fresh 24h TTL; the old key remains valid for a **5-minute grace window** so in-flight requests don't fail. A cron worker walks `actor.valid-to < now` every 60s and revokes expired keys. Wallet-bound agents (with a row in `agent_wallet`) can re-mint a key at any time via SIWE — the wallet is the durable identity, the key is the convenience.

### 5c. Email verification — required for trust transitions

| Event | Verification required? | Mechanism |
|---|---|---|
| Email + password signup | Yes | Better Auth `requireEmailVerification: true`; `user.email_verified = 0` until link click |
| Magic-link signup | Implicit | Click *is* the verification; `email_verified = 1` on first session |
| Passkey-first signup with no email | N/A | `user.email = NULL` until user explicitly adds an email method |
| Adding email to a passkey-first account | Yes | Same as fresh signup — verification link to the new address |
| Changing email on an existing account | Yes | **Override the reference's `updateEmailWithoutVerification: true`**. New address must be confirmed before the swap commits. Old address gets an alert. |
| Adding a passkey while signed in via Google | Inherits Google verification | No re-verify |

Without verification gates on email change, a compromised password rotates the recovery email and locks the real user out. The reference's permissive setting is wrong for v1.

### 5d. Account lifecycle — delete, export, retain

Two operations, both bearer-authenticated, both rate-limited.

**Data export** (`GET /api/auth/account/export`) — returns a signed `.zip` of:
- `user.json` (Better Auth profile)
- `accounts.json` (linked providers, minus secrets)
- `actor.json` (substrate identity)
- `memberships.json` (every group + role)
- `signals.ndjson` (every signal the actor sent or received, scoped to their own scopes)
- `vault.enc` (the encrypted envelope from `vault_blob`, opaque to us)

Available to any authenticated user at any time. Satisfies GDPR right of access.

**Account deletion** (`POST /api/auth/account/delete`) — two-phase:

```
T+0       Soft delete: user.deleted_at = now, every session revoked, every API key revoked,
          actor.valid-to = now, group memberships marked 'left', sign-in blocked.
          User receives one email: "Your account is scheduled for permanent deletion in 30 days.
          Click here to cancel."

T+30d     Hard purge: cron worker drops user/account/session/verification rows (FK cascades
          in D1); deletes actor + memberships in TypeDB; signals authored by the actor are
          retained (immutable audit) but the actor reference is anonymized to "deleted:{hash}".
          vault_blob is dropped — we never had the key anyway.
```

Soft-delete window satisfies "I changed my mind" without making the deletion non-binding. Hard purge satisfies GDPR right of erasure. The retained signals satisfy regulatory audit requirements (we can still prove who did what, just not who they were).

---

## 6. Whitelabel — domains, branding, cross-domain sessions

### 6a. Domain → group resolution

Three host shapes resolve to a group at middleware:

| Host | Group |
|---|---|
| `one.ie`, `app.one.ie`, `dev.one.ie`, `pay.one.ie` | platform default (`group:one`) |
| `{slug}.one.ie` | `group:{slug}` (subdomain workspaces) |
| custom domain (e.g. `dentist-smile.com`) | lookup in D1 `domains(host → gid)` |

Middleware writes `ctx.locals.host` and `ctx.locals.group` (resolved by host). All subsequent reads (branding, sign-in surface, theme) come from `ctx.locals.group.brand`.

D1 table (already in reference): `domains(host TEXT PRIMARY KEY, gid TEXT, verified_at INTEGER, ssl_status TEXT, dcv_records TEXT)`.

**TLS via Cloudflare for SaaS Custom Hostnames.** We never touch certs; CF owns the lifecycle:

```
1. POST /api/domains/verify { host, gid }
   → calls CF API POST /zones/{zone}/custom_hostnames
       { hostname, ssl: { method: "txt", type: "dv" } }
   → stores DCV TXT records in domains.dcv_records
   → surfaces records to agency UI

2. Agency adds TXT record to their DNS at host

3. Cron worker polls CF Custom Hostnames API every 60s for pending hosts
   → on cf.status === "active": domains.ssl_status = "active",
     domains.verified_at = now()

4. Incoming HTTPS requests on the host route to our Worker via CF SaaS;
   middleware does domains lookup → ctx.locals.group resolved
```

We own one D1 table, one verify endpoint, one polling worker. No ACME library, no cert storage, no SNI logic.

### 6b. Branding

`group.brand` (already in `one.tql:34`) is a string key into a branding bundle stored in KV:

```
KV: brand:{brand}:theme.json   { primary, secondary, font, logo_url, favicon_url, name }
KV: brand:{brand}:meta.json    { tagline, support_email, terms_url, privacy_url }
```

Components read from `ctx.locals.group.brand` and render the bundle. `SignInWithAnything` shows the agency's logo. Welcome emails carry the agency's signature. The platform recedes.

### 6c. Plan-tier — `group.plan` is the only source of truth

```
read path:   middleware → KV(plan:{gid}, 60s TTL) → TypeDB(group.plan)
write path:  Stripe webhook → TypeDB(group.plan) → KV.delete(plan:{gid})
```

No D1 mirror table. The KV cache is invalidation-driven, not TTL-driven for correctness — the 60s TTL only bounds the cost of a missed invalidation. Plan-gated features (`invite_member` requires `group.plan ∈ {agency, enterprise}`) read from `ctx.locals.group.plan`, which middleware hydrates once per request.

One fact, one home, one read, one invalidator.

### 6c. Sessions across domains

Two flavors:

- **Cross-subdomain** (`one.ie`, `*.one.ie`): handled by Better Auth's `advanced.crossSubDomainCookies = { domain: '.one.ie' }`. One sign-in covers all `.one.ie` surfaces.
- **Cross-domain** (whitelabel custom domains): Better Auth treats each domain as its own session realm. A user signing in at `dentist-smile.com` gets a session bound to that domain. They sign in separately at `one.ie` if they're also a platform user.

This is correct. The agency wants the dentist's customers to see the dentist's domain, not the platform. Cross-domain SSO would leak the relationship.

For platform users who switch domains (Brad logs into his agency dashboard at `agency.com` and his client's workspace at `dentist-smile.com`), Better Auth's bearer plugin lets him request a short-lived bearer at `agency.com/api/auth/token?audience=dentist-smile.com` and use it to open a session there. Out of scope for v1; flag as future work.

---

## 7. Capability grants and audit

Two kinds of authority in the system:

| Kind | Mechanism | Storage |
|---|---|---|
| **Role-based** | `role-grant(governance-role, role-action)` × `membership.member-role` | TypeDB |
| **Capability-based** | A signal of type `grant-capability` writes a scoped, time-bound, revocable action grant | TypeDB |

Roles are stable (an owner is an owner). Capabilities are dynamic (Brad grants the marketing agent `wallet:sign` on his agency group for 24 hours).

### Capability grant signal

```
POST /api/signal/group:{gid}
{
  type:      "grant-capability",
  grantee:   "agent:swift-scout",
  actions:   ["wallet:sign", "x402:pay"],
  scope:     "group:brad-agency",
  expires:   "2026-05-20T00:00:00Z"
}
```

Intercepted before ADL by `lib/role-check.ts`. Writes:

```tql
insert $cap isa capability,
  provider $brad,
  offered $agent-action,
  has price 0,
  has valid-from <now>,
  has valid-to <expires>;
```

`requireAuth` reads both the role-grant matrix and any active capabilities for the principal. Either grants access.

### Audit

Two surfaces:

- **`owner_audit` table in D1** — synchronous; every `ownerBypass()` writes a row *before* the bypassed action commits; `enforce` mode fails closed if the write fails
- **`signal` entities in TypeDB** — every meaningful auth event is a signal (`auth:signin`, `auth:link-account`, `capability:grant`, `role:promote`); the audit log is just `match $s isa signal, has payload contains "auth:";`

D1 is fast (audit can't block the action); TypeDB is queryable (forensic analysis later).

### Suspicious sign-in detection

Every `session.create.after` hook compares the new session against the user's prior sessions:

| Anomaly | Detection | Response |
|---|---|---|
| New device fingerprint | `user_agent` ≠ any prior session for this user | Emit `auth:new-device` signal; email user with sign-in details + revoke link |
| New IP `/16` block | `ip_address` first three octets ≠ any prior IP `/16` for this user | Emit `auth:new-network` signal; email |
| New country | Cloudflare `request.cf.country` ≠ any country in user's last 90 days | Emit `auth:new-country` signal; email |
| Velocity anomaly | Two sessions > 1000 mi apart within 10 min (uses `request.cf.latitude/longitude`) | Emit `auth:velocity-anomaly` signal; suspend the **newer** session pending click-to-confirm from email |

Geo data comes free from Cloudflare's `request.cf` properties — no IP-geolocation service to call, no per-request latency. The user history (last 90 days of `{ua_hash, ip_16, country, lat, lng}` tuples) lives in KV with a 90-day TTL, keyed on `user.id`. One read + one write per session create. Total added latency: ~3ms.

---

## 8. Port map — `dev.one.ie` → `one.ie/web/`

### 8a. Libraries (adapted port — only `auth.ts` is near-verbatim)

| From `apps/dev.one.ie/src/lib/` | To `one.ie/web/src/lib/` | Lines | Notes |
|---|---|---|---|
| `auth.ts` | `auth.ts` | 259 | Better Auth config: Kysely + D1 + plugins + `databaseHooks`. Adapted: `databaseHooks.session.create.after` routes through `session-hooks.ts` dispatcher. |
| `d1-kysely-dialect.ts` | `d1-kysely-dialect.ts` | — | Lazy D1 binding lookup; adapted to the project-local minimal D1 type in `env.d.ts` (cast through `unknown` for `.meta`). |
| `auth-client.ts` | `auth-client.ts` | — | Browser-side SDK (`signIn.passkey()`, `signIn.email()`, …) |
| `api-auth.ts` | `api-auth.ts` | 658 | **`requireAuth(action)` lives here** (T2) |
| `auth-rate-limit.ts` | `auth-rate-limit.ts` | — | KV-backed quota; reads `actor.quota-bucket` |
| `auth-redirect.ts` | `auth-redirect.ts` | — | `?redirect=` plumbing for sign-in pages |
| `human-actor.ts` | `human-actor.ts` | — | `ensureHumanUnit(env, slug, user)` — **adapted**: takes `SubstrateEnv` explicitly; drops `status / success-rate / activity-score / sample-count / created` attribute writes (not in our `one.tql`); writes only schema-supported attributes `aid / name / actor-type / generation / wallet`. Personal group `member-role: "owner"` per §4b. |
| `agent-actor.ts` | `agent-actor.ts` | — | `ensureAgentUnit` — same shape for agents (T13 fills) |
| `role-check.ts` | `role-check.ts` | — | `OWNER_ACTIONS`, `ownerBypass()`, `auditOwner()`. T1 ships stub (`ownerBypass` returns `'not-owner'`, `auditOwner` returns `false`) so T2's `requireAuth` import compiles; T12 fills the matrix + D1 audit writes. |
| `session-hooks.ts` | `session-hooks.ts` | — | **New** — single `onSessionCreate(session)` dispatcher; coordinates `ensureHumanUnit` + `detectSuspiciousSignIn`; both wrapped `.catch(() => {})` so sign-in never fails on a TypeDB hiccup. |

**Not ported:** `typedb-auth-adapter.ts` (404 lines). The reference moved auth tables to D1 specifically to escape gateway latency; we follow.

### 8b. Better Auth plugins (verbatim + one adaptation)

| Plugin | From | To | Lines | Notes |
|---|---|---|---|---|
| Passkey + WebAuthn (PRF + wrapped_master) | `auth-plugins/passkey-webauthn.ts` | same path | 1066 | Verbatim |
| Sui wallet (SIWE) | `auth-plugins/sui-wallet.ts` | same path | 215 | Verbatim |
| Wallet-link (post-signin linking) | `auth-plugins/wallet-link.ts` | same path | 141 | **Adapt** |

Stock plugins (`bearer`, `magicLink`, `mcp`) ship with the package; only configured in `auth.ts`.

**Wallet-link adaptation.** The reference writes `wallet-address` and `passkey-cred-ids` to a TypeDB `auth-user` entity that exists in its `world.tql` schema. Our `one.tql` has no `auth-user`. The port writes to `actor` instead:

```tql
# Reference (world.tql, dev.one.ie):
match $u isa auth-user, has auth-id "{userId}";
insert $u has wallet-address "{address}";

# Adapted (one.tql, one.ie/web):
match $u isa actor, has aid "{slug}";
insert $u has wallet "{address}";
```

The `passkey-cred-ids` JSON array (multi-device hints) is **dropped from the substrate write entirely** — that data lives in D1 `vault_passkey_hints` (from cycle 12's `vault_blob.sql` and the passkey plugin's own tables). The substrate carries `actor.wallet` and nothing else.

### 8c. API routes

| Path | Source | Purpose |
|---|---|---|
| `pages/api/auth/[...all].ts` | reference | Better Auth catch-all (mounts all stock + plugin routes) |
| `pages/api/auth/me.ts` | reference | Current Principal |
| `pages/api/auth/passkey/assert.ts` | reference | Sign-in assertion (registration is in `[...all]`) |
| `pages/api/auth/wallet/nonce.ts` | reference | SIWE nonce |
| `pages/api/auth/wallet/verify.ts` | reference | SIWE verify |
| `pages/api/auth/email/continue.ts` | reference | Magic-link continue |
| `pages/api/auth/sign-in/email.ts` | reference | Email + password |
| `pages/api/auth/agent.ts` | reference | Agent self-registration: `POST {} → {uid, apiKey, wallet, group}` |
| `pages/api/auth/agent/[uid].ts` | reference | Agent identity lookup |
| `pages/api/auth/agent/[uid]/rotate.ts` | new | Agent key rotation; 5-min grace on the old key |
| `pages/api/auth/api-keys.ts` | reference | Replaces current `/api/keys.ts` |
| `pages/api/auth/owner-pubkeys.ts` | reference | Owner pubkey rotation |
| `pages/api/auth/owner-key-versions.ts` | reference | Pubkey history |
| `pages/api/auth/forget-password.ts` | provided by `emailAndPassword` | Sends reset email; rate-limited |
| `pages/api/auth/reset-password.ts` | provided by `emailAndPassword` | Token + new password |
| `pages/api/auth/verify-email.ts` | provided by `emailAndPassword` | Click-target for verification link |
| `pages/api/auth/sessions.ts` | new | `GET` lists user's active sessions; `POST /revoke-all` revokes all except current |
| `pages/api/auth/sessions/[id].ts` | new | `DELETE` revokes a specific session by id |
| `pages/api/auth/account/export.ts` | new | Signed `.zip` data export (see §5d) |
| `pages/api/auth/account/delete.ts` | new | Two-phase delete: soft-delete now, hard-purge at +30d |
| `pages/api/auth/account/cancel-delete.ts` | new | Click-target in the deletion confirmation email |
| `pages/api/invites/create.ts` | new | Renamed from `/api/provision?action=create-invite` |
| `pages/api/invites/accept.ts` | new | Renamed from `/api/provision?action=redeem-invite` |
| `pages/api/vault/sync.ts` | reference | Envelope vault sync (PUT) |
| `pages/api/domains/verify.ts` | new | Whitelabel domain verification (DNS TXT challenge) |
| `pages/.well-known/webauthn.ts` | reference | RP discovery |
| `pages/.well-known/oauth-authorization-server.ts` | provided by `mcp()` plugin | MCP discovery — confirm at cycle 11 |

### 8d. Astro pages

| Path | Source | Notes |
|---|---|---|
| `pages/signin.astro` | new | Hosts `SignInWithAnything`; honors `?redirect=`; loads branding from `ctx.locals.group.brand` |
| `pages/signup.astro` | new | Same component, signup mode |
| `pages/join.astro` | new | Consumes `?token=`; redirects unauthenticated users to `/signin?redirect=…` |
| `pages/recover.astro` | new | Magic-link consume page |
| `pages/auth/link-expired.astro` | reference | |
| `pages/auth/link-used.astro` | reference | |
| `pages/agency.astro` (or extension to dashboard) | new | Invite UI for owners and admins on agency-tier groups |

### 8e. Components

| File | Source |
|---|---|
| `components/auth/SignInWithAnything.tsx` | reference — the unified sign-in surface |
| `components/auth/AuthSurface.tsx` | reference |
| `components/auth/PasskeyButton.tsx` | reference |
| `components/auth/GoogleButton.tsx` | reference |
| `components/auth/WalletSignIn.tsx` | reference |
| `components/auth/EmailContinueForm.tsx` | reference |
| `components/auth/EmailInboxPanel.tsx` | reference |
| `components/auth/SigninForm.tsx` | reference |
| `components/auth/PasskeyUpgradePrompt.tsx` | reference — mount `client:idle` in `Layout.astro` |
| `components/auth/CloudRestorePanel.tsx` | reference |
| `components/auth/CryptoAuthPanel.tsx` | reference |
| `components/auth/RecoveryPhraseDialog.tsx` | reference |
| `components/auth/InviteButton.tsx` | reference |

### 8f. Middleware

`one.ie/web/src/middleware.ts` (188 lines) is **rewritten**, not edited:

```ts
// New shape (concept):
export const onRequest = defineMiddleware(async (ctx, next) => {
  const session = await auth.api.getSession({ headers: ctx.request.headers })
  ctx.locals.session = session ?? null
  ctx.locals.slug = session?.user?.slug ?? null
  ctx.locals.host = resolveHost(ctx.request)              // returns the active workspace gid
  ctx.locals.group = await resolveGroup(ctx.locals.host)  // KV-cached
  ctx.locals.visitorHash = await visitorHash(ctx)         // unchanged
  return next()
})
```

Authorization is **not** middleware's job anymore. Routes call `requireAuth(action)` which builds the full `Principal`. Middleware only resolves identity + host.

### 8g. Files deleted at cutover

| File | Replaced by |
|---|---|
| `pages/api/auth.ts` | `pages/api/auth/[...all].ts` |
| `pages/api/provision.ts` | `pages/api/invites/create.ts` + Better Auth registration |
| `pages/api/recover.ts` | Better Auth magic-link |
| `pages/api/keys.ts` | `pages/api/auth/api-keys.ts` |
| `lib/passkey.ts` | `auth-plugins/passkey-webauthn.ts` |
| `lib/agent-auth.ts` | `lib/api-auth.ts` (`requireAuth`) |
| `lib/api-keys.ts` | Folded into Better Auth account + agent flows |
| `components/auth/AuthButton.tsx` | `SignInWithAnything` |
| `components/auth/PasskeyCreate.tsx` | `PasskeyButton` |
| `components/auth/PasskeyKeepThis.tsx` | `PasskeyUpgradePrompt` |

---

## 9. D1 migrations

Current `one.ie/web/migrations/` ends at `0048`. Append:

| # | File | Source |
|---|---|---|
| 0049 | `better_auth.sql` | `dev.one.ie/migrations/0037_better_auth.sql` — **with `email` made nullable**; `user_id_pub` column + index land here (no separate 0051) |
| 0050 | `user_slug.sql` | new — adds `user.slug TEXT UNIQUE`, `user.active_group_id TEXT`, `user.locked_until INTEGER`, `user.deleted_at INTEGER` |
| ~~0051~~ | ~~`user_id_pub.sql`~~ | **Dropped 2026-05-20.** Reference 0036 targets `vault_blob` and `vault_passkey_hints`, neither of which exists in T1. The `user.user_id_pub` column moved to 0049; `vault_blob.user_id_pub` is created inline in 0058; `vault_passkey_hints` is deferred to T14. |
| 0052 | `user_plugin_columns.sql` | `dev.one.ie/migrations/0039_user_plugin_columns.sql` |
| 0053 | `better_auth_mcp.sql` | `dev.one.ie/migrations/0040_better_auth_mcp.sql` |
| 0054 | `agent_wallet.sql` | `dev.one.ie/migrations/0031_agent_wallet.sql` |
| 0055 | `owner_audit.sql` | derived from `dev.one.ie/migrations/0035_owner_daemon_audit.sql`; schema reshaped for `(slug, group_id, action, outcome)` — the 28-action vocabulary + `enforce-blocked` outcome |
| 0056 | `owner_key.sql` | `dev.one.ie/migrations/0028_owner_key.sql` |
| 0057 | `invites_v2.sql` | new — fresh `invites` table; `DROP TABLE IF EXISTS invites` precedes create |
| 0058 | `vault_blob.sql` | new — `vault_blob(user_id PK, blob, version, user_id_pub, updated_at)`; user_id_pub indexed for restore-by-derived-key |
| 0059 | `domains.sql` | new (was ported from `dev.one.ie/0018`; **shape replaced**) — `domains(host PK, gid, verified_at, ssl_status, dcv_records)`. `DROP TABLE IF EXISTS domains` precedes create (no prod rows). |
| 0060 | `drop_legacy_auth.sql` | new, cutover — drops `owners`, `owners_keys`, `api_keys`. **Created at T1, executed at T18.** |

**Migration deviation:** `user.email` is `NULL`able from `0049`. Passkey-first and wallet-first signups create `user` rows with `email = NULL`, populated when the user adds an email-bearing method. Email+password and magic-link routes validate email presence at the route, not the schema.

---

## 10. TypeDB seed (no `.tql` changes)

`schema/one.tql` already has every entity and attribute needed. No schema edits. **Seed data** is written once on first deploy:

```tql
# Owner pubkey actor (Tony) — created from BIP39 paper derivation
insert $owner isa actor,
  has aid "tony",
  has name "Tony",
  has actor-type "human",
  has wallet "0x…";

# Platform group (group:one)
insert $g isa group,
  has gid "group:one",
  has group-type "world",
  has plan "enterprise",
  has brand "one",
  has visibility "public";
insert (group: $g, member: $owner) isa membership, has member-role "owner";

# role-grant matrix (seeded from role-check.ts)
# Example rows:
insert $rg isa role-grant, has rg-id "owner:*",        has governance-role "owner",   has role-action "*";
insert $rg isa role-grant, has rg-id "admin:invite",   has governance-role "admin",   has role-action "invite_member";
insert $rg isa role-grant, has rg-id "member:chat",    has governance-role "member",  has role-action "chat_write";
insert $rg isa role-grant, has rg-id "viewer:read",    has governance-role "viewer",  has role-action "chat_read";
# … one row per (role, action) pair from OWNER_ACTIONS
```

Seed runs from `scripts/seed-roles.ts`. Idempotent; matches on `rg-id` before insert.

---

## 11. Environment variables

Add to `one.ie/web` Worker secrets:

```
BETTER_AUTH_SECRET            32-byte hex; signs sessions
BETTER_AUTH_TRUSTED_ORIGINS   CSV of allowed origins
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
PASSKEY_CHALLENGE_SECRET      Optional; falls back to BETTER_AUTH_SECRET
WALLET_NONCE_SECRET           SIWE nonce HMAC key
SUI_SESSION_SECRET            Optional; for wallet-issued sessions
INVITE_SECRET                 HMAC for invite tokens
RESEND_FROM_EMAIL             Already present
USE_BETTER_AUTH               Feature flag, removed at cycle 15
```

`SERVER_SECRET` (current) is retired at cycle 16. Worker bindings already include `DB` (D1), `SESSION` (KV), `KV`; no new bindings needed.

### 11a. Vault KDF parameters (locked)

The vault and its envelope sync are deterministic. Three info strings, one hash, one cipher, one PRF salt. All versioned (`-v1`) so a future scheme can ship alongside without breaking ciphertext.

| Parameter | Value | Used at |
|---|---|---|
| PRF input salt (`eval.first` bytes) | `"one.ie-wallet-v1"` (ASCII) | WebAuthn assertion in passkey unlock |
| HKDF hash | SHA-256 | All derivations |
| HKDF info — per-device wrap | `"wallet-wrap-v1"` | AES key wrapping the master seed in a `passkey-prf` entry |
| HKDF info — cloud envelope | `"vault.sync.export.v1"` | AES key for the `PUT /api/vault/sync` blob |
| AEAD | AES-256-GCM | Encrypt/decrypt seed and envelope |
| IV | 12 bytes, `crypto.getRandomValues` per encryption | Per-ciphertext, prepended to blob |

Source: `plans/world/passkeys.md:72-74, 125-132`. Locked at cycle 12. v2 adds new info strings, never mutates v1.

### 11b. Rate-limit thresholds (configured at cycle 1)

Better Auth's `rate_limit` table (D1, migration 0049) is the substrate. Thresholds are configured in `auth.ts` and per-route via the rate-limit plugin. Where two rules apply, the stricter wins. **Lockout** is per-account; **throttle** is per-IP.

| Surface | Limit | Window | Lockout |
|---|---|---|---|
| Sign-in attempts (per IP) | 10 | 5 min | No — throttle only |
| Sign-in attempts (per account) | 5 | 15 min | **Yes** — account locked for 15 min after 5th failure; auto-unlock by magic-link or password-reset success |
| Email + password signup (per IP) | 3 | 1 hr | No |
| Magic-link request (per email) | 5 | 1 hr | No |
| Password reset request (per email) | 3 | 1 hr | No |
| Email verification resend (per user) | 5 | 1 hr | No |
| Agent self-registration (per IP) | 10 | 1 hr | No |
| MCP DCR registration (per IP) | 20 | 1 hr | No |
| Invite create (per group) | 50 | 1 hr | No |
| Vault sync write (per user) | 60 | 1 hr | No |
| Account deletion request (per user) | 1 | 24 hr | No |
| Data export request (per user) | 3 | 24 hr | No |
| Authenticated API requests (per `actor.quota-bucket`) | free=1k, growth=50k, agency=500k, enterprise=∞ | 1 hr | Soft cap → 429 with `Retry-After`; enterprise overage billed, not throttled |

Per-account lockout writes `user.locked_until` (added in `0050_user_slug.sql` alongside `user.slug`). Sign-in checks `locked_until > now` *before* checking credentials, so failed attempts during lockout don't reset the counter. Magic-link sign-in and successful password-reset both clear `locked_until` to zero.

Numbers chosen to keep humans unbothered (5 failed sign-ins is "I forgot my password", not a brute force) while making credential stuffing prohibitively slow (50,000 accounts × 5 attempts = 250,000 per hour, which dies at the per-IP cap).

---

## 12. Cycles

20 cycles in two phases. Cycles 1–16 ship behind the `USE_BETTER_AUTH` flag; each lands on a branch deploy, smoke-tests, then merges. Cycles 17–20 are post-cutover enterprise hardening (see §20); no feature flag needed.

| # | Cycle | Mode | Exit gate (what `verify` checks) |
|---|---|---|---|
| 1 | **Foundation** | full | Migrations 0049–0055 land. `lib/auth.ts` wired. New middleware in place. `GET /api/auth/get-session` returns null cleanly. Flag = `false` everywhere. **Rate-limit thresholds from §11b configured in `auth.ts`.** |
| 2 | **`requireAuth` + `Principal`** | full | `lib/api-auth.ts` ports cleanly. 4 pilot routes (`me.ts`, `billing.ts:webhook`, `agents/[id].ts`, `chat.ts`) migrated. Integration test proves Principal hydration. |
| 3 | **Passkey (method 1)** | full | `/signin` + `/signup` render. Register passkey → session → `ensureHumanUnit` creates `actor` with `aid = slug` + personal group + owner membership. |
| 4 | **Google OAuth (method 2)** | lean | Google flow completes; account linking creates a second `account` row on the same `user`. Same `slug`, same actor. |
| 5 | **Magic link + email+password (methods 3 + 4) + verification + reset + lockout** | full | Both methods produce identical sessions. Email verification required for email+password signup; verification link round-trips. `POST /api/auth/forget-password` → reset email → `POST /api/auth/reset-password` rotates credential. 6th failed sign-in triggers 15-min lockout; magic-link unlocks. |
| 6 | **Sui wallet SIWE (method 5)** | lean | `wallet-link` plugin (adapted to write `actor.wallet`, not `auth-user`) lets an existing user add a wallet; cold SIWE sign-in creates user + actor with `wallet` attribute. |
| 7 | **Cascade + invites + whitelabel domains** | full | `/api/invites/create` + `/api/invites/accept` + `/join` page. `hierarchy(parent, child)` written for sub-workspaces. CF Custom Hostnames flow verifies `dentist-smile.com`; branding renders. |
| 8 | **Authority: role-grant matrix + `ownerBypass` + suspicious sign-in** | full | Seed script writes role-grant matrix to TypeDB. `requireAuth` enforces matrix. Owner sees a client workspace; `owner_audit` row exists in D1 *before* the read commits. Sign-in from new country emits `auth:new-country` signal + sends email. |
| 9 | **Agents: self-registration + SIWE + key rotation** | full | `POST /api/auth/agent {}` returns `{uid, apiKey, wallet, group}`. Agent SIWE returns Better Auth session. `POST /api/auth/agent/{uid}/rotate` issues new key; old key valid for 5-min grace; cron revokes expired keys. |
| 10 | **Capability grants** | full | `POST /api/signal/group:*` with `type: "grant-capability"` writes a `capability` relation with `valid-from`/`valid-to`. `requireAuth` honors it. Expiry tested. |
| 11 | **MCP OAuth** | full | `/.well-known/oauth-authorization-server` serves discovery. `POST /api/auth/mcp/register` returns client credentials. Claude Desktop completes the OAuth dance, calls `@oneie/mcp` with bearer. |
| 12 | **Vault + `PasskeyUpgradePrompt`** | full | `vault_blob` table + `PUT /api/vault/sync` round-trips. `CloudRestorePanel` restores on a new device using 24-word phrase. `PasskeyUpgradePrompt` mounted `client:idle` in `Layout.astro`; Google-only user sees prompt; one Touch ID press wraps master. |
| 13 | **Account lifecycle: sessions + delete + export** | full | `GET /api/auth/sessions` lists active sessions; `DELETE` revokes one; `POST /revoke-all` revokes all-but-current. `POST /api/auth/account/delete` writes `user.deleted_at`, revokes sessions, schedules hard-purge cron at +30d. `GET /api/auth/account/export` returns signed `.zip` round-tripping `user.json` + `actor.json` + `signals.ndjson`. |
| 14 | **Route sweep** | lean | Remaining ~25 routes migrated to `requireAuth(action)`. Pick the right action string per route. `grep -r "readSession\|checkOwnerAuth\|checkApiKey"` returns 0 hits. |
| 15 | **SDK + CLI** | lean | `@oneie/sdk` ports `auth-client.ts`; SDK exposes `client.signIn.*` and persists token. `oneie auth login` uses device-flow OAuth via MCP plugin; opens browser, polls, writes `~/.config/oneie/key`. |
| 16 | **Cutover** | full | `USE_BETTER_AUTH=true` permanently. `0060_drop_legacy_auth.sql` runs. Legacy files deleted (§8g). `grep` for legacy symbols returns 0 hits. Full verify matrix (§14) green. |
| 17 | **Auth policy + domain auto-join** | lean | `PUT /api/groups/{gid}/policy` persists policy to KV. `requireAuth` enforces `allowed_methods` against session provider and `ip_allowlist` against `CF-Connecting-IP`. `domains.auto_join_role`: sign-in with matching email domain auto-inserts membership in `ensureHumanUnit`. |
| 18 | **Automated offboarding** | lean | `POST /api/auth/members/{slug}/offboard` cascades membership deletion across caller's group + all descendants in one TypeDB transaction. Sessions and API keys revoked synchronously. |
| 19 | **SCIM 2.0** | full | `/scim/v2/Users` and `/scim/v2/Groups` endpoints. Okta provisions user → `ensureHumanUnit` + membership; deletes user → offboarding cascade. SCIM bearer token per group, hashed in `scim_tokens` D1 table. Verify: Okta test tenant create + delete round-trip. |
| 20 | **OIDC SSO** | full | Per-group IdP config in D1 `sso_config`. `GET /api/auth/sso/initiate?email=` routes by domain to configured IdP. Better Auth `oidc` plugin handles token exchange. Callback → `ensureHumanUnit`. Policy from cycle 17 can restrict group to `allowed_methods: ['sso']`. Verify: Okta OIDC → callback → actor in TypeDB. |

---

## 13. Threat model

| Surface | Defends against | Accepts |
|---|---|---|
| Passkey (WebAuthn) | Phishing, password reuse, server-side credential theft | Device loss → BIP39 paper break-glass (`mac.md`) |
| Google OAuth | Lost password flows, weak passwords | Google account compromise → linked passkey mitigates |
| Magic link | Forgotten passwords, low-friction sign-in | Email account compromise; 5-min link TTL bounds replay window |
| Email + password (PBKDF2 100k) | Brute force at rest | Server-side credential exposure → hash-only storage |
| Sui wallet (SIWE) | Replay (nonce), spoofed addresses | Seed compromise; nonce HMAC keyed by `WALLET_NONCE_SECRET` |
| Agent API key | Network sniff (TLS), persisted secrets (hash-only) | Key leak by member or admin; 24h TTL + revocation table + `actor.valid-to` |
| Session cookie | XSS (`httpOnly`), CSRF (`sameSite=lax`), eavesdrop (`secure`) | Browser malware with FS access |
| Owner bypass | Silent privilege escalation | Owner key compromise → `auditOwner()` writes row *before* bypass; `enforce` mode fails closed; canary tx (`mac.md`) detects unauthorized owner action |
| MCP OAuth | Unauthorized tool access (consent screen) | Phished consent → PKCE + short-lived access tokens |
| Invite token | Replay (idempotent accept), forgery (HMAC-signed) | Email forwarding within 7-day TTL |
| Capability grant | Permanent over-grant (`valid-to` enforces expiry) | Compromised grantor → audit row from `auditOwner()` if grantor is owner |
| Whitelabel domain | Spoofed domain mapping | DNS TXT challenge required before `domains.verified_at` is set |
| Cross-domain leakage | Session bleed | Better Auth treats each domain as its own realm; whitelabel sessions are domain-bound |

---

## 14. Verify — the exit scalar

A single test pass after cycle 16 lands. Each row is one assertion in `__tests__/integration/auth.full.test.ts`.

```
01  POST /api/auth/sign-up/email                → session, user in D1, actor.aid = slug in TypeDB
02  POST /api/auth/sign-in/email                → session
03  GET  /api/auth/google → callback             → session + account row + linked to existing user
04  POST /api/auth/sign-in/magic-link            → email sent; click link → session
05  POST /api/auth/passkey-webauthn/register     → credential; assert → session
06  POST /api/auth/wallet/nonce → verify         → session
07  POST /api/auth/agent {}                      → {uid, apiKey, wallet, group}; bearer works on /api/agents/*
08  POST /api/invites/create                     → token; /api/invites/accept → membership in TypeDB
09  GET  /.well-known/oauth-authorization-server → MCP discovery doc
10  POST /api/auth/mcp/register                  → client_id + client_secret
11  PUT  /api/vault/sync                         → blob stored; GET round-trips
12  Cross-subdomain: sign in on one.ie           → authenticated on pay.one.ie
13  Whitelabel: sign in on dentist-smile.com     → authenticated only on dentist-smile.com; not on one.ie
14  ensureHumanUnit idempotent                   → 10× session creates → exactly 1 actor + 1 group + 1 membership
15  ownerBypass                                  → action by owner → owner_audit row exists in D1 before action commits
16  Capability grant                             → grant action with valid-to=now+1h; honored for 1h; expires cleanly
17  Email verification round-trip                → signup blocks sign-in until link click; email change requires confirm
18  Password reset round-trip                    → forget-password → email → reset-password → new credential signs in
19  Account lockout                              → 6 failed sign-ins → 15-min lock; magic-link clears lock
20  Sessions list + revoke                       → 3 sign-ins from different UAs → list shows 3; revoke 1 invalidates that session only
21  Suspicious sign-in                            → sign in from second country → auth:new-country signal + email sent
22  Agent key rotation                           → rotate; old key valid for 5 min; cron expires old key after grace
23  Rate limit                                   → 11th sign-in attempt from same IP in 5 min returns 429 with Retry-After
24  Account delete soft phase                    → /account/delete → sessions revoked; sign-in blocked; cancel email arrives
25  Account delete hard purge                    → simulate +30d cron run → user/actor rows gone; signals anonymized
26  Data export                                  → /account/export → signed zip; user.json, actor.json, signals.ndjson present
27  grep -r 'agent-auth|passkey.ts|provision.ts|api-keys.ts' src/  → 0 hits
28  grep -r 'readSession|checkOwnerAuth|checkApiKey' src/pages/api → 0 hits
```

All 28 green = the plan ships.

---

## 15. Doc edits in scope (per `.claude/rules/documentation.md`)

| Doc | Edit |
|---|---|
| `plans/auth.md` | this document |
| `plans/auth-todo.md` | created from this plan; drives `/do` |
| `plans/dictionary.md` | add canonical terms: `requireAuth`, `Principal`, `ensureHumanUnit`, `role-grant`, `slug`, `MemberRole`, `RoleAction` |
| `plans/website.md` | add `/signin`, `/signup`, `/join`, `/recover` to the 5-route surface; flag any conflicts |
| `one-ie/CLAUDE.md` | add §Auth: two-layer model — D1 owns Better Auth tables, TypeDB owns substrate, bridged by `ensureHumanUnit`. Link to this plan. |
| `one.ie/CLAUDE.md` | replace current auth section with the new endpoint surface + `requireAuth(action)` pattern |
| `CLAUDE.md` (root workspace) | one-line entry in the plan cluster table pointing to `plans/auth.md` |
| `text/01-auth.md` | **no edit** — this plan ships *to match* it; if anything diverges in build, change this plan, not the promise |
| `agents.md` | cross-reference: capability grants are written via the auth signal handler in this plan |
| `mac.md` | cross-reference: owner key rotation lives in `/api/auth/owner-pubkeys` |
| `passkeys.md` | cross-reference: PRF + wrapped_master + vault sync surface in cycle 12 |

---

## 16. Gateway scope

`api.one.ie` (the TypeDB proxy Worker in `api/`) is **not modified** in this plan.

- `GATEWAY_API_KEY` remains a server-to-server secret used by `one.ie/web` to talk to the gateway
- BaaS callers reach the platform through `one.ie/api/*` (Better Auth bearer), not the gateway
- If raw TypeQL access is later offered to BaaS tenants, it ships as `one.ie/api/data` with `requireAuth('data:query')`, **not** by exposing the gateway

This keeps the blast radius of the rewrite contained to `one.ie/web/` and one set of D1 migrations.

---

## 17. Rollback

Feature flag `USE_BETTER_AUTH` from cycle 1 to cycle 15. Both auth systems coexist; new routes prefer Better Auth, old routes still serve `readSession()` users.

**Per-cycle:** each cycle lands on a branch deploy, smokes against the verify row(s) it covers, merges only on green.

**Cycle 16 is non-reversible.** It drops `owners`, deletes legacy files, and removes the flag. By then the prior 15 cycles have proven the new path in full. The safety net is the branch-deploy gate, not the ability to roll forward and back through cycle 16.

If catastrophic failure surfaces post-cutover: restore from the D1 snapshot taken immediately before `0060` runs (Cloudflare D1 supports point-in-time restore). Users are cleared at cutover, so identity loss is bounded.

---

## 18. Out of scope for v1

Enterprise hardening (auth policy, domain auto-join, automated offboarding, SCIM 2.0, OIDC SSO) is in scope but post-cutover; see §20 for cycles 17–20.

- **Better Auth admin plugin** — proxy-session for agencies to "log in as" a client. Flagged in `text/01-auth.md` as "next step". Cycle 16+.
- **Cross-domain SSO** — bearer-handoff between whitelabel domains for platform users. Manual sign-in per domain works in v1.
- **TypeDB adapter for Better Auth** — the reference moved auth tables to D1 to escape gateway latency. We follow.
- **Replacing `lib/typedb.ts`** — substrate client unchanged; only its callers (the new `ensureHumanUnit`, role-grant lookups) are new.
- **Federation** — `actor-type: world` is in the ontology but cross-world auth (one ONE world signing into another) is a v2 conversation.
- **BaaS via gateway** — third parties hit `one.ie/api/*`, not `api.one.ie/typedb/query`. v2.
- **zkLogin** — reference has `pages/auth/zklogin/`; defer.
- **Schema changes to `one.tql`** — none. The ontology is sufficient.
- **SAML SSO** — no Better Auth plugin; `node-saml` adds 3–4 cycles. OIDC (§20e) covers Okta, Azure AD, Google Workspace. Defer until §20e ships and a customer explicitly requires SAML. See §20f.

---

## 19. Decisions (resolved)

The seven open questions from prior drafts collapsed against `text/01-auth.md`, `passkeys.md`, and the reference. Each decision is sourced; the relevant section absorbs the detail.

| # | Decision | Source | Folds into |
|---|---|---|---|
| 1 | Agent self-registration **open** by design; SIWE is the upgrade path; blast radius bounded by 4-action `agent` role + 24h TTL | `text/01-auth.md` "agent self-registration" | §5b |
| 2 | MCP consent rendered inline on **`/signin`**; one surface for humans, agents, MCP clients | `text/01-auth.md` "MCP OAuth"; `apps/dev.one.ie/src/lib/auth.ts:189` (`loginPage: '/signin'`) | §8c, §8d |
| 3 | Vault KDF locked: PRF salt `"one.ie-wallet-v1"`, HKDF info strings `"wallet-wrap-v1"` and `"vault.sync.export.v1"`, SHA-256, AES-256-GCM | `plans/world/passkeys.md:72-74, 125-132` | §11a |
| 4 | **No `one.tql` change.** OAuth provider IDs stay in D1 `account` only. `identity-link` stays defined-but-unused. Substrate-side, `actor.wallet` is the only external identifier | `apps/dev.one.ie/src/lib/auth-plugins/wallet-link.ts:48-71` (writes to entity attribute, not relation) | §3, §8b |
| 5 | Whitelabel TLS via **Cloudflare for SaaS Custom Hostnames**; CF owns cert lifecycle; we own one D1 table, one verify endpoint, one polling worker | `apps/dev.one.ie/migrations/0018_domains.sql` (`ssl_status` column) | §6a |
| 6 | **`group.plan` in TypeDB is the only source of truth.** KV invalidation-cached for reads; Stripe webhook writes TypeDB and deletes the KV key. No D1 mirror. | This plan (architectural choice — minimizes stores) | §6c |
| 7 | Action namespace **frozen at 28**: 22 inherited verbatim from `role-check.ts`, 6 new (`chat_read`, `chat_write`, `vault_sync`, `mcp_register`, `verify_domain`, `grant_capability`). snake_case. Freeze gate at cycle 8. | `apps/dev.one.ie/src/lib/role-check.ts:1-22` | §4d |

No open questions remain. `auth-todo.md` can be written from §12 directly.

---

## 20. Enterprise hardening (cycles 17–20)

Four post-cutover cycles. Each is independently deployable, gated on the enterprise plan tier. No `one.tql` schema changes; all new state lives in D1 or KV.

**Action namespace:** no new actions needed. Enterprise cycles use existing `update_group` (policy, SSO config, SCIM token), `verify_domain` (domain auto-join config), and `remove_unit` (offboarding). The 28-action freeze gate holds.

---

### 20a. Auth policy (cycle 17)

Group-level auth enforcement. Stored in KV (`policy:{gid}` → JSON), read by middleware alongside brand, enforced inside `requireAuth`.

```ts
interface GroupPolicy {
  allowed_methods: ('passkey' | 'google' | 'magic_link' | 'email_password' | 'wallet' | 'sso')[]
  require_passkey:  boolean    // session must originate from passkey or OIDC with MFA
  session_ttl:      number     // seconds; 0 = Better Auth default (7d)
  ip_allowlist:     string[]   // CIDR blocks; empty = no restriction
}
```

Written by `PUT /api/groups/{gid}/policy` (requires `update_group`). `requireAuth` enforces `allowed_methods` against `session.account.provider_id`; checks IP via `CF-Connecting-IP`; rejects sessions older than `session_ttl`. Policy applies to all members including those arriving via hierarchy traversal.

### 20b. Domain auto-join (cycle 17)

One new column on the existing `domains` table: `auto_join_role TEXT` (null = off). Migration `0061_domain_auto_join.sql` — `ALTER TABLE domains ADD COLUMN auto_join_role TEXT`.

`ensureHumanUnit` checks the user's email domain against `domains` on every first session. Match with a non-null `auto_join_role` → insert membership before returning. Works for platform subdomains and custom hostnames alike.

Admin route: `PUT /api/domains/{host}/auto-join { role: 'member' | 'viewer' | null }` (requires `verify_domain`).

### 20c. Automated offboarding (cycle 18)

`POST /api/auth/members/{slug}/offboard` (requires `remove_unit`, owner only). One TypeDB transaction cascades across the caller's active group and all descendants:

```tql
match
  $target isa actor, has aid "{slug}";
  $m (group: $g, member: $target) isa membership;
  { $g is $caller_group; } or { (ancestor: $caller_group, descendant: $g) isa hierarchy; };
delete $m isa membership;
```

Synchronously revokes all Better Auth sessions (D1 `session` rows deleted by `user_id`) and expires all API keys (`actor.valid-to = now`). Does not delete the actor — they retain their personal group and can still sign in to unrelated groups.

### 20d. SCIM 2.0 (cycle 19)

Standard provisioning API. Bearer-authenticated with a per-group SCIM token (hashed in `scim_tokens` D1 table, migration `0062_scim_tokens.sql`). Token issued via `POST /api/groups/{gid}/scim-token` (requires `update_group`).

| SCIM endpoint | Action |
|---|---|
| `POST /scim/v2/Users` | `ensureHumanUnit` + membership at group's default role |
| `PATCH /scim/v2/Users/{id}` | update `user.name` / `user.email` |
| `DELETE /scim/v2/Users/{id}` | offboarding cascade (§20c) |
| `PATCH /scim/v2/Groups/{id}` | add/remove TypeDB memberships |

SCIM `id` = Better Auth `user.id` (UUID). SCIM `userName` = `user.slug`. Group ID = `group.gid`.

### 20e. OIDC SSO (cycle 20)

Per-group IdP config in D1 `sso_config` table (migration `0063_sso_config.sql`): `gid TEXT PK, discovery_url TEXT, client_id TEXT, client_secret_enc TEXT, attribute_mapping TEXT, enabled_at INTEGER`.

Sign-in flow:
1. User enters email in `SignInWithAnything`
2. `GET /api/auth/sso/initiate?email=user@acme.com` — checks email domain against `sso_config`
3. On match → redirect to IdP `authorization_endpoint` (from discovery URL)
4. `GET /api/auth/sso/callback` — validates `id_token`, maps attributes via `attribute_mapping`, calls `ensureHumanUnit`
5. Auth policy (§20a) can restrict the group to `allowed_methods: ['sso']` only — enforces SSO-only sign-in for the whole group

Better Auth's `oidc` plugin handles token exchange. New `SSOButton.tsx` appears in `SignInWithAnything` when `?email=` matches a configured domain.

Routes:
- `GET/PUT /api/groups/{gid}/sso` — configure IdP (requires `update_group`)
- `GET /api/auth/sso/initiate` — public; email-domain routing
- `GET /api/auth/sso/callback` — public; token exchange + session creation

### 20f. SAML — deferred

No Better Auth SAML plugin. Implementation requires `node-saml`, custom SP metadata endpoint, IdP metadata import, assertion parsing, and attribute mapping — approximately 3–4 cycles. Defer until OIDC (§20e) is validated in production and a customer explicitly requires SAML. Okta, Azure AD, and Google Workspace all support OIDC; SAML is legacy infrastructure for older corporate deployments only.

---

## Provenance

| Layer | Source |
|---|---|
| Promise | `text/01-auth.md` — kept unchanged; this plan ships to match it |
| Gap | `plans/improve/01-auth.md` — every gap addressed in §8, §12, §15 |
| Reference | `apps/dev.one.ie/` — strong reference, deviations enumerated (§9, §8a typedb-adapter not ported) |
| Ontology | `schema/one.tql` — no edits; one candidate rename flagged (§19.4) |
| Target | `one.ie/web/` — cutover at cycle 15 |

*Slug is the universal identifier. Principal is the unit of trust. `requireAuth(action)` is the only thing routes call. Better Auth runs sessions; TypeDB runs reality; `ensureHumanUnit` is the bridge. The cascade is structural. The whitelabel is `group.brand`. The audit is the substrate.*
