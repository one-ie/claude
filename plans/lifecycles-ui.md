# lifecycles-ui.md — UI Surfaces That Close the Lifecycle Gaps

`lifecycles.md` describes the journey. `roles.md` describes who sees what.
This doc names the **screens that don't exist yet** but must, to make every
lifecycle path frictionless. Each surface here is a UI spec: route, props,
behaviour, the conversion lever it carries.

If a moment in `lifecycles.md` has a friction symbol below, this is the surface
that removes it.

---

## 1. The Gap Map

Friction points across the four lifecycles, with the surface that closes each:

| # | Audience | Lifecycle moment | Friction | Surface (this doc §) | Severity |
|---|----------|------------------|----------|---------------------|----------|
| 1 | end_user | Discovers ONE through a workspace | No "Sign up" CTA visible | §3 Sidebar conversion footer | HIGH |
| 2 | end_user | Used priced skill 3+ times | No conversion prompt | §3 Skill-use lever (deferred) | MED |
| 3 | client | Just completed passkey | Lands on chat with no orientation | §4 `/u/[slug]/onboarding` | HIGH |
| 4 | client | Receives invite from agency | No invite redemption page | §4 Invite redeem flow | HIGH |
| 5 | client | First agent creation | Markdown-frontmatter-only editor | §4 Form-based agent creator | HIGH |
| 6 | agency | Wants to upgrade | No Plan section in settings | §5 Settings → Plan | HIGH |
| 7 | agency | Hits a plan gate | No upgrade prompt — bare 403 | §5 UpgradePrompt at trigger points | HIGH |
| 8 | agency | Wants to provision a client | No Clients section | §5 Settings → Clients | HIGH |
| 9 | agency | Pro plan paid, attribution still showing | No Branding section | §5 Settings → Branding | MED |
| 10 | agency | Wants to see earnings | Payments page is empty | §5 Revenue dashboard (early) | MED |
| 11 | any paying | Stripe payment fails | No banner, no recovery path | §7 PaymentFailureBanner | MED |
| 12 | any | Wants to delete workspace | No Danger Zone | §7 DangerSection | MED |
| 13 | agency | Tries to downgrade with active clients | No impact preview | §7 Pre-downgrade modal | MED |
| 14 | owner | Operational dashboards | No owner-only routes | §6 Owner surfaces (deferred) | LOW |

---

## 2. UI Surfaces by Audience

```
end_user      → 1 surface  (sidebar CTA)
client        → 3 surfaces (onboarding, invite redeem, agent creator)
agency        → 5 surfaces (Plan, Clients, Branding, revenue, upgrade prompts)
owner         → 3 surfaces (deferred — D1 console adequate for now)
cross-cutting → 4 surfaces (PaymentBanner, DangerZone, DowngradeModal, UpgradePrompt)
```

13 active surfaces total. 9 are HIGH-priority for the resell loop to function;
the other 4 are MED-priority polish.

---

## 3. End User Surfaces

### 3.1 Sidebar conversion footer (CTA)

**Route:** rendered globally in `Sidebar.tsx` for `viewer === 'end_user'`  
**Component:** `src/components/sidebar/EndUserCTA.tsx` (new)  
**Placement:** above `<Attribution>`, below `<ThemeToggle>`

```
┌─────────────────────┐
│  [ThemeToggle]      │
├─────────────────────┤
│  ✨ Get your own    │ ← bg-primary/10, hover bg-primary/20
│     ONE workspace → │   click → /get-yours
├─────────────────────┤
│  ⚡ Powered by ONE  │
└─────────────────────┘
```

- Collapsed (56px): single icon `Sparkles`, tooltip "Get your own ONE"
- Expanded (240px): icon + 2-line text
- `emitClick('ui:sidebar:get-yours')` on click — substrate measures conversion
- Hidden when `viewer !== 'end_user'`

### 3.2 Skill-use conversion lever (deferred)

When end_user invokes a priced skill 3+ times in a session, surface a one-line
banner at top of chat: *"You're getting value from this — want your own ONE
workspace? →"*. Requires substrate session-tracking that doesn't exist yet.
Defer until x402 split lands.

---

## 4. Client Surfaces

### 4.1 `/u/[slug]/onboarding` — 3-step walkthrough

**Route:** `src/pages/u/[slug]/onboarding.astro` (new)  
**Trigger:** Auto-redirect from `/get-yours` after first passkey, OR manual via Settings  
**Gate:** `owners.onboarded_at IS NULL` (new column, migration 0010)

Single-screen, three sequential cards (no separate routes — just stepper state):

```
┌──── Step 1 of 3 ─────────────────────┐
│  Pick a name for your workspace      │
│  ┌─────────────────────────────────┐ │
│  │ Display name: [_____________]    │ │
│  │ This appears in the sidebar &    │ │
│  │ chat header.                     │ │
│  └─────────────────────────────────┘ │
│                            [Continue→]│
└──────────────────────────────────────┘

Step 2: Pick a brand colour (3 swatches + custom)
Step 3: Write your first agent (form-based, see §4.3)
```

- Final step writes `display_name` to owners + `site.md` to R2 + creates first agent.md
- Sets `owners.onboarded_at = unixepoch()`
- Redirects to `/u/{slug}/chat` with the new agent active
- Skip-able via "Skip for now" link — sets `onboarded_at` to a sentinel so it doesn't loop

### 4.2 Invite redemption flow

**Route:** `/u/[slug]/index.astro` extension — checks `?invite={token}` query  
**Backend:** D1 table `invites`, endpoint `/api/provision?action=redeem-invite`

```sql
-- migration 0011_invites.sql
CREATE TABLE invites (
  token        TEXT PRIMARY KEY,
  parent_slug  TEXT NOT NULL REFERENCES owners(slug) ON DELETE CASCADE,
  child_slug   TEXT NOT NULL,
  email        TEXT,
  expires_at   INTEGER NOT NULL,
  redeemed_at  INTEGER,
  ts           INTEGER DEFAULT (unixepoch())
);
CREATE INDEX idx_invites_parent ON invites(parent_slug);
CREATE INDEX idx_invites_child  ON invites(child_slug);
```

Flow:

```
agency → Settings → Clients → "Invite client" → enters email
  → POST /api/provision?action=create-invite
  → row inserted, link emailed: https://acme.com/u/startup1?invite={token}

client clicks link
  → /u/[startup1]/index.astro reads ?invite=
  → if no session: redirects to /get-yours?return=/u/startup1?invite={token}
  → after passkey: returns here, redeems invite
  → POST /api/provision?action=redeem-invite { token, slug, pubkey }
  → owners row updated with passkey credential, parent_slug locked
  → invite row marked redeemed_at
  → redirect to /u/{startup1}/onboarding
```

UI:
- If invite token present and unredeemed: full-screen welcome card *"You've been invited by ACME — sign in to continue"* + passkey button
- If invite expired: full-screen *"This invite has expired — contact ACME to get a new one"*
- If invite already redeemed by a different actor: *"This invite has already been used"*

### 4.3 Form-based agent creator

**Route:** `src/pages/u/[slug]/agents/new.astro` (new)  
**Component:** `src/components/agents/AgentForm.tsx` (new)

Currently `/u/[slug]/agents` requires markdown frontmatter. Form mode for new
users; markdown editor remains as advanced mode.

```
┌── New agent ───────────────────────────┐
│  Name:           [Scout____________]   │
│  One-liner:      [Helps with research] │
│  System prompt:  ┌──────────────────┐  │
│                  │ You are a helpful │  │
│                  │ research agent... │  │
│                  └──────────────────┘  │
│  Skills:         [+ web-search]        │
│                  [+ summarise]         │
│  Pricing:        ( ) Free              │
│                  ( ) $0.01 per call    │
│                                        │
│  [Cancel]  [Save & open chat →]        │
│                                        │
│  [Edit as markdown →] (advanced)        │
└────────────────────────────────────────┘
```

- Submit → POST `/api/settings?action=site` writing `agent.md` to R2
- "Save & open chat" → redirects to `/u/{slug}/chat` with the agent picker pre-set to the new agent
- "Edit as markdown" → switches to existing markdown editor with form data pre-filled

This is the activation surface. <60s from form open to first agent reply.

---

## 5. Agency Surfaces

All five live inside the new Settings sections framework (roles-todo Wave 1f).

### 5.1 Settings → Plan section

**Component:** `src/components/settings/PlanSection.tsx` (new)  
**Visibility:** all viewers (with own-row content)

```
┌── Plan ─────────────────────────────────────┐
│  Current: Free                              │
│  ──────────────────                         │
│  ✗ Custom domain                            │
│  ✗ Remove "Powered by ONE"                  │
│  ✗ Client workspaces                        │
│                                             │
│  ┌──────────┬──────────┬──────────────────┐│
│  │   Pro    │  Agency  │   Enterprise     ││
│  │  $29/mo  │  $99/mo  │   custom         ││
│  │  ✓ Domain│  ✓ Domain│  ✓ Multi-domain  ││
│  │  ✓ Voice │  ✓ Up to │  ✓ SSO           ││
│  │  ✓ ...   │    20 cl.│  ✓ All branding  ││
│  │  [Choose]│  [Choose]│  [Contact sales] ││
│  └──────────┴──────────┴──────────────────┘│
└─────────────────────────────────────────────┘
```

- "Choose Pro" / "Choose Agency" → POST `/api/billing?action=checkout`
- Backend creates Stripe Checkout Session, returns redirect URL
- After webhook: `owners.plan` updated, user lands back on `/settings#plan` with success banner
- Below the table: link to invoice history (Stripe customer portal redirect)

### 5.2 Settings → Clients section

**Component:** `src/components/settings/ClientManager.tsx` (already in Wave 3b)  
**Visibility:** `viewer === 'agency' || viewer === 'owner'` AND `plan in ('agency','enterprise')`

Three states:

**State A — gated (free/pro):**
```
┌── Clients ──────────────────────────────────┐
│  Hosting clients requires Agency plan.      │
│  Upgrade to host up to 20 client            │
│  workspaces under your brand.               │
│  [Upgrade to Agency →]                      │
└─────────────────────────────────────────────┘
```

**State B — unlocked, empty:**
```
┌── Clients ──────────────────────────────────┐
│  You haven't onboarded any clients yet.     │
│  [+ Invite first client]                    │
└─────────────────────────────────────────────┘
```

**State C — unlocked, populated:**
```
┌── Clients (3 of 20) ────────────────────────┐
│  ┌─────────────┬──────────┬──────────────┐  │
│  │ Startup-1   │ Active   │ [Open] [···] │  │
│  │ Corp-2      │ Active   │ [Open] [···] │  │
│  │ Indie-3     │ Pending  │ [Resend] [×] │  │
│  └─────────────┴──────────┴──────────────┘  │
│  [+ Invite new client]                      │
└─────────────────────────────────────────────┘
```

- "Invite new client" → modal: name, email, optional starter brand
- Submit → creates pending invite (§4.2)
- "Resend" → re-emails invite
- "×" on pending → revokes invite token

### 5.3 Settings → Branding section

**Component:** `src/components/settings/BrandingSettings.tsx` (already in Wave 3a)

Two attribution toggles + locking:

```
┌── Branding ─────────────────────────────────┐
│  Powered by ONE                             │
│  [✓ Show]   [Hide ✗]   [Lock for clients]   │
│  Hiding requires Pro+. Locking requires     │
│  Agency+ — your clients can't unhide it.    │
│                                             │
│  Powered by [your name] (on client workspaces)│
│  [Show ✓]   [✓ Hide]    [Lock for clients]  │
│  Showing requires Agency+. When on, your    │
│  name appears in client sidebars.           │
│                                             │
│  ─────                                      │
│  Logo:    [Upload] [Remove]                 │
│  Favicon: [Upload] [Remove]                 │
└─────────────────────────────────────────────┘
```

### 5.4 Revenue dashboard (early version)

**File:** `src/pages/u/[slug]/payments.astro` (extend)  
**Component:** `src/components/payments/RevenueDashboard.tsx` (new)

Pull forward from Wave 6a. Even before x402 split lands, show subscription
state + zero-state for per-use:

```
┌── Subscription ─────────────────────────────┐
│  Plan: Agency • Next bill 2026-06-08        │
│  $99/mo • [Manage in Stripe →]              │
└─────────────────────────────────────────────┘

┌── Per-use earnings ─────────────────────────┐
│  $0.00 — no priced skills published yet     │
│  [Publish a paid skill →]                   │
└─────────────────────────────────────────────┘

┌── Client billing (agency tier) ─────────────┐
│  Startup-1: $29/mo Pro                      │
│  Corp-2:    $99/mo Agency                   │
│  Indie-3:   $0/mo Free                      │
│  [Manage clients →]                         │
└─────────────────────────────────────────────┘
```

The subscription card is the easy win — just queries Stripe API. The per-use
card is a placeholder until x402 lands.

### 5.5 UpgradePrompt at trigger points

**Component:** `src/components/settings/UpgradePrompt.tsx` (already in Wave 4b — needs trigger list)

Trigger points where the prompt fires inline (replaces the gated UI):

| Trigger | Required plan | Prompt copy |
|---------|--------------|-------------|
| Settings → Domain on free | Pro | "Custom domain requires Pro" |
| Settings → Branding "Hide ONE" | Pro | "Hiding attribution requires Pro" |
| Settings → Chat → Voice toggle | Pro | "Voice input requires Pro" |
| Settings → Clients (empty state) | Agency | "Hosting clients requires Agency" |
| Settings → Domains "Add client domain" | Agency | "Client subdomains require Agency" |
| Settings → Branding "Lock for clients" | Agency | "Locking attribution requires Agency" |
| Skills page → Publish paid skill | Pro | "Paid skills require Pro" |
| Agents page → Voice agent | Pro | "Voice agents require Pro" |

Each prompt is a card, not a toast. It replaces the disabled control inline so
the reason is co-located with the action.

---

## 6. Owner Surfaces (deferred)

`/platform-metrics`, `/workspaces`, `/audit` mentioned in `lifecycles.md §5a`.
For one-staff operation, D1 console + R2 dashboard are adequate. Build when:
- Second staff member joins, OR
- Daily abuse-report volume exceeds 5/day

Current workaround: SQL queries against D1 + R2 viewer in CF dashboard.

---

## 7. Cross-cutting Failure UIs

### 7.1 PaymentFailureBanner

**Component:** `src/components/billing/PaymentFailureBanner.tsx` (new)  
**Placement:** Inside `Layout.astro`, above main content, when `owners.payment_status === 'failed'`

```
┌─────────────────────────────────────────────┐
│ ⚠ Your last payment failed.                 │
│   Update your card by 2026-06-15 or your    │
│   workspace drops to Free tier.             │
│   [Update payment →]    [Dismiss for today] │
└─────────────────────────────────────────────┘
```

- Persistent across all routes until resolved
- Dismiss = session-only; reappears next session
- "Update payment" → Stripe customer portal
- Banner color: bg-destructive/10, border-destructive

### 7.2 DangerSection in Settings

**Component:** `src/components/settings/DangerSection.tsx` (new)  
**Visibility:** owner of workspace (matches slug) only

```
┌── Danger zone ──────────────────────────────┐
│  Delete this workspace permanently.         │
│  [Delete workspace]                         │
│                                             │
│  → modal:                                   │
│    "Type 'acme' to confirm: [______]"       │
│    "This action is irreversible."           │
│    [Cancel]  [Delete acme]                  │
└─────────────────────────────────────────────┘
```

Backend: `DELETE /api/settings?action=workspace`
- Auth: passkey re-challenge (not just session)
- Deletes owners row → CASCADE/SET NULL on domains, invites
- Async: R2 purge of `{slug}/*` objects
- Sub-clients (where parent_slug = slug) inherit NULL parent — they survive

### 7.3 Pre-downgrade impact modal

**Component:** `src/components/billing/DowngradeImpactModal.tsx` (new)  
**Trigger:** PlanSection "Cancel subscription" or "Switch to lower tier"

```
┌── Downgrade impact ─────────────────────────┐
│  Switching from Agency → Pro will:          │
│                                             │
│  • Disable client provisioning              │
│  • 12 existing client workspaces continue,  │
│    but lose your locked branding            │
│  • "Powered by ACME" attribution removed    │
│    from client sidebars                     │
│  • Custom domain remains active             │
│                                             │
│  Effective date: 2026-07-08 (end of cycle)  │
│                                             │
│  [Stay on Agency]  [Confirm downgrade]      │
└─────────────────────────────────────────────┘
```

Modal queries D1 for client count + active locks before rendering. The numbers
are real, computed at modal-open time.

### 7.4 UpgradePrompt (component + wiring)

Spec'd in §5.5. The component already exists in roles-todo Wave 4b — this doc
adds the wiring list (8 trigger points) so the rollout is checklist-driven.

---

## 8. Surface → Route → Component Map

| Surface | Route | Component | Backend |
|---------|-------|-----------|---------|
| Sidebar CTA | (global) | `EndUserCTA.tsx` | — |
| Onboarding | `/u/[slug]/onboarding` | `OnboardingFlow.tsx` | `/api/settings?action=site` |
| Invite redeem | `/u/[slug]?invite=` | (in `index.astro`) | `/api/provision?action=redeem-invite` |
| Agent creator | `/u/[slug]/agents/new` | `AgentForm.tsx` | `/api/settings?action=site` |
| Plan section | `/u/[slug]/settings#plan` | `PlanSection.tsx` | `/api/billing?action=checkout` |
| Clients section | `/u/[slug]/settings#clients` | `ClientManager.tsx` | `/api/provision?action=create-invite` |
| Branding section | `/u/[slug]/settings#branding` | `BrandingSettings.tsx` | `/api/settings?action=site` |
| Revenue dashboard | `/u/[slug]/payments` | `RevenueDashboard.tsx` | `/api/billing?action=summary` |
| UpgradePrompt | inline at gates | `UpgradePrompt.tsx` | (no backend) |
| PaymentBanner | (global) | `PaymentFailureBanner.tsx` | reads `owners.payment_status` |
| DangerSection | `/u/[slug]/settings#danger` | `DangerSection.tsx` | `/api/settings?action=delete` |
| DowngradeModal | inline in PlanSection | `DowngradeImpactModal.tsx` | `/api/billing?action=preview-downgrade` |

12 components. 4 new endpoints (or actions on existing endpoints).

---

## 9. Activation Time Budgets

The lifecycle UX is judged by these:

| Audience | Moment | Budget | Owner |
|----------|--------|--------|-------|
| end_user | Arrive → first chat reply | <2s | chat infra |
| end_user | See "Get yours" CTA | <500ms post-load | sidebar |
| client (invited) | Click invite → onboarded | <90s | invite redeem + onboarding |
| client (independent) | Passkey → first agent reply | <60s | onboarding + agent creator |
| agency | Free signup → custom domain live | <10min | onboarding + Plan + Domain |
| agency | Choose Agency plan → first client provisioned | <5min | Plan + Clients + invite |
| any | Plan upgrade Stripe redirect | <3s | Plan section |
| any | Stripe webhook → UI reflects new plan | <30s | webhook + cache invalidation |

---

## 10. Implementation Sequence (companion to roles-todo)

The new Wave 0 in `roles-todo.md` covers §3, §4, §5.1, §5.5 — the HIGH-priority
gaps. Wave 4 picks up §5.2-§5.4 + §7. Wave 6 brings §5.4 (full revenue) + §7.1.

```
Wave 0  →  surfaces 3.1, 4.1, 4.2, 4.3, 5.1
Wave 1  →  config foundation (no UI surfaces directly)
Wave 3  →  surfaces 5.2, 5.3
Wave 4  →  surfaces 5.5, 7.2, 7.3, 7.4
Wave 6  →  surfaces 5.4 (full), 7.1
deferred →  §6 owner surfaces
```

---

## 11. The Two Truths

1. **A lifecycle is only as smooth as its rough edge.** One missing surface
   blocks the whole arc. The agency tier means nothing if there's no Plan
   section to upgrade through.

2. **Conversion is a substrate signal.** Every CTA in this doc emits via
   `emitClick('ui:<surface>:<action>')` per `.claude/rules/ui.md`. The
   substrate measures which screens convert which audiences. Pheromone
   strengthens the paths that work; the paths that don't fade. UI design
   decisions are validated by the same loop that validates agent decisions.

*Twelve components. Five lifecycle moments per audience. Zero friction at the
moments that matter most.*
