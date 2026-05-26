# lifecycles.md — Audience Journeys, Arrival to Reseller

ONE has four parallel lifecycles, one substrate. This doc walks each audience
through the full arc — arrival, signup, activation, payment, expansion,
reselling, off-boarding. Roles answer *what they can do* (`roles.md`); groups
answer *how they nest* (`groups.md`); lifecycles answer *what they go through*.

> **Note on terminology:** the root `/lifecycle.md` is the on-chain agent state
> machine (Conceived → Live → Retired). This doc — `web/lifecycles.md`, plural —
> is about the humans using the website. Different layer, same word.

---

## 1. The Four Audiences, At a Glance

| Audience | Trigger | Activation | Money | Expansion path |
|----------|---------|-----------|-------|----------------|
| **end_user** | URL shared by friend, search result | First chat reply | Pays per-use (x402) | → client → agency |
| **client** | Invited by agency or self-signs up | Configures own brand inside agency cascade | Subscription to agency (separate) + earns from own end users | → agency (own platform) |
| **agency** | Found ONE through marketplace, friend, search | First custom domain live | Subscription ($29 / $99) + revenue share from clients | → enterprise (multi-domain) |
| **owner** | Hired/founded ONE | Platform metrics dashboard live | Salary + platform revenue | (operates the system) |

Lifecycles are **additive** — an `end_user` can become a `client` can become
an `agency` can become an `enterprise` customer, all on the same wallet and
identity. The viewer tier in the UI updates as their role changes; their
substrate `actor` row stays the same.

---

## 2. End User Lifecycle — anonymous to engaged

The simplest path. No signup required to get value. Most visitors never leave
this tier — and that's fine.

```
arrives → orients → asks first → gets value → maybe pays → maybe returns
   │         │          │           │            │             │
[someone   [chat       [warm        [streamed    [x402         [bookmarks
 shared    visible    starter      reply or     prompt for    or ignores
 the URL]  + name]    chip or      card]        priced skill] forever]
                      typed Q]
```

### 2a. Arrival

Three entry shapes, all land at chat:

| Shape | URL | What renders |
|-------|-----|-------------|
| Platform subdomain | `alice.one.ie` | Alice's workspace, chat as front door |
| Agency custom domain | `acme.com` | ACME workspace, chat |
| Sub-workspace | `client.acme.com` | Client workspace under ACME's cascade |
| Direct profile link | `one.ie/u/alice` | Same as first row, canonical URL |

`/u/[slug]/index.astro` reads viewer; `end_user` (no session) sees chat directly,
not a file listing. Workspace name comes from `resolveIdentity(slug, site).name`.

### 2b. First impression (<5s)

What hits the screen:
- Workspace logo + name (from `site.md`)
- Welcome message (from `site.chat.welcome` if set, else generic)
- Up to 5 starter chips (from `site.chat.starters[lifecycle:fresh][viewer:end_user]`)
- Input box, focused
- Sidebar collapsed to 56px (mini mode is the workspace default)

What is *not* there:
- "Sign up" CTA — there isn't one. Auth happens later, on demand
- ONE branding (if workspace is on Pro+ and hid attribution)
- Empty states. Workspace owner pre-seeded the chat starter chips

### 2c. Activation — first reply

User picks a chip or types. ai-sdk streams the response. The substrate emits
`ui:chat:send`, `chat:message:received` signals; pheromone deposits on the
starter chip's path. If reply was useful (timeout reached without `warn`), the
chip strengthens. Chips a workspace owner sees in `/design` reflect what's
working for actual users.

**Activation moment:** first streamed reply renders. No auth, no payment, no
account creation. This is the bar the rest of the lifecycle is measured against.

### 2d. Optional: pay for a priced skill

Some skills carry a `price` field (`groups.md §8`). When invoked:

```
user invokes priced skill
  → x402 challenge issued (HTTP 402, payment headers)
  → user's wallet (ONE provides minimal wallet UI for non-auth users)
  → on success: skill runs, payment splits 85/10/5
```

The end user never thinks "I'm doing crypto." It's "click → pay 0.01 → got
result." Per-use payments are the conversion lever toward `client` (creating
their own workspace to host their own priced skills).

### 2e. Optional: become a client

If the end user wants their own version of the experience — their own agents,
their own brand — they hit:

```
end_user → /u/[slug]/settings (gated: redirects)
        → /signup (or hits agency's "new client workspace" CTA)
        → passkey ceremony (one Touch ID)
        → owners row created with parent_slug = current workspace
        → seeded site.md inheriting agency tokens
        → redirected to their own /u/{newSlug}
        → now a `client` — sees client-tier nav
```

Conversion rate matters here. The agency's plan determines what the new client
gets: free if agency provisioned, or pay-as-you-go if independent.

### 2f. Off-boarding

End users churn silently — they close the tab. No off-boarding flow. The
substrate fades their session pheromone over 5 minutes (L3 fade loop, root
engine.md). Returning to the same URL feels fresh, not stateful. That's a feature.

---

## 3. Client Lifecycle — invited, branded, scoped

A client is an authenticated visitor or sub-workspace tenant. Two shapes:
**inherited client** (provisioned by an agency) and **independent client**
(signed up directly, no parent).

### 3a. Inherited-client arrival (the agency path)

```
agency creates the client workspace
  → /u/[agencySlug]/settings#clients → "New client"
  → POST /api/provision?action=client-workspace
  → owners row { slug: agency-startup1, parent_slug: agency, plan: free }
  → R2: {agency-startup1}/site.md seeded with agency tokens
  → invite link emailed to client contact

client clicks invite
  → /u/[agency-startup1]?invite={token}
  → passkey ceremony (or Google plugin per Better Auth)
  → invite token validated, owners.pubkey updated
  → redirected to /u/[agency-startup1]/chat
  → now an `agency` in their OWN workspace, but `client` when visiting acme.com
```

This is the **white-label commercial path**. The client experiences the
agency's platform as their own — their colours (within agency locks), their
agents, their domain (`startup1.acme.com` after CNAME).

### 3b. Independent-client arrival (the platform path)

```
visitor signs up at /signup
  → passkey ceremony
  → owners row { slug: alice, parent_slug: NULL, plan: free }
  → /u/alice/onboarding (3-step: pick name, pick brand, write first agent)
  → /u/alice/chat
```

Independent clients are self-funded. They pay ONE directly via Stripe to upgrade
plans. They have no parent agency in the cascade, so they only see Layer 0
(platform) and Layer 1 (their own site.md).

### 3c. Activation — first published agent

For both shapes, the client's activation moment is **first published agent
reachable by chat**:

1. Open `/u/[slug]/agents` → "New agent"
2. Markdown editor with frontmatter (name, system prompt, skills)
3. Save → agent.md written to R2 at `{slug}/agents/{name}.md`
4. Agent appears in the chat agent picker
5. Send a message → agent responds

Time-to-activation budget: **<60s** from passkey ceremony to first agent reply.

### 3d. Daily use

Clients live in `/chat`, occasional dips into `/agents` and `/settings`.
They do **not** see `/skills` or `/payments` (gated to agency+) per
`roles.md §7` surface matrix. Voice and attachments depend on agency lock state.

### 3e. Custom domain (independent clients only)

```
client wants client.com (no agency parent)
  → /u/[slug]/settings#domain
  → POST /api/domain?action=register
  → domains row, parent_slug = NULL
  → CNAME target = one.ie (not {agency}.one.ie)
  → DNS, verify, live
```

Inherited clients inherit the agency's domain shape (`startup1.acme.com`); they
don't typically add their own custom domain unless they're upgrading their
relationship.

### 3f. Expansion to agency

The conversion moment: a `client` realises they want to host their own clients.

```
client → Settings → Plan → "Upgrade to Agency ($99/mo)"
  → Stripe checkout
  → owners.plan = 'agency'
  → Settings now shows "Clients" section
  → /api/provision?action=client-workspace now succeeds
  → they create their first sub-client → cascade applies their brand
```

The substrate doesn't change — same `actor` row, same wallet. Only the `plan`
field flips, and the gates open. This keeps the "growing into ONE" path
frictionless.

### 3g. Off-boarding

```
client deletes workspace
  → Settings → Danger zone → "Delete workspace"
  → Confirmation (typed slug match)
  → owners row deleted (CASCADE: domains.parent_slug = NULL via ON DELETE SET NULL)
  → R2 objects under {slug}/ purged async
  → redirected to one.ie homepage
```

Sub-clients of an agency that off-boards: their `parent_slug` becomes NULL
(via `ON DELETE SET NULL` in migration 0008). They don't lose their workspace,
but they lose the agency's cascade — they revert to platform defaults until
they pick a new parent or set their own brand.

---

## 4. Agency Lifecycle — creator, white-labeler, reseller

The agency is the lifecycle ONE optimises hardest for. They're the multiplier:
one agency brings N clients brings M end users.

### 4a. Discovery

Three common discovery shapes:

```
1. Search "open source AI agents" / "white-label chatgpt"  → one.ie/agents
2. Friend referral / Twitter post                          → one.ie/u/{friend}
3. CLI / SDK first ("npx oneie")                           → cli/dev → /chat
```

The agency lands either on the public marketplace or a friend's white-labelled
workspace. The "powered by ONE" attribution in the friend's footer is
load-bearing here — it's the discovery vector.

### 4b. Free trial

Agency signs up at `/signup`, gets `{slug}.one.ie`, free plan:

| Free plan grants | Free plan limits |
|------------------|-----------------|
| Subdomain `{slug}.one.ie` | "Powered by ONE" footer (cannot remove) |
| 1 agent, 5 skills | No client workspaces |
| Chat, agents, basic settings | No custom domain |
| `/design` token editor | No voice input |

The free tier is the trial. No credit card. Time-to-value is the same as a
paying client: <60s to first agent reply.

### 4c. First commercial moment — custom domain

The agency's first paid threshold is the custom domain. Cost: $29/mo (Pro).

```
agency → Settings → Plan → "Upgrade to Pro"
  → Stripe checkout
  → owners.plan = 'pro'
  → Settings → Domain unlocks
  → POST /api/domain?action=register, host = acme.com
  → CNAME acme.com → acme.one.ie (their own subdomain)
  → TXT _one-verify.acme.com → verify_token
  → DNS propagates (up to 24h, often <5min)
  → /api/domain?action=verify → verified=1
  → acme.com now serves their workspace
  → "Powered by ONE" can be hidden (Pro feature)
```

This is a major activation. Most agencies upgrade within a week of starting,
because the platform subdomain feels like a demo, the custom domain feels like
a product.

### 4d. White-label expansion — Agency plan

The agency wants to host clients. Cost: $99/mo (Agency tier, up to 20 clients).

```
agency → Settings → Plan → "Upgrade to Agency"
  → Stripe checkout
  → owners.plan = 'agency'
  → Settings → Clients unlocks
  → "Powered by ACME" attribution slot opens for client workspaces
```

Now the resell loop activates:

```
agency provisions client → POST /api/provision?action=client-workspace
                       → child workspace seeded with agency tokens
                       → invite sent to client contact
                       → client onboards → uses platform
                       → client's end_users hit acme.com or client.acme.com
                       → they see client's brand + "Powered by ACME"
                       → end_user pays for priced skill
                       → 85% to client, 10% to ONE, 5% protocol
                       → agency earns nothing per-use directly
                       → agency earns indirectly via subscription fee from client
                         (if agency invoices clients separately, off-platform)
```

The agency's incentive is clean: they want clients to succeed (so subscription
revenue continues). They don't skim per-use revenue, which keeps the creator
economy honest.

### 4e. Daily operation

An active agency uses:
- `/u/{slug}/agents` — agent CRUD, refining personas
- `/u/{slug}/skills` — pricing, marketplace listings
- `/u/{slug}/settings#clients` — onboarding new clients, monitoring usage
- `/u/{slug}/payments` — revenue dashboard (own + per-client breakdown)

Substrate-level: their workspace's agents accumulate pheromone. Highways harden
into knowledge (root engine.md L6). The agent personas evolve every 10min if
performing badly (L5 evolution loop).

### 4f. Enterprise expansion

The threshold to Enterprise is when an agency wants:
- Multiple top-level domains (not just sub-workspaces of one)
- SSO for client teams
- All attribution removed (no "Powered by ONE", no "Powered by ACME" — just clean)
- SLA + dedicated support

This is custom-priced, sales-led. The plan field becomes `'enterprise'`. No
Stripe checkout — invoiced.

### 4g. Off-boarding

Agency churn is the most expensive churn. The off-boarding flow must protect
their clients:

```
agency → Settings → Danger zone → "Cancel subscription"
  → grace period (30 days): plan stays at agency, attribution stays as configured
  → after grace: plan downgrades to free
  → "Powered by ONE" reappears on agency workspace
  → clients of the agency: parent_slug stays set, but client workspaces also
    revert to free unless they pay independently
  → custom domains: continue working until DNS expires (CNAME still valid)
```

The agency's clients shouldn't suddenly lose their workspace — that would
poison the network. They drop to a graceful free tier and can opt to pay
themselves to continue.

---

## 5. Owner Lifecycle — Tony / platform admin

The owner lifecycle is operational, not commercial. One person (or a small
team) at a time.

### 5a. Daily operations

```
/u/tony (with staffRole=true)
  → sidebar shows owner-only items: /platform-metrics, /workspaces, /audit
  → /platform-metrics: aggregate revenue, active workspaces, daily signups
  → /workspaces: list all owners, filter by plan, drill in
  → /audit: signal log, abuse reports, manual interventions
```

Owner-only items don't currently exist as routes (Wave 5+ in roles-todo). For
now, the owner sees the same surfaces as agency, just filtered to all
workspaces instead of own.

### 5b. Platform configuration

The owner sets Layer 0 defaults. Currently hardcoded in `Layout.astro` CSS
tokens. Future: world-level config in a dedicated R2 path (`world/site.md`),
read by `resolveConfig()` as Layer 0 (or Layer 1 in the 5-layer cascade per
groups.md §4).

### 5c. Marketplace curation

Featured agents, featured skills, featured workspaces. These appear on the
public `/agents`, `/skills`, `/workspaces` pages (which all use the world-level
catalog, not workspace-scoped). Curation is `staffRole`-only.

### 5d. Incident response

When an agency's workspace gets reported (abuse, spam, broken):

```
owner → /audit → reviews signals
     → /workspaces/[slug] → freeze (sets owners.frozen=1)
     → frozen workspaces 503 on all routes except /settings
     → emails workspace contact
     → 30-day appeal window
     → after 30 days: delete or unfreeze
```

This flow is also not yet implemented. It belongs in a future wave alongside
plan gates.

### 5e. Off-boarding

Owners don't churn — they're staff. If staff turnover happens, `staffRole`
moves to a new actor. The substrate doesn't care which human is the owner;
it cares which actors have the role.

---

## 6. Cross-Lifecycle Conversions

The valuable transitions between tiers:

```
end_user → client          (signs up, gets own workspace)
client → agency             (upgrades plan, can host clients)
agency → enterprise         (sales-led, custom contract)

agency → client of agency   (rarely — an agency closes shop, becomes a client elsewhere)
client → end_user           (cancels workspace, still uses other workspaces as visitor)
```

Every transition is a single API call + plan change + UI re-gate. No data
migration. No different account. The same `actor` row remains; only role,
plan, and parent_slug change.

### Conversion levers

| From | To | Lever | Trigger |
|------|----|----|---------|
| end_user | client | "Create your own [thing] for free" | Used a priced skill 3+ times |
| client | agency | "Host your own clients" | Workspace has 100+ end_user sessions/mo |
| agency | enterprise | "Need multi-domain or SSO?" | 15+ active clients (close to Agency cap) |

These thresholds aren't enforced today — they're product hypotheses. The
substrate measures usage (signals), the marketing layer applies the lever.

---

## 7. Money Flow Across Lifecycles

Two parallel revenue streams, never crossing:

### 7a. Subscription (Stripe)

```
end_user           → free
client (indep.)    → free | $29 Pro | $99 Agency | enterprise
client (inherited) → billed by parent agency, off-platform
agency             → $29 Pro | $99 Agency | enterprise
owner              → (staff, no subscription)
```

Stripe handles checkout, recurring billing, invoices, refunds, dunning.
`owners.plan` is the cached state synced from Stripe webhooks.

### 7b. Per-use (x402)

```
end_user invokes priced skill (1 USDC)
  ├── creator workspace (whoever owns the skill): 850 mUSDC (85%)
  ├── platform (ONE): 100 mUSDC (10%)
  └── protocol (network fee): 50 mUSDC (5%)
```

Splits flow on-chain via the x402 protocol (`x402.md` in root). The creator
workspace's agency parent doesn't earn directly from per-use; they earn via
their subscription fee from the client.

### 7c. The unified dashboard

Both streams visible in `/u/{slug}/payments`:

```
[Subscription]
  Plan: Agency • Next billing: 2026-06-08 • $99/mo
  [View invoices →]

[Per-use earnings]
  Last 30 days: 1,247 USDC across 3,419 skill invocations
  Top skill: voice-clone (847 USDC) • Top agent: Scout (291 USDC)
  [Withdraw 1,247 USDC →]

[Client billing] (agency tier only)
  Startup-1: 12 active end_users • $29 plan
  Corp-2:    87 active end_users • $99 plan
  [Manage →]
```

---

## 8. Critical UI Transitions

Each lifecycle has 3-5 moments that must be polished. Drop-off here is permanent.

| Transition | Audience | Surface | Budget |
|-----------|----------|---------|--------|
| First chat reply | all | `/chat` | <2s to first token |
| Passkey ceremony | end_user → client | `/signup` | one Touch ID, no extra fields |
| Custom domain verify | client → agency | `/settings#domain` | clear DNS instructions, single Verify button |
| Plan upgrade | client → agency | `/settings#plan` | one Stripe redirect, no friction |
| Client provisioning | agency | `/settings#clients` | <30s from "New client" to invite link |
| White-label live | client | `client.acme.com` | first hit shows full brand, no flash of unstyled |
| First payout | agency | `/payments` | "Withdraw" button always visible when balance > 0 |

---

## 9. Failure Paths

The lifecycle is only as good as its sad paths.

### 9a. Auth fails

```
passkey not supported on device → fallback to email magic link (Better Auth)
passkey lost → recovery via paper backup (passkeys.md break-glass)
              → if no backup: workspace remains inaccessible (intentional —
                non-custodial)
```

### 9b. Domain verification times out

```
TXT record not propagated within 24h
  → email reminder
  → after 7 days: domain row marked stale
  → user can retry verify or delete + re-add
  → no auto-deletion (DNS sometimes takes weeks for unusual providers)
```

### 9c. Payment fails

```
Stripe charge declined → grace 7 days, then plan → free
                       → email + in-app banner
                       → workspace stays live, just degraded
                       → custom domain: keeps working until DNS expires
                         (URL doesn't break, just "Powered by ONE" reappears)

x402 challenge fails → skill not invoked, error returned to caller
                     → no retry loop (caller decides)
```

### 9d. Plan downgrade with attached resources

```
agency on Agency tier (12 clients) → downgrades to Pro (allows 0 clients)
  → 30-day grace
  → after grace: clients are NOT deleted
  → they become "orphaned" — parent_slug stays set, but agency's locks no longer apply
  → clients revert to free tier on their own subscriptions
  → owners get a one-time email explaining the change
```

This protects clients from agency churn. The cost to the platform is small;
the cost of breaking a client's workspace because their agency forgot to pay
is huge.

### 9e. Workspace deletion with active end users

```
client deletes workspace mid-session
  → all open chat sessions get a "workspace closed" error
  → x402 challenges in flight: refunded if uncaptured
  → R2 objects under {slug}/ purged async
  → DNS records persist until owner removes them
  → /u/{slug} returns 404
```

---

## 10. Lifecycle ↔ Substrate Mapping

The 6 ontology dimensions surface in lifecycles:

| Dimension | Where it appears |
|-----------|------------------|
| **Groups** | Workspace creation, client provisioning, team formation |
| **Actors** | Passkey ceremony creates an actor; plan changes update actor metadata |
| **Things** | Agents/skills/tools published; the thing inventory is the workspace's product |
| **Paths** | Repeated chat starters strengthen; preferred agents harden into highways |
| **Events** | Every transition (signup, upgrade, payment) emits a substrate signal |
| **Learning** | Hypotheses about which audience converts at which step (L6 loop) |

Every lifecycle moment is also a substrate signal:

```
ui:signup:start          → ui:signup:passkey-prompt → ui:signup:complete
ui:plan:upgrade-clicked  → ui:plan:stripe-redirect  → ui:plan:webhook-success
ui:domain:register       → ui:domain:verify-pending → ui:domain:live
ui:client:provision      → ui:client:invite-sent    → ui:client:onboarded
```

These are observable. The substrate measures conversion at each step. Friction
shows up as warn() calls; smooth paths show up as mark() chains. The
implementation matches: every onClick emits via `emitClick('ui:<surface>:<action>')`
per `.claude/rules/ui.md`.

---

## 11. Implementation Map

Each lifecycle moment maps to code or todo items:

| Moment | Status | File / Todo |
|--------|--------|-------------|
| End user arrival → chat | ✓ | `src/pages/u/[slug]/index.astro` (role-aware redirect) |
| Passkey ceremony | ✓ | `src/lib/passkey.ts`, `/signup` |
| Custom domain registration | ✓ | `src/pages/api/domain.ts` |
| Sub-workspace CNAME | ✓ | parent_slug column, migration 0008 |
| Settings sections framework | TODO | roles-todo.md Wave 1f |
| Client provisioning | TODO | roles-todo.md Wave 3b |
| Plan field on owners | TODO | roles-todo.md Wave 1d (migration 0009) |
| Plan gates at API | TODO | roles-todo.md Wave 4a (`src/lib/plan.ts`) |
| Stripe subscription webhook | TODO | not yet listed (Wave 6 area) |
| x402 split | TODO | roles-todo.md Wave 6b |
| Revenue dashboard | TODO | roles-todo.md Wave 6a |
| Workspace freeze (owner) | TODO | not yet listed (post-MVP) |
| Workspace deletion + cleanup | TODO | not yet listed |

---

## 12. The One Mental Model

```
   end_user                client                  agency               owner
       │                     │                       │                    │
   [arrives]            [signs up]              [upgrades to Pro]    [staff role]
       │                     │                       │                    │
   [first reply]        [first agent]           [custom domain]      [oversees all]
       │                     │                       │                    │
   [maybe pays]         [maybe pays]            [upgrades to Agency]  [curates]
       │                     │                       │                    │
       │                  [reaches limits]        [hosts clients]      [intervenes
       │                     │                       │                    on abuse]
       └──→ [becomes client] └──→ [becomes agency]   └──→ [becomes
                                                          enterprise]

Money flow:
  end_user pays per-use → 85% creator / 10% ONE / 5% protocol
  client/agency pays subscription → ONE, monthly, Stripe

Substrate flow:
  every transition is a signal
  every successful conversion deposits pheromone
  paths that work harden into highways
  the platform learns which prompts convert which audiences
```

Four lifecycles. One substrate. Money flows in two directions, learning in
one. End users get value first, signup later, payment optional. Agencies get
revenue from clients, branding from customisation, leverage from the
white-label cascade. Everyone has a clear, low-friction path to the next tier
when they want it — and an equally clear path to stay where they are if they
don't.

*That's the lifecycle.*
