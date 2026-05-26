# Invitations

How we bring agencies, clients, and staff into ONE — zero friction, pre-auth on click.

---

## Principle

An invitation is a credential, not a notification. When someone clicks an invite link, they are already inside their workspace — no separate sign-in step. The token is the auth.

---

## Current state

| What exists | Where |
|---|---|
| HMAC-signed invite tokens (7-day TTL) | `src/lib/invite-token.ts` |
| D1 invites table (`invites_v2`) | `migrations/0057_invites_v2.sql` |
| `POST /api/invites/create` — issues token | `src/pages/api/invites/create.ts` |
| `POST /api/invites/accept` — redeems token | `src/pages/api/invites/accept.ts` |
| `InviteGate` — landing holding page | `src/components/auth/InviteGate.tsx` |
| `InviteCodeEntry` — paste/accept UI | `src/components/auth/InviteCodeEntry.tsx` |
| `InvitesPane` — sidebar badge | `src/components/sidebar/InvitesPane.tsx` |
| Agency list | `src/pages/u/[slug]/agencies/index.astro` |
| Client list | `src/pages/u/[slug]/clients.astro` |
| Staff list + promote | `src/pages/u/[slug]/staff.astro` |

**Gap:** accepting a token is a two-step dance — arrive at `/join`, paste token, then accept. New users also need a separate sign-in. The token is not yet a credential that creates a session.

---

## The two invite modes

### Mode A — Pre-configured workspace

Operator sets up the workspace first (branding, members, data), then sends the invite. The invitee lands in a ready environment.

```
Operator configures workspace
  → sets brand colours, logo, domain alias
  → pre-loads client data or agent definitions
  → adds initial members with correct roles
Operator triggers invite (agency / client / staff panel)
  → system issues signed token + stores invite row
  → email or copy-link dispatched
Invitee clicks link
  → token verified + session created atomically
  → account created if new user (email from token payload)
  → membership written (TypeDB signal)
  → redirect to workspace /u/[slug]/dashboard
  → workspace is already live
```

Use cases: onboarding a new agency white-label, handing a client their configured workspace, adding a staff member to an already-running system.

### Mode B — Self-onboarding

Operator creates the account shell and sends the invite. The invitee configures their own workspace after sign-in.

```
Operator triggers invite (minimal — just email + role)
Invitee clicks link
  → token verified + session created atomically
  → account created if new user
  → redirect to /onboarding/[slug]
  → onboarding wizard: workspace name, logo, first agent, first client
```

Use cases: agency signing up their own staff, client who wants to self-configure, developer evaluating ONE.

---

## Token-as-credential flow (the zero-friction mechanism)

The invite token currently stores `{ id, gid, role, exp }`. To make it an auth credential, the accept endpoint must atomically:

1. Verify HMAC + TTL — existing logic, keep it
2. Look up or create a user record for the invited email
3. Issue a session (same mechanism as passkey/social login)
4. Write membership (TypeDB signal `auth:invite_accepted`) — existing logic, keep it
5. Mark invite `accepted_at = now()` — existing logic, keep it
6. Return a `Set-Cookie` session header + redirect to workspace

Single HTTP round-trip. No second login page.

Two entry points, same backend flow:

**1. Link click** — token in the URL
```
https://one.ie/join?token=<signed-token>
```
On GET `/join`: server-side verify → accept+auth → redirect. No UI, no paste step.

**2. Paste on the homepage** — `index.astro` already renders `InviteGate` with an "Enter code" tab. Currently that tab redirects to `/join` for a second step. The fix: the "Enter code" tab submits directly to `POST /api/invites/accept` and on success the page does a client-side redirect to the workspace. Same single round-trip, no second page.

`InviteGate` already calls `extractToken()` which strips URLs down to the raw token — so a user can paste either the full link or just the code and it resolves correctly.

For security, tokens remain single-use. Re-visit of a used link → redirect to the workspace directly if the session is live, or to sign-in if not.

---

## Invite surfaces by audience

### Agencies (`/u/[slug]/agencies`)

Triggered from the agency list page. Operator fills:
- Agency name (pre-populates workspace slug)
- Primary contact email (goes in token payload as `email`)
- Role: `owner` (agency gets full control of their sub-workspace)
- Mode A or B toggle

The invite creates a child workspace row + membership row in a pending state. When accepted, both are activated.

### Clients (`/u/[slug]/clients`)

Triggered from the client list page or the `NewClientDialog`. Operator fills:
- Client name
- Primary contact email
- Role: `owner` or `admin`
- Mode A or B toggle

Pre-configuration (Mode A) opens the client workspace in the operator's context for setup before the invite is dispatched. A status badge on the client row shows `Pending invite` until accepted.

### Staff (`/u/[slug]/staff`)

Triggered from the staff management page. Operator fills:
- Email
- Staff role level (mirrors current `staff_role` boolean — extend to levels if needed)

Staff invites always Mode A (the system is already running). No onboarding wizard.

---

## Delivery

Three delivery methods, selectable per invite:

| Method | When to use | How |
|---|---|---|
| **Email** | Client/agency — formal, trackable | Resend via `api/invites/send-email` |
| **Copy link** | Internal/staff — fast, trusted channel | Operator copies from panel, sends via Slack/WhatsApp |
| **QR code** | In-person onboarding | Rendered in the panel, printable |

All three routes resolve to the same `/join?token=` URL. No special handling per delivery method.

---

## Status tracking

The `invites` D1 table already has `accepted_at`. Add:

| Column | Type | Purpose |
|---|---|---|
| `sent_at` | INTEGER | When the email/notification was dispatched |
| `mode` | TEXT | `'preconfigured'` or `'self_onboard'` |
| `workspace_ready` | INTEGER | Boolean — operator has finished pre-config |

Panel shows per-invite status chips:

```
[ Configuring ]  → operator is setting up workspace (Mode A only)
[ Ready to send ] → workspace ready, invite not yet dispatched
[ Sent ]          → dispatched, not accepted
[ Accepted ]      → live
[ Expired ]       → TTL passed, offer to re-send
```

---

## Resend and expiry

When an invite expires (7-day TTL hit before acceptance):
- Status chip shows `Expired`
- Re-send is a two-step confirmation: panel shows current workspace state (configured / empty) and asks the operator to confirm it's still ready before dispatching
- On confirmation: new token issued, old token hash marked `superseded`, new `sent_at` recorded
- Workspace pre-config is preserved — operator does not redo setup, just confirms
- Re-send uses the same delivery method as the original (email / copy-link / QR) unless the operator changes it

---

## Onboarding wizard (Mode B)

Minimal, skippable. Three steps:

1. **Workspace name** — pre-filled from invite payload, editable
2. **Logo + colour** — drag-upload or skip → defaults to initials avatar
3. **First action** — fork: `Add your first client` / `Invite a team member` / `Skip to dashboard`

Each step signals TypeDB (`signal("onboarding:step_complete", ...)`). The wizard knows which steps are done and resumes correctly on refresh.

---

## Pages to build / modify

| File | Change |
|---|---|
| `src/pages/join.astro` | Convert from client-only InviteCodeEntry → server-side token verify + auth + redirect (GET handler); link-click entry point |
| `src/pages/index.astro` + `InviteGate.tsx` | "Enter code" tab: submit directly to `/api/invites/accept` instead of redirecting to `/join`; paste entry point |
| `src/pages/api/invites/create.ts` | Add `mode`, `email` (required), `workspace_ready` fields to payload |
| `src/pages/api/invites/accept.ts` | Extend: create user if new, issue session cookie, redirect |
| `src/pages/api/invites/send-email.ts` | New — Resend integration, dispatch invite email with token link |
| `src/pages/u/[slug]/agencies/index.astro` | Add invite trigger per agency row + `New agency + invite` flow |
| `src/pages/u/[slug]/clients.astro` | Add invite trigger, status chips, Mode A pre-config entry point |
| `src/pages/u/[slug]/staff.astro` | Replace raw email form with invite flow (copy-link primary) |
| `src/pages/onboarding/[slug].astro` | New — Mode B wizard |
| `migrations/XXXX_invites_v3.sql` | Add `sent_at`, `mode`, `workspace_ready` columns |

---

## Signals

| Event | Signal key | When |
|---|---|---|
| Operator creates invite | `auth:invite_created` | existing — keep |
| Email dispatched | `auth:invite_sent` | new |
| Invitee clicks link | `auth:invite_clicked` | new — fires before auth |
| Invitee accepts + session created | `auth:invite_accepted` | existing — extend to include session issuance |
| Invite expired without use | `auth:invite_expired` | new — scheduled check or on-access |
| Onboarding step complete | `onboarding:step_complete` | new |
| Onboarding wizard finished | `onboarding:complete` | new |

---

## Domain aliases

Invite links for agencies use the agency's custom domain when one is configured:

```
https://[agency-domain]/join?token=<signed-token>   ← custom domain
https://one.ie/join?token=<signed-token>             ← fallback
```

**Gate:** the custom domain option is only shown in the invite panel if the agency's domain alias is DNS-verified. If DNS is not verified, the panel shows a warning and the link defaults to `one.ie/join`. Dispatching an invite before the domain is live would break the link — this gate prevents that.

The `join` route must exist (or be proxied) on the agency domain. In practice this means the agency's Cloudflare Worker responds to `[agency-domain]/join` and proxies to the same accept+auth flow. The token itself is domain-agnostic — verification is HMAC-keyed, not origin-keyed.

---

## Role escalation rules

An actor can only grant roles they are permitted to grant. The rule depends on whether the invite is same-workspace or cross-workspace (parent → child).

### Same workspace

| Inviter role | Max role they can grant |
|---|---|
| `owner` | `owner` |
| `admin` | `admin` |
| `member` | cannot invite |
| `viewer` | cannot invite |

An admin inviting into their own workspace cannot grant `owner`. That would let them create a peer who could then demote them — privilege escalation.

### Cross-workspace (parent inviting into child)

An admin or owner at a parent workspace can grant `owner` into a child workspace they manage. Ownership of a child is a scoped grant — that owner operates within a subordinate context and cannot affect the parent.

```
Parent workspace (admin A)
  └─ Child workspace (inviting new owner B)   ← allowed
       └─ B can only act within child scope
```

Rule: **cross-workspace owner grant is allowed if and only if the inviter's workspace is a verified parent of the target workspace.**

### Enforcement at `POST /api/invites/create`

Before issuing the token, the API must verify:

1. `inviter_role >= 'admin'` in `inviter_workspace`
2. If `target_role == 'owner'`:
   - If `target_workspace == inviter_workspace` → **reject 403**
   - If `target_workspace` is a child of `inviter_workspace` → **allow**
   - Otherwise → **reject 403**
3. If `target_role != 'owner'`: `target_role <= inviter_role` (no role above self)

The parent-child relationship is verified against D1 (the `groups` table hierarchy), not taken from the request payload — the client cannot self-assert parenthood.

---

## Security notes

- Token is HMAC-signed — cannot be forged without `INVITE_SECRET`
- Single-use enforced by `accepted_at` check — replay returns 410
- Session issued only after token verification — no auth bypass path
- `email` in token payload is informational; session is keyed to the verified token `id`, not the email string
- Operator who created the invite must hold `invite_member` permission — existing gate, keep
- Accepting still requires `discover` permission — but for brand-new users this is granted implicitly on account creation (they exist, therefore they can discover themselves)
- Role ceiling enforced server-side at invite creation, not at accept time — the token encodes the role, so accept-time check is replay protection only
- Domain alias used in link must be DNS-verified before dispatch — prevents broken links and phishing via unverified domains
- Parent-child relationship verified in D1, never from client payload — prevents privilege escalation via forged workspace hierarchy claims

---

## Open questions

2. **Bulk invites** — clients with large teams may want CSV upload. Out of scope for v1; plan separately if needed.
