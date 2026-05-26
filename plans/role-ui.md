# role-ui.md — Roles, Hierarchy, and UI

Roles are the Group dimension projected into a UI lens. Four tiers, one hierarchy, one switcher. No extra schema needed.

---

## The Four Tiers

| Tier | Who | How derived |
|------|-----|-------------|
| `owner` | Platform admin | `staffRole = true` in session |
| `agency` | Owns the active workspace, or holds `manage_clients` | `ownerSlug === workspaceSlug` or `hasManageClients` cap |
| `client` | Authenticated, visiting another owner's workspace | Session present, different slug |
| `end_user` | Anonymous visitor | No session |

Additive downward: `owner ⊃ agency ⊃ client ⊃ end_user`. Derived per active group in middleware on every request — not once per session.

```ts
// src/lib/viewer.ts
export function deriveViewer(session: SessionInfo): Viewer {
  if (session.staffRole) return 'owner'
  if (!session.hasSession) return 'end_user'
  if (session.ownerSlug === session.workspaceSlug) return 'agency'
  if (session.hasManageClients) return 'agency'
  return 'client'
}
```

---

## The Hierarchy

```
owner (Tony)
  └── creates agencies

agency (ACME)
  ├── creates sub-agencies  (Brad's Agency — same mechanism as clients)
  └── creates clients       (Startup-1, BigCorp, ...)
        └── their end users
```

An agency creates its own plan and configures what each client gets via `site.md` in R2. Enterprise features (SSO, divisions, custom domains) are things an agency enables for a client in their config — not a separate hardcoded plan tier. No schema changes needed.

`hierarchy(parent, child)` in TypeDB encodes the relationship. `manage_clients` capability is granted when an org is provisioned with the ability to create children.

---

## How Viewer Flows

```
middleware.ts  →  ctx.locals.workspaceContext.viewer
Layout.astro   →  prop to every surface
```

Components receive `viewer` as a prop. They never fetch it.

---

## What Each Tier Sees

### Nav (`/u/[slug]/...`)

| Route | owner | agency | client | end_user |
|-------|:-----:|:------:|:------:|:--------:|
| `/dashboard` | ✓ | ✓ | ✓ | — |
| `/in` | ✓ | ✓ | ✓ | — |
| `/chat` | ✓ | ✓ | ✓ | ✓ |
| `/agents` | ✓ | ✓ | ✓ | — |
| `/skills` | ✓ | ✓ | — | — |
| `/tools` | ✓ | ✓ | ✓ | — |
| `/people` | ✓ | ✓ | — | — |
| `/clients` | ✓ | ✓ (manage_clients only) | — | — |
| `/analytics` | ✓ | ✓ | — | — |
| `/audit` | ✓ | ✓ | — | — |
| `/payments` | ✓ | ✓ | ✓ | — |
| `/settings` | ✓ | ✓ | ✓ | — |

`/people` — members (actors) of this group.
`/clients` — child orgs of this group. Only shown when `manage_clients` is active.

### Surface gates

| Surface | owner | agency | client | end_user |
|---------|:-----:|:------:|:------:|:--------:|
| Create agents | ✓ | ✓ | — | — |
| Import skills | ✓ | ✓ | — | — |
| Workspace branding | ✓ | ✓ | — | — |
| `/design` token editor | ✓ | own ws | — | — |
| Act As another user | ✓ | ✓ (own org + clients) | — | — |
| Create child org | ✓ | ✓ (manage_clients) | — | — |

---

## Anonymous → Identified → Authenticated

Every user starts anonymous and may never go further. The tier system reflects this progression.

```
Anonymous                Identified               Authenticated
(end_user)          →   (still end_user)      →   (client or agency)

No session              Has email                  Has passkey + session
vid cookie only         Pending invite token       actor in TypeDB
Sees chat only          Invite landing page        Personal group provisioned
                        Sign-up / passkey step     Org membership written
                                                   Upgrade pulse fires
```

### Stage 1 — Anonymous (`end_user`)

Middleware sets a `vid` cookie (hashed visitor ID, never PII). The visitor sees Chat and public agents only. No sidebar nav beyond Chat.

The UI needs a visible nudge to convert: a soft CTA in the chat input area — *"Save your conversation — sign in"* — that doesn't interrupt the session but is always reachable. Currently missing.

### Stage 2 — Identified (still `end_user`)

The visitor has given their email — either by clicking an invite link from `CreateOrgDrawer` or filling a form. A pending invite token exists in D1. They have not registered a passkey yet.

**Invite landing page** (`/go/[token]` or `/invite/[token]`):

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   [ACME logo]                                       │
│                                                     │
│   Alice has invited you to ACME                     │
│   You'll join as a member of the workspace.         │
│                                                     │
│   Your email: brad@example.com                      │
│                                                     │
│   [Set up your account →]                           │
│                                                     │
│   Already have an account? [Sign in]                │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Stage 3 — Authenticated (`client` or `agency`)

After passkey registration:
- `actor` written to TypeDB, personal group provisioned
- Anonymous `vid` history linked to the new actor
- Org membership written (if invited)
- Redirect to `/u/[slug]/dashboard` as `client`
- Upgrade pulse fires: switcher pulses once, toast shows *"You now have access to ACME"*

If the user creates their own org rather than joining via invite, they land on `/u/[slug]/onboarding` as `agency`.

### The gap in the current flow

`/go/[token]` invite landing page is not yet built. `CreateOrgDrawer` sends the email but there is no page to receive the invitee. This is the first thing to close.

---

## Page Sketches

### Owner — switcher open

```
┌────────────────────────────────────┐
│ ┌─ GroupSwitcher ───────────────┐  │
│ │ 🔍 Search groups…             │  │
│ ├───────────────────────────────┤  │
│ │ Personal                      │  │
│ │  ● ONE               owner    │  │
│ ├───────────────────────────────┤  │
│ │ Agencies                      │  │
│ │  ● ACME              owner    │  │
│ │  ● BigCorp           owner    │  │
│ ├───────────────────────────────┤  │
│ │ [+ New agency]                │  │
│ │ [+ New client]                │  │
│ │ [+ Join via invite]           │  │
│ └───────────────────────────────┘  │
└────────────────────────────────────┘
```

### Owner — `/u/tony/clients`

```
┌──────────────────┬─────────────────────────────────────────┐
│ [ONE]            │ Clients                  [+ New org ▾]  │
│ ─────────────    │                           ├─ Agency      │
│ 📊 Dashboard     │                           └─ Client      │
│ 💬 Chat          ├─────────────────────────────────────────┤
│ 🤖 Agents        │ 🔍 Search…                               │
│ ⚡ Skills        ├──────────────────┬────────┬────────┬────┤
│ 👥 People        │ Name             │ Type   │ People │    │
│ 🏢 Clients  ←   ├──────────────────┼────────┼────────┼────┤
│ 📈 Analytics     │ ACME             │ agency │   8    │ ···│
│ 🛡 Audit         │ BigCorp          │ agency │  45    │ ···│
│ 💳 Payments      │                  │        │        │    │
│ ⚙️  Settings      │                  │        │        │    │
└──────────────────┴─────────────────────────────────────────┘
```

### Owner / Agency — `CreateOrgDrawer`

```
                        ░┌───────────────────────┐░
                        ░│ New org            ✕  │░
                        ░├───────────────────────┤░
                        ░│ Type                  │░
                        ░│ ● Agency  ○ Client    │░
                        ░│                       │░
                        ░│ Name                  │░
                        ░│ ┌───────────────────┐ │░
                        ░│ │ ACME              │ │░
                        ░│ └───────────────────┘ │░
                        ░│                       │░
                        ░│ Slug                  │░
                        ░│ ┌───────────────────┐ │░
                        ░│ │ acme      .one.ie  │ │░
                        ░│ └───────────────────┘ │░
                        ░│                       │░
                        ░│ Invite owner          │░
                        ░│ ┌───────────────────┐ │░
                        ░│ │ ceo@acme.com      │ │░
                        ░│ └───────────────────┘ │░
                        ░│                       │░
                        ░│ [Cancel]  [Create →]  │░
                        ░└───────────────────────┘░
```

On submit: creator stays on `/clients`, new row appears. Invitee receives email → `/go/[token]` → register → `/u/new-slug/onboarding`.

### Agency — `/u/acme/clients`

```
┌──────────────────┬─────────────────────────────────────────┐
│ [ACME]           │ Clients                  [+ New org ▾]  │
│ ─────────────    │                           ├─ Agency      │
│ 📊 Dashboard     │                           └─ Client      │
│ 💬 Chat          ├─────────────────────────────────────────┤
│ 🤖 Agents        │ 🔍 Search…                               │
│ ⚡ Skills        ├────────────────┬────────┬───────┬───────┤
│ 👥 People        │ Name           │ Type   │ People│Clients│
│ 🏢 Clients  ←   ├────────────────┼────────┼───────┼───────┤
│ 📈 Analytics     │▸ Brad's Agency │ agency │  12   │  3  ···│
│ 🛡 Audit         │  ├─ Client A   │ client │   4   │  — ···│
│ 💳 Payments      │  └─ Client B   │ client │   9   │  — ···│
│ ⚙️  Settings      │  Startup-1    │ client │   3   │  — ···│
└──────────────────┴─────────────────────────────────────────┘
```

Sub-agency rows expand in place. `···` → Open workspace · Act As owner · Manage people · Archive.

### Sub-agency (Brad) — `/u/brads-agency/clients`

Same layout as above. Brad sees only his own clients — ACME's other orgs are invisible.

```
┌──────────────────┬─────────────────────────────────────────┐
│ [Brad's Agency]  │ Clients                  [+ New org ▾]  │
│ ─────────────    ├─────────────────────────────────────────┤
│ 📊 Dashboard     │ Name           │ Type   │ People        │
│ 💬 Chat          ├────────────────┼────────┼───────────────┤
│ 🤖 Agents        │ Client A       │ client │   4        ···│
│ ⚡ Skills        │ Client B       │ client │   9        ···│
│ 👥 People        │ Client C       │ client │  23        ···│
│ 🏢 Clients  ←   │                │        │               │
│ 📈 Analytics     │                │        │               │
│ 💳 Payments      │                │        │               │
│ ⚙️  Settings      │                │        │               │
└──────────────────┴─────────────────────────────────────────┘
```

### Client — dashboard (restricted nav)

No `/clients`, `/skills`, `/people`, `/analytics`, `/audit`.

```
┌──────────────────┬─────────────────────────────────────────┐
│ [Startup-1]      │ Dashboard                               │
│ ─────────────    ├─────────────────────────────────────────┤
│ 📊 Dashboard  ← │  [usage · recent activity]              │
│ 📥 Inbox         │                                         │
│ 💬 Chat          │                                         │
│ 🤖 Agents        │                                         │
│ 🔧 Tools         │                                         │
│ 💳 Payments      │                                         │
│ ⚙️  Settings      │                                         │
│ ─────────────    │                                         │
│ [sign out]       │                                         │
└──────────────────┴─────────────────────────────────────────┘
```

Switcher footer: `[+ Join via invite]` only. No create options.

### End user — chat only

```
┌──────────────────┬─────────────────────────────────────────┐
│ [workspace logo] │                                         │
│ ─────────────    │   [agent welcome message]               │
│ 💬 Chat      ←  │                                         │
│                  │   ┌─────────────────────────────────┐   │
│                  │   │ Ask anything…        [↑]        │   │
│ ─────────────    │   └─────────────────────────────────┘   │
│ Sign in          │   Save your conversation · Sign in      │
└──────────────────┴─────────────────────────────────────────┘
```

"Save your conversation · Sign in" is the conversion nudge. Currently missing.

### Onboarding — after invite accepted

```
┌──────────────────┬─────────────────────────────────────────┐
│ [New Org]        │  Set up your workspace          2 of 4  │
│                  │─────────────────────────────────────────│
│                  │  ① Name & logo         ✓               │
│                  │  ② Brand colours       ←               │
│                  │  ③ Custom domain                        │
│                  │  ④ Invite your team                     │
│                  │─────────────────────────────────────────│
│                  │  Primary colour                         │
│                  │  ┌─────────────────────────────────┐    │
│                  │  │ #3B82F6          [preview]      │    │
│                  │  └─────────────────────────────────┘    │
│                  │                                         │
│                  │  [← Back]                  [Next →]     │
└──────────────────┴─────────────────────────────────────────┘
```

Steps vary by org type. Agency gets brand + domain. Client gets name + invite only.

---

## Gaps

| # | Gap | Impact |
|---|-----|--------|
| 1 | `/go/[token]` invite landing page missing — drawer sends email but nothing receives it | blocks CreateOrgDrawer invite flow |
| 2 | Switcher footer buttons not wired — `[+ New agency]` / `[+ New client]` shell exists, no drawer | blocks creation flow |
| 3 | `/u/[slug]/clients` page doesn't exist | blocks org management |
| 4 | `POST /api/groups` missing `parent_gid` + `invite_email` | blocks hierarchy creation |
| 5 | `/people` queries `agent_events` (analytics), not membership roster | misleading nav label; members roster lives in `/api/groups/members` |
| 6 | Onboarding has no org-type awareness — agency and client get same steps | wasted steps for clients |
| 7 | End user has no "sign in / save conversation" CTA visible in chat | zero conversion surface for anonymous users |
| 8 | Switcher section headers don't label "Agencies" / "Clients" — groups by org type internally | visual gap when owner has many orgs |

---

## How to Add UI for a Role

### New nav item

```ts
// src/lib/menu.ts — getUserMenu()
{ href: `${base}/new-route`, label: 'Label', icon: SomeIcon, viewer: ['owner', 'agency'] }
```

### New page — always gate at both layers

```astro
---
// src/pages/u/[slug]/new-route.astro
const { viewer } = Astro.locals.workspaceContext
if (viewer !== 'owner' && viewer !== 'agency') {
  return Astro.redirect(`/u/${Astro.params.slug}/chat`)
}
---
```

### Surface gate inside a page

```tsx
// React island — viewer arrives as a prop, never fetched
{(viewer === 'owner' || viewer === 'agency') && <CreateButton />}
```

---

## The Group Switcher

`GroupSwitcher.tsx` lives in the Sidebar header. Fetches `GET /api/groups/tree` (60s KV cache). Switching navigates to `/u/<gid>/<currentRoute>` — middleware recomputes viewer + config server-side.

### Footer actions

| Viewer | `manage_clients`? | Footer |
|--------|:-----------------:|--------|
| `owner` | — | [+ New agency] [+ New client] [+ Join via invite] |
| `agency` | yes | [+ New agency] [+ New client] [+ Join via invite] |
| `agency` | no | [+ Join via invite] |
| `client` | — | [+ Join via invite] |

An agency with `manage_clients` can create sub-agencies exactly as it creates clients. ACME adds Brad's Agency the same way it adds Startup-1.

---

## The Clients Page (`/u/[slug]/clients`)

Shows child orgs — not people. Distinct from `/people` which shows members.

```
┌──────────────────────────────────────────────────┐
│ Clients                         [+ New org ▾]    │
│                                  ├─ Agency        │
│                                  └─ Client        │
├────────────────────┬──────────┬────────┬──────────┤
│ Name               │ Plan     │ People │ Clients  │
├────────────────────┼──────────┼────────┼──────────┤
│ ▸ Brad's Agency    │ agency   │   12   │    3     │
│   ├─ Client A      │ starter  │    4   │    —     │
│   └─ Client B      │ scale    │    9   │    —     │
│ Startup-1          │ starter  │    3   │    —     │
│ BigCorp            │ custom   │   45   │    2     │
└────────────────────┴──────────┴────────┴──────────┘
```

`···` per row: Open workspace · Act As owner · Manage people · Archive.

Sub-agency rows expand to show their clients. Depth comes from `GET /api/groups/tree?depth=2`.

---

## CreateOrgDrawer

One component, triggered from the switcher footer or the `/clients` page.

```
┌──────────────────────────────────┐
│ New org                      ✕   │
├──────────────────────────────────┤
│ Name                             │
│ ┌──────────────────────────────┐ │
│ │ Brad's Agency                │ │
│ └──────────────────────────────┘ │
│                                  │
│ Slug                             │
│ ┌──────────────────────────────┐ │
│ │ brads-agency        .one.ie  │ │
│ └──────────────────────────────┘ │
│                                  │
│ Type   ● Agency  ○ Client        │
│                                  │
│ Invite owner (optional)          │
│ ┌──────────────────────────────┐ │
│ │ brad@example.com             │ │
│ └──────────────────────────────┘ │
│                                  │
│ [Cancel]          [Create →]     │
└──────────────────────────────────┘
```

`POST /api/groups { name, slug, type, parent_gid, invite_email }` — existing endpoint, add `parent_gid` + `invite_email`. On success: creator stays on `/clients`; invitee lands on `/u/new-slug/onboarding`.

---

## What's New vs Already Built

| Thing | Status |
|-------|--------|
| 4-tier viewer + nav filtering | ✓ done |
| Group switcher + manage_clients | ✓ done |
| Act As + audit | ✓ done |
| `/u/[slug]/clients` page | **new** |
| `ClientsTable` component | **new** |
| `CreateOrgDrawer` component | **new** |
| `[+ New org]` in switcher footer | **new** (wire existing shell) |
| `Clients` nav item in `menu.ts` | **new** (1 line) |
| `parent_gid` + `invite_email` on `POST /api/groups` | **new** (extend existing) |
| `GET /api/groups/tree?depth=2` | **new** (extend existing) |

---

## See Also

- `plans/roles.md` — surface matrix, cascade model, locking grammar
- `plans/groups.md` — RBAC/ABAC/ReBAC, membership schema
- `plans/role-switcher.md` — switcher design, Act As, companion surfaces
- `src/lib/viewer.ts` — `deriveViewer()` pure function
- `src/lib/menu.ts` — `getUserMenu()` nav filtering
- `src/middleware.ts` — viewer resolution per request
