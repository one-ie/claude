---
mode: lean
lifecycle: construction
classifier:
  spec_locked: true
  variance_known: true
  exit_scalar: "every level of the agency cascade has a defined promotion path, billing rule, and branding rule"
  files_known: true
---

# cascade.md — Sub-client agency hierarchy

`roles.md` describes the 4 viewer tiers (owner / agency / client / end_user).
This doc describes what happens **when those tiers nest** — agency provisions
a child workspace, the child becomes an agency in their *own* workspace, and
they in turn invite their own clients. The resell loop, drawn explicitly.

> The mechanism is migration `0008_workspace_hierarchy.sql` (`owners.parent_slug`).
> Everything below derives from that single column.

---

## 1. The three-level pattern

```
LEVEL 0 — Platform                  one.ie (Tony's workspace)
   │
   │ provisions
   ▼
LEVEL 1 — Agency                    acme.com (parent_slug = NULL)
   │   plan: agency
   │   viewer-of-self: agency
   │
   │ provisions (via invite)
   ▼
LEVEL 2 — Child workspace           startup-1.acme.com (parent_slug = 'acme')
   │   plan: free | pro | agency
   │   viewer-of-self: agency in their own workspace
   │
   │ if plan = agency, can provision …
   ▼
LEVEL 3 — Grandchild workspace      sub.startup-1.acme.com (parent_slug = 'startup-1')
       plan: free | pro | agency
       viewer-of-self: agency
```

**No depth limit in schema.** UI surfaces a max-depth of 3 by default
(platform → agency → child → grandchild) to keep the mental model bounded.
Deeper nesting works but doesn't get UI affordances.

---

## 2. The promotion path

How a workspace climbs from end_user → its own agency.

```
                                    │
end_user                            │ visits acme.com
                                    │ chats anonymously
                                    │
                                    ▼
end_user                            │ clicks "Save with Touch ID" or
                                    │ accepts invite from agency
                                    │
                                    ▼
client (in acme's workspace)        │ has a session, viewer = client
                                    │ can chat, use tools, see own payments
                                    │
                                    ▼
agency-of-self (in own workspace)   │ ALWAYS — every owner is agency in
                                    │ their own slug, regardless of plan
                                    │
                                    ▼
agency provisioning children        │ ONLY when plan in (agency, enterprise)
                                    │ unlocks /u/[slug]/settings#clients
```

Key rule: **everyone is `agency` in their own workspace.** The 4-tier model
applies *per workspace context*. Tony viewing `alice.one.ie` is `owner`
(staffRole). Alice viewing `alice.one.ie` is `agency`. Bob viewing
`alice.one.ie` is `client`.

---

## 3. Branding cascade (white-label)

| Level | What renders in sidebar Attribution | Override conditions |
|-------|-------------------------------------|---------------------|
| Platform (one.ie) | "Powered by ONE" | always (owner) |
| Agency (acme.com) | "Powered by ONE" if Free; hidden on Pro+; "Powered by ACME" never (acme IS the brand) | acme.plan ≥ pro hides; acme.plan ≥ agency can lock for children |
| Child (startup-1.acme.com) | "Powered by ACME" + "Powered by ONE" if both unlocked; cascade rules below | child.plan + parent's lock |
| Grandchild | Same logic, two-level chain | walks up `parent_slug` |

**Cascade rule** (executed top-down per render):
1. Walk the `parent_slug` chain from leaf → root.
2. At each ancestor: if `plan ≥ agency` AND `branding_lock = true`, that ancestor's
   "Powered by [name]" is non-removable on the child.
3. If `plan ≥ pro`, the child *can* hide "Powered by ONE" on its own surfaces
   (the platform-level attribution).
4. If `plan = free`, child shows everything: "Powered by ONE" + every locked
   ancestor "Powered by [parent]".

```
example: deep cascade
sub.startup-1.acme.com  on Free plan
  → ancestors: startup-1 (pro, no lock) → acme (agency, lock=true) → ONE
  → renders:  Powered by ACME (locked)
              Powered by ONE   (free tier shows it)
              [no startup-1 attribution — they didn't lock]

sub.startup-1.acme.com  on Pro plan
  → renders:  Powered by ACME (still locked — child can't override)
              [Powered by ONE hidden — Pro tier]
```

---

## 4. Billing cascade

Each workspace pays its own bill. The agency does **not** see invoices for
children — children manage their own Stripe customer.

| What | Who pays | Where it shows |
|------|----------|----------------|
| Child's Pro/Agency subscription | child's owner | child's `/payments` |
| Per-use revenue earned by child's skills | child's owner | child's `/payments` |
| Per-use revenue earned by agency's skills used in child's workspace | agency's owner | agency's `/payments` (cross-workspace section, future) |
| Platform 10% / x402 5% splits | always taken at the protocol level | every payment row |

**Agency's view of children**: `/u/[agency-slug]/settings#clients` shows a
read-only roster: child slug, plan, status (active / pending / cancelled),
last activity. Clicking a child opens a tooltip with stats but does NOT
grant the agency access to the child's wallet, agents, or chats. *The
agency provisioned the workspace; they don't own its data.*

This is the resell-loop trust contract: agency benefits from successful
children (referral fees, future), but children own their own keys.

---

## 5. Provisioning UI (where the cascade is created)

The flow that creates a child workspace, drawn against existing surfaces.

```
agency at  acme.com / settings  ─── §3.7 Settings → Clients section
    │
    │ click "+ Invite client"
    ▼
modal: { name, email, optional starter brand }
    │
    │ submit → POST /api/provision?action=create-invite
    ▼
invites row created (lifecycles-ui.md §4.2 schema)
    │
    │ email sent: "ACME invites you to startup-1.acme.com"
    ▼
client clicks email link → /u/startup-1?invite={token}
    │
    │ if no session: redirect /get-yours?return=...
    │ after passkey: redeem invite
    ▼
POST /api/provision?action=redeem-invite       ⬅ W9E2 in ui-todo
    │  - creates owners row { slug:'startup-1', parent_slug:'acme', credential }
    │  - marks invites.redeemed_at
    ▼
client lands at  /u/startup-1/onboarding
    │  (now they're agency-of-self in startup-1)
    ▼
3-step onboarding (lifecycles-ui.md §4.1):
    1. Display name
    2. Brand colour (or inherit from acme if locked)
    3. First agent
    ▼
startup-1 is live. They can now:
    - chat / build agents (everyone)
    - if their own plan ≥ agency → invite their own clients (level 3)
```

---

## 6. Limits per plan tier

| Plan | Children allowed | Branding lock | Custom domain |
|------|------------------|---------------|---------------|
| Free | 0 | – | – |
| Pro | 0 | – | ✓ (1 domain) |
| Agency | up to 20 | ✓ (locks "Powered by [agency]" on children) | ✓ (1 + child subdomains) |
| Enterprise | unlimited | ✓ + multi-level lock (locked attribution propagates further down) | ✓ (multi-domain) |

**Schema:** `owners.plan` (mig 0009). Limits enforced server-side in
`/api/provision?action=create-invite` — child count query before insert.

---

## 7. UI affordances per level

### Level 1 (agency in own workspace, no parent)

- Sidebar shows full menu (chat, agents, skills, tools, payments, settings)
- Settings → Clients visible if plan ≥ agency
- No "parent" indicator (they're the root of their tree)

### Level 2 (child workspace)

- Sidebar shows full menu (they're agency-of-self)
- Settings → **Parent** section (new, this doc spec):
  ```
  ┌── Parent workspace ─────────────────────┐
  │ This workspace is hosted by ACME.        │
  │   Plan: Pro                              │
  │   Locked attributions: "Powered by ACME" │
  │   [Contact ACME →]   [Leave parent →]*   │
  └─────────────────────────────────────────┘
  * "Leave parent" = pay for own custom domain, sever parent_slug;
    requires Pro+, requires explicit confirm modal (lifecycles-ui §7.3-style)
  ```
- Settings → Clients visible if their own plan ≥ agency

### Level 3 (grandchild)

- Same as Level 2, but Parent section walks the chain:
  ```
  ┌── Hierarchy ────────────────────────────┐
  │ ONE                                      │
  │  └── ACME (agency)                       │
  │       └── startup-1 (your parent)        │
  │            └── you                       │
  └─────────────────────────────────────────┘
  ```

---

## 8. Failure modes (what breaks the cascade)

| Event | Effect on children |
|-------|--------------------|
| Agency downgrades from Agency → Pro | Existing children survive but agency loses provisioning. Lock on attribution remains until agency cancels lock manually. Spec'd in lifecycles-ui §7.3. |
| Agency cancels subscription entirely | Children survive; their `parent_slug` stays. Agency's locked attribution stops rendering (agency is now Free, can't enforce locks). Children effectively become Level 1. |
| Agency deletes workspace (DangerSection) | Per W9E1: `parent_slug` of all children → NULL on CASCADE/SET NULL. Children become root-level workspaces. They keep their data. |
| Child fails payment (payment_status='failed') | Child UI shows PaymentFailureBanner. After grace, drops to Free tier. Children of this child (level 3) inherit (no cascade effect — billing is per-workspace). |

---

## 9. Cross-references

- `roles.md` — 4-tier model + 5 org patterns (Solo / Agency / Team / etc.)
- `lifecycles.md` — journey across roles
- `lifecycles-ui.md §4.2` — invite redemption flow + schema
- `lifecycles-ui.md §5.2` — ClientManager component
- `lifecycles-ui.md §5.3` — BrandingSettings (lock UI)
- `lifecycles-ui.md §7.3` — DowngradeImpactModal
- `web/migrations/0008_workspace_hierarchy.sql` — `parent_slug` column
- `web/migrations/0009_owners_plan.sql` — `plan` column (cascade limits)
- `web/migrations/0011_invites.sql` — invites table

---

*One column (`parent_slug`). Three levels by default. White-label cascades
top-down; billing stays per-workspace. Agencies provision; they don't own.*
