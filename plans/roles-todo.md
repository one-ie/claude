# roles-todo.md — actionable, parallel-claim TODO

Extracted from `roles.md`, `groups.md`, `lifecycles-ui.md`, `authentication.md`.
**Each item is its own atomic /do cycle.** No item shares waves with another.
A swarm of agents can claim every Tier-1 item simultaneously — only true code
or schema dependencies block; nothing else.

**Mode:** mixed · **Lifecycle:** construction · **Deterministic exit:** all open `[ ]` boxes below flip to `[x]` and `bun run verify` is green on each item's touched files.

---

## How to run with `/do`

- `/do roles-todo.md --tier 1` — claim every unblocked Tier-1 item, fan out N agents in one message (one agent per item, model per the `model:` tag).
- `/do roles-todo.md --item 0f` — drive a single item end-to-end (its own W1→W4 sandwich).
- `/do roles-todo.md --auto` — repeat: claim unblocked items → spawn → close → re-evaluate tiers as upstream items land.
- Each item closes with `/close --item <id>` so the substrate marks pheromone per item, not per shared wave.

**Model routing per item** (override the global wave-model map):

| Item kind | Model | Why |
|---|---|---|
| Pure SQL migrations, wrangler.toml stanzas, simple string-replace passes | `haiku` | Mechanical, low-variance |
| Components, API extensions, single-feature UI, focused edits | `sonnet` | Default for code synthesis |
| Cascade logic, plan-gate centralization, downgrade-impact compute, multi-file architecture decisions | `opus` | Cross-cutting reasoning |

---

## Status board (every item, single source of truth)

### Done ✓

- [x] **viewer** — 4-tier viewer type (`owner/agency/client/end_user`) in `src/lib/viewer.ts` + `src/env.d.ts`
- [x] **menu** — Menu filtering per tier in `src/lib/menu.ts`
- [x] **sidebar** — Hover sidebar (56px collapsed, 240px expanded, 150ms) in `src/components/sidebar/Sidebar.tsx`
- [x] **pin** — Pin button (Pin/PinOff icons) replacing toggle in sidebar
- [x] **identity** — `resolveIdentity()` helper in `src/lib/slug.ts`
- [x] **landing** — `/u/[slug]/index.astro` chat-or-workspace router by tier
- [x] **attribution** — `Attribution` component in sidebar footer
- [x] **parent_slug** — `parent_slug` column in `domains` + `owners` (`migrations/0008_workspace_hierarchy.sql`)
- [x] **domain-cname** — `DomainSettings.tsx` shows CNAME target `{parentSlug}.one.ie`
- [x] **domain-api** — `/api/domain.ts` accepts/stores `parent_slug`, returns `cnameTarget`
- [x] **domain-settings** — `settings.astro` passes `parentSlug` + `currentDomain`

### Open

#### Tier 1 — independent (claim freely; up to 21 agents in parallel)

Each item carries its own four-wave checklist (`w1 recon · w2 decide · w3 edit · w4 verify`). Items already shipped show all four boxes checked.

- [x] **0f** — rpFromRequest registrable-parent fix · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **0a** — /u/[slug]/onboarding 3-step walkthrough · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **0c** — Sidebar end_user conversion CTA · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **0e** — Form-based agent creator (`/agents/new`) · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **1a** — `WorkspaceConfig.attribution` in `site.md` + `parseSite()` · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **1c** — Locked-properties parser + merge guard in `parseSite()` · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **1d** — `owners.plan` column migration · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **1f** — Settings page section framework (`SettingsView.tsx` refactor) · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H1** — Session cookie issue/read + middleware population · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H4** — Replay set → KV · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H5** — `owners_keys.counter` migration + verify wiring · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **H6** — Email delivery (`src/lib/email.ts`, Resend) · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H7** — Rate-limit rules in `wrangler.toml` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **H9** — ToS acceptance flow on `/get-yours` · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H10** — 404/500 pages + ErrorBoundary · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H11** — D1 Time-Travel enable + recovery runbook · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **H12** — Playwright e2e resell-loop · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **5a** — OG metadata on `/u/[slug]` · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **5b** — `/u/[slug]/workspace.astro` (extracted file listing) · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **5c** — Replace `@{slug}` → `identity.name` across views · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **5d** — Group identity card endpoint extension · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **5e** — `/api/logo/[slug]` placeholder SVG fallback · `sonnet` · w1[x] w2[x] w3[x] w4[x]

#### Tier 2 — one upstream

- [x] **0g** — `owners_keys` multi-RP migration · deps: 0f · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **0d** — Plan section + Stripe checkout · deps: 1f · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **1b** — `resolveConfig()` 5-layer cascade · deps: 1c · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **H2** — Auth gate on `/api/settings` form POST · deps: H1 · `sonnet` · w1[x] w2[x] w3[x] w4[x]

#### Tier 3 — two upstream

- [x] **0h** — `/api/link` device-link endpoint · deps: 0g · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H3** — Multi-credential verify path · deps: 0g · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **0b** — Invite-link table + redeem flow · deps: 0g, H6 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **H8** — Stripe webhook signature verify · deps: 0d · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **1e** — `/api/settings ?action=site` · deps: 1b · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **2a** — Per-client override file (Layer 3 in resolveConfig) · deps: 1b · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **2b** — Per-team config file (Layer 4 in resolveConfig) · deps: 1b · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **6c** — PaymentFailureBanner · deps: 0d · `haiku` · w1[x] w2[x] w3[x] w4[x]
- [x] **4e** — DowngradeImpactModal · deps: 0d · `sonnet` · w1[x] w2[x] w3[x] w4[x]

#### Tier 4 — settings UIs (depend on the section framework + write API)

- [x] **3a** — Branding settings (attribution toggles) · deps: 1e, 1f · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **3b** — Client manager · deps: 1e, 1f · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **3c** — Team manager · deps: 1e, 1f, 2b · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **3d** — Nav override UI · deps: 1e, 1f · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **3e** — Chat config UI · deps: 1e, 1f · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **3f** — Sidebar mode (mini/full/hidden) · deps: 1e, 1f · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **3g** — Mobile feature gates · deps: 1b · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **2c** — In-page surface guards · deps: 2a, 2b · `sonnet` · w1[x] w2[x] w3[x] w4[x]

#### Tier 5 — plan gates + revenue (depend on plan-aware settings)

- [x] **4a** — `src/lib/plan.ts` gates + API enforcement · deps: 1d, 1e, 3b · `opus` · w1[x] w2[x] w3[x] w4[x]
- [x] **4b** — `UpgradePrompt` component (8 trigger points) · deps: 4a · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **4c** — Agency subdomain provisioning UI · deps: 4a, 3b · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **4d** — DangerSection (delete workspace) · deps: 4a, H11 · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **6a** — Revenue dashboard · deps: 4a, 0d · `sonnet` · w1[x] w2[x] w3[x] w4[x]
- [x] **6b** — x402 revenue split · deps: 4a · `sonnet` · w1[x] w2[x] w3[x] w4[x]

---

## Dependency graph (real edges only)

```
                                Tier 1 — fully independent
                                ─────────────────────────
        ┌──── auth + lifecycle ────┐    ┌──── config + plan ────┐    ┌──── hardening ────┐    ┌── identity / polish ──┐
        │ 0f  rpFromRequest        │    │ 1a  attribution+parse │    │ H1 session cookie │    │ 5a OG metadata        │
        │ 0a  onboarding 3-step    │    │ 1c  locks parser      │    │ H4 replay→KV      │    │ 5b workspace.astro    │
        │ 0c  end_user CTA         │    │ 1d  owners.plan mig   │    │ H5 counter mig    │    │ 5c name replace       │
        │ 0e  agent form           │    │ 1f  settings sections │    │ H6 email          │    │ 5d group card         │
        └────────────┬─────────────┘    └────────────┬──────────┘    │ H7 rate limits    │    │ 5e logo fallback      │
                     │                               │               │ H9 ToS            │    │ H10 error pages       │
                     │                               │               │ H11 D1 PITR       │    │ H12 e2e resell loop   │
                     ▼                               ▼               └────────┬──────────┘    └───────────────────────┘
                                              Tier 2                          │
                                              ──────                          ▼
        ┌─ 0f ─►  0g  multi-RP mig            ┌─ 1c ─►  1b  resolveConfig    ┌─ H1 ─►  H2  /api/settings auth gate
        │                                     │                               │
        └─ 1f ─►  0d  Stripe + Plan UI        │
                                              │
                                              ▼
                                        Tier 3
                                        ──────
        ┌─ 0g ─►  0h  device-link              ┌─ 1b ─►  1e  /api/settings ?action=site
        ├─ 0g ─►  H3  multi-credential verify  ├─ 1b ─►  2a  client override layer
        ├─ 0g ─►                               └─ 1b ─►  2b  team config layer
        │  H6 ─►  0b  invites
        ├─ 0d ─►  H8  webhook sig
        ├─ 0d ─►  6c  PaymentFailureBanner
        └─ 0d ─►  4e  DowngradeImpactModal
                                              ▼
                                        Tier 4 — settings UIs
                                        ─────────────────────
        1e + 1f ─►  3a Branding · 3b Clients · 3d Nav · 3e Chat · 3f Sidebar mode
        1e + 1f + 2b ─►  3c Teams
        1b ─►  3g Mobile gates
        2a + 2b ─►  2c In-page guards
                                              ▼
                                        Tier 5 — plan gates + revenue
                                        ────────────────────────────
        1d + 1e + 3b ─►  4a  src/lib/plan.ts (gates)
                            ├─►  4b  UpgradePrompt
                            ├─►  4c  Agency subdomain UI    (also needs 3b)
                            ├─►  4d  DangerSection           (also needs H11)
                            ├─►  6a  Revenue dashboard       (also needs 0d)
                            └─►  6b  x402 split
```

**Critical paths**

- White-label MVP: `H1 · H4 · H6` ⊕ `0f → 0g → {H3, 0h}` ⊕ `1d · 1f` ⊕ `1c → 1b → 1e` ⊕ `3a` ⊕ `4a → 4b`.
- Resell-loop MVP: above ⊕ `H6 + 0g → 0b` ⊕ `3b` ⊕ `4a → 4c`.
- Production gate (must be in before public launch): all of `H1 H2 H3 H4 H5 H6 H7 H8 H9 H10 H11 H12`. `H8` lands inside `0d`. `H11` must precede `4d`.

---

## Item details

Each item below is independently shippable. Spec is unchanged from prior version — only the metadata header is new. Run `/do roles-todo.md --item <id>` to drive one end to end.

### 0f — rpFromRequest registrable-parent fix
`model: sonnet · deps: none · files: src/lib/passkey.ts · refs: authentication.md §9`

Today's full-host RP breaks every multi-domain lifecycle.

```ts
const rpId = host === 'one.ie' || host.endsWith('.one.ie')
  ? 'one.ie'
  : host.replace(/^www\./, '')
```

Existing credentials registered against subdomains keep working (RP is bound at registration). New registrations consolidate to `one.ie`. No data migration here — see 0g for schema.

---

### 0a — /u/[slug]/onboarding 3-step walkthrough
`model: sonnet · deps: none · files: src/pages/u/[slug]/onboarding.astro (new), src/components/onboarding/OnboardingFlow.tsx (new), migrations/0010_onboarded_at.sql (new) · refs: lifecycles-ui.md §4.1`

```sql
ALTER TABLE owners ADD COLUMN onboarded_at INTEGER;
```

- 3-step stepper, single page, internal state (not separate routes)
  - Step 1: display name · Step 2: brand colour (3 swatches + custom hex) · Step 3: first agent (form-based, embeds 0e via prop)
- Final submit: writes `display_name`, `site.md` tokens, first `agent.md` to R2; sets `owners.onboarded_at = unixepoch()`
- Skip → sentinel value, doesn't loop
- Auto-redirect from `/get-yours` post-passkey when `onboarded_at IS NULL`
- `emitClick('ui:onboarding:step{N}-complete')` per step

---

### 0c — Sidebar end_user conversion CTA
`model: haiku · deps: none · files: src/components/sidebar/EndUserCTA.tsx (new), src/components/sidebar/Sidebar.tsx (mount above <Attribution>) · refs: lifecycles-ui.md §3.1`

- Visible only when `viewer === 'end_user'`
- Collapsed (56px): `Sparkles` icon, tooltip "Get your own ONE"
- Expanded (240px): icon + "Get your own ONE workspace →"
- Style: `bg-primary/10`, hover `bg-primary/20`, primary text colour
- Click: `emitClick('ui:sidebar:get-yours')` then `window.location = '/get-yours'`

---

### 0e — Form-based agent creator
`model: sonnet · deps: none · files: src/pages/u/[slug]/agents/new.astro (new), src/components/agents/AgentForm.tsx (new) · refs: lifecycles-ui.md §4.3`

- Fields: name, one-liner, system prompt textarea, skill picker (multiselect from workspace skills), pricing (free / per-call cents)
- Submit: serialise to markdown frontmatter + body, POST to `/api/settings ?action=site` (writes `agent.md` to R2)
- "Save & open chat" → `/u/{slug}/chat?agent={name}`
- "Edit as markdown" → existing markdown editor at `/u/[slug]/agents` with form data pre-filled
- Embeddable into 0a step 3 via prop, no redirect

---

### 1a — `WorkspaceConfig.attribution` in `site.md` + `parseSite()`
`model: sonnet · deps: none · files: src/lib/site.ts · refs: groups.md §5, roles.md §10`

- Add `attribution?: { one?: 'shown' | 'hidden'; agency?: 'shown' | 'hidden' }` to `SiteConfig`
- Add `attribution-locked?` parsing (`one-locked: true` etc.)
- Thread `attribution` and `parentWorkspace` into `Layout.astro` → `Sidebar.tsx`
- `Sidebar` renders `<Attribution>` based on resolved values:
  - `one: hidden` requires Pro plan (`owners.plan !== 'free'`) — render-time check (4a will harden at API)
  - `agency: shown` requires `parentWorkspace`

---

### 1c — Locked properties in `parseSite()` + `merge()`
`model: sonnet · deps: none · files: src/lib/site.ts · refs: roles.md §9, groups.md §4`

- Parse `{key}-locked: true` frontmatter into a `locked` map
- `merge(parent, child)` skips child value for any key in `parent.locked`
- Tier-violation guard: a child layer cannot lock a key the parent already locked

---

### 1d — `owners.plan` field
`model: haiku · deps: none · files: migrations/0009_owners_plan.sql (new), src/lib/slug.ts · refs: groups.md §8`

```sql
ALTER TABLE owners ADD COLUMN plan TEXT NOT NULL DEFAULT 'free';
CREATE INDEX IF NOT EXISTS idx_owners_plan ON owners(plan);
```

- Update `getSlugOwner()` to include `plan`
- Add `plan: 'free' | 'pro' | 'agency' | 'enterprise'` to `SlugOwner`
- Pass through to `WorkspaceConfig`

---

### 1f — Settings page section framework
`model: sonnet · deps: none · files: src/pages/u/[slug]/settings.astro, src/components/settings/SettingsView.tsx (refactor), src/components/settings/ProfileSection.tsx (extract)`

- Refactor to left-rail nav + right pane (mirrors sidebar)
- Sections: Profile (existing), Domain (existing), Branding (3a), Clients (3b), Teams (3c), Navigation (3d), Chat (3e), Appearance (3f), Plan (4b)
- URL hash `#branding` etc. selects active section
- Section visibility gated by viewer + plan
- `SettingsView.tsx` becomes the container; existing form fields move to `ProfileSection.tsx`

This is the host structure — Tier-4 sections plug into it, but they don't need to wait for it if developed against the existing flat panel and re-mounted later. Listed Tier-1 because it's pure refactor with no upstream code dependency.

---

### H1 — Session cookie + `hasSession` population
`model: sonnet · deps: none · files: src/lib/passkey.ts (add issueSession, readSession), src/middleware.ts · refs: authentication.md §7`

```ts
const sig = hmac(SERVER_SECRET, `${slug}:${exp}`)
const cookie = `${slug}:${exp}:${sig}`  // Set-Cookie: one-session=...; Max-Age=2592000; Secure; HttpOnly; SameSite=Lax
```

- Issued on successful `/api/provision` register + `/api/commit` auth + `/api/link` redeem (when 0h ships)
- 30-day sliding expiry
- `readSession(request) → { slug } | null` — verifies HMAC + expiry
- Middleware: `ctx.locals.session = readSession(request)` → fed into `deriveViewer()`

---

### H4 — Replay set → KV
`model: sonnet · deps: none · files: src/lib/passkey.ts, wrangler.toml (KV binding) · refs: authentication.md §1`

```ts
await env.SESSION.put(`replay:${challenge}`, '1', { expirationTtl: 120 })
const seen = await env.SESSION.get(`replay:${challenge}`)
```

- Reuse existing `SESSION` KV namespace
- 120s TTL matches challenge expiry
- Read-then-write race acceptable — challenge expiry bounds the window

---

### H5 — WebAuthn counter persistence
`model: haiku · deps: none · files: migrations/0014_owners_keys_counter.sql (new), src/lib/passkey.ts · refs: authentication.md §2`

```sql
ALTER TABLE owners_keys ADD COLUMN counter INTEGER NOT NULL DEFAULT 0;
```

- Pass stored counter to `verifyAuthenticationResponse`
- On success: `UPDATE owners_keys SET counter = ? WHERE slug = ? AND credential_id = ?`
- Reject if returned counter ≤ stored (clone signal)

---

### H6 — Email delivery
`model: sonnet · deps: none · files: src/lib/email.ts (new) · refs: authentication.md §6, lifecycles-ui.md §7.1`

- Provider: Resend (single API key, $0 free tier covers MVP)
- Env: `RESEND_API_KEY`, `EMAIL_FROM`
- Three inline templates: `invite`, `recovery`, `paymentFailed` — string interpolation, no engine
- One function: `sendEmail(to, subject, html)` — POST to Resend API
- Failures logged but non-fatal

---

### H7 — Rate limiting
`model: haiku · deps: none · files: wrangler.toml (CF rate-limit rules) · refs: authentication.md (production gate)`

| Endpoint | Limit |
|----------|-------|
| `/api/provision` | 5/min/IP |
| `/api/auth`, `/api/commit` | 30/min/IP |
| `/api/domain` | 5/hour/IP |
| `/api/settings` | 60/min/slug |
| `/api/billing` | 30/min/slug |
| `/api/link` | 10/min/slug |
| `/api/recover` | 3/hour/IP |

429 responses include `Retry-After`. Owners exempt via `staffRole` header.

---

### H9 — ToS acceptance flow
`model: sonnet · deps: none · files: src/pages/get-yours.astro, src/pages/api/provision.ts`

Schema fields already exist (`owners.tos_hash`, `owners.tos_signed_at`).

- Inline ToS link + "I accept the terms" checkbox before passkey button
- On register POST: `tos_hash = 'v1'`, `tos_signed_at = unixepoch()`
- Reject if unchecked
- Versioning: bump `tos_hash` to `v2` later → existing users see one-time re-acceptance

---

### H10 — Custom error pages + ErrorBoundary
`model: sonnet · deps: none · files: src/pages/404.astro (new), src/pages/500.astro (new), src/components/ErrorBoundary.tsx (new)`

- 404 workspace-aware (uses `resolveIdentity`) — "Page not found on {name}"
- 500 minimal, no workspace lookup
- ErrorBoundary wraps every `client:*` island root in Layout.astro fallbacks

---

### H11 — D1 point-in-time recovery
`model: haiku · deps: none · files: wrangler.toml, web/runbook.md (new)`

CF D1 has built-in Time Travel up to 30 days. Enable in dashboard or via `wrangler d1 time-travel`. Runbook documents the recovery procedure. **Required before 4d ships** — irreversible deletes need recovery.

---

### H12 — Playwright resell-loop e2e
`model: sonnet · deps: none (independent infra) · files: tests/e2e/resell-loop.spec.ts (new)`

The highest-value path:

```
1. agency signs up at one.ie/get-yours
2. upgrades to Agency plan (Stripe test mode)
3. attaches custom domain (mocked DNS)
4. provisions a client (creates invite)
5. client redeems invite at agency domain
6. client publishes an agent
7. end_user (different browser context) hits client.{agency}.com
8. agent responds in chat
```

Runs on CF Pages preview deploys. Failure blocks merge to main. Other feature tests live in component-level vitest. (Note: this **executes** against features that must already be in place — but the test itself can be written first as an aspirational fixture, with `test.skip()` flipping to `test()` as features land.)

---

### 5a — OG metadata on `/u/[slug]`
`model: haiku · deps: none · files: src/pages/u/[slug]/index.astro · refs: groups.md §6`

```html
<meta property="og:title" content="{identity.name}" />
<meta property="og:description" content="{identity.tagline}" />
<meta property="og:image" content="/api/logo/{slug}" />
<meta property="og:url" content="https://{identity.shortUrl}" />
```

When accessed via custom domain, canonical URL uses domain.

---

### 5b — `/u/[slug]/workspace.astro` (file listing extracted)
`model: sonnet · deps: none · files: src/pages/u/[slug]/workspace.astro (new)`

- Move file-listing content out of `index.astro`
- Gate: redirect `client`/`end_user` → `/u/{slug}/chat`
- Add to agency/owner nav as "Workspace"

---

### 5c — Replace `@{slug}` with `identity.name`
`model: haiku · deps: none · files: src/pages/u/[slug]/settings.astro, src/components/sidebar/SheetMenu.tsx (~line 77), src/layouts/Layout.astro (~line 19) · refs: groups.md §7, §11`

Use `resolveIdentity(slug, site).name` everywhere. Already done in `index.astro` and `chat.astro`.

---

### 5d — Group identity card endpoint
`model: sonnet · deps: none · files: src/pages/u/[slug]/.well-known/agent-card.json.ts (extend) or sibling group-card.json.ts · refs: groups.md §9`

- Wrap or sibling: agent card + group envelope
- Fields: `slug, name, tagline, domain, logo, parent, type, plan, agents, children, attribution`
- `children`: `SELECT slug FROM owners WHERE parent_slug = ?`
- Gate: `plan`, `parent`, `attribution` omitted for `end_user` requests

---

### 5e — `/api/logo/[slug]` placeholder fallback
`model: sonnet · deps: none · files: src/pages/api/logo/[slug].ts (extend)`

- On 404: generate SVG placeholder — initials from `site.name ?? slug`, background = workspace `primary` token, foreground = `on-primary`
- Direct R2 read of `{slug}/site.md` for performance (skip resolveConfig)
- Cache: `Cache-Control: public, max-age=86400`
- Optional `?size=64|128|256`

---

### 0g — `owners_keys` multi-RP migration
`model: haiku · deps: 0f · files: migrations/0013_owners_keys_rp.sql (new), src/lib/passkey.ts (add findCredential) · refs: authentication.md §10`

```sql
ALTER TABLE owners_keys ADD COLUMN credential_id TEXT;
ALTER TABLE owners_keys ADD COLUMN rp_id TEXT NOT NULL DEFAULT 'one.ie';
CREATE INDEX idx_owners_keys_rp ON owners_keys(slug, rp_id);
INSERT INTO owners_keys (slug, pubkey, credential_id, rp_id, label)
  SELECT slug, pubkey, credential_id, 'one.ie', 'primary' FROM owners
  WHERE NOT EXISTS (SELECT 1 FROM owners_keys k WHERE k.slug = owners.slug AND k.pubkey = owners.pubkey);
```

`findCredential(slug, rpId, db)` — single SELECT, replaces `getSlugOwner().pubkey` in verify path. Returns `null` → caller responds `{ error: 'no-credential', rpId }` so UI can offer device-link.

---

### 0d — Plan section + Stripe checkout
`model: sonnet · deps: 1f · files: src/components/settings/PlanSection.tsx (new), src/pages/api/billing.ts (new), migrations/0012_payment_status.sql (new) · refs: lifecycles-ui.md §5.1`

```sql
ALTER TABLE owners ADD COLUMN stripe_customer_id TEXT;
ALTER TABLE owners ADD COLUMN stripe_subscription_id TEXT;
ALTER TABLE owners ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'ok';
  -- values: 'ok' | 'failed' | 'past_due' | 'cancelled'
ALTER TABLE owners ADD COLUMN plan_renews_at INTEGER;
CREATE INDEX idx_owners_payment_status ON owners(payment_status) WHERE payment_status != 'ok';
```

- `PlanSection.tsx`: current plan + 3-column comparison + "Choose Pro/Agency"
- `/api/billing?action=checkout` — Stripe Checkout Session, returns redirect URL
- `/api/billing?action=portal` — customer portal redirect
- `/api/billing?action=webhook` — handler (signature verified by H8) — updates `plan`, `stripe_customer_id`, `payment_status`, `plan_renews_at`
- `/api/billing?action=preview-downgrade` — impact summary for 4e
- "Cancel subscription" → opens 4e modal

Env: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO`, `STRIPE_PRICE_AGENCY`.

---

### 1b — `resolveConfig()` 5-layer cascade
`model: opus · deps: 1c · files: src/lib/config.ts (new), src/middleware.ts · refs: roles.md §11, groups.md §4`

- `resolveConfig({ slug, parentSlug, groupId, env })` reads:
  - L1 `{slug}/site.md` · L2 `{parentSlug}/site.md` · L3 `{slug}/clients/{clientSlug}.md` (2a) · L4 `{slug}/teams/{groupId}.md` (2b) · L5 platform defaults
  - Merge with locked-property semantics
- Expose `WorkspaceConfig` (typed) instead of bare `SiteConfig`
- Thread through `ctx.locals` → `Layout.astro` → components

```ts
interface WorkspaceConfig extends SiteConfig {
  features?: { chat?:boolean; agents?:boolean; skills?:boolean; tools?:boolean; payments?:boolean }
  nav?: { items?: NavItem[]; footer?: NavItem[] }
  chat?: { welcome?:string; placeholder?:string; agentId?:string }
  attribution?: { one?:'shown'|'hidden'; agency?:'shown'|'hidden' }
  locked?: Partial<Record<string, boolean>>
  plan?: 'free' | 'pro' | 'agency' | 'enterprise'
}
```

---

### H2 — Auth gate on `/api/settings` form POST
`model: sonnet · deps: H1 · files: src/pages/api/settings.ts · refs: authentication.md §5`

- Existing form path: require session cookie (H1) AND `slug === session.slug` (or `staffRole`)
- Sensitive fields (`wallet`, `agentverse_key_enc`, `recovery_email`): require fresh assertion (`checkToken` + WebAuthn) on top of session
- New `?action=site` path (1e) already requires `checkToken`

---

### 0h — `/api/link` device-link endpoint
`model: sonnet · deps: 0g · files: src/pages/api/link.ts (new) · refs: authentication.md "Multi-Domain via Device-Link"`

Two actions:
- `issue` — authenticated at existing domain, returns short-lived HMAC token bound to slug (10min, one-shot)
- `redeem` — at new domain, validates token, runs `verifyRegistrationResponse`, inserts row in `owners_keys` with new RP

No new schema. Reuses `makeChallenge` / `checkToken`.

---

### H3 — Multi-credential verify path
`model: sonnet · deps: 0g · files: src/lib/passkey.ts (verifyCommitAssertion), src/pages/api/commit.ts, src/pages/api/commit-media.ts · refs: authentication.md §3`

- Use `findCredential(slug, rpId, db)` instead of `getSlugOwner().pubkey`
- Iterate matching rows when multiple credentials exist (rare); first verify wins
- Same change in `commit.ts` + `commit-media.ts`
- No new schema beyond 0g

---

### 0b — Invite-link table + redeem flow
`model: sonnet · deps: 0g, H6 · files: migrations/0011_invites.sql (new), src/pages/api/provision.ts (extend with ?action=create-invite + ?action=redeem-invite), src/pages/u/[slug]/index.astro (read ?invite=) · refs: lifecycles-ui.md §4.2`

```sql
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

- `?action=create-invite` — agency tier check
- `?action=redeem-invite` — client redeems via passkey
- `index.astro` with `?invite={token}`: full-screen welcome card with passkey button (no session) or auto-redeem (has session)
- Expired/redeemed pages
- Email send via H6 (`invite` template)

---

### H8 — Stripe webhook signature verification
`model: sonnet · deps: 0d · files: src/pages/api/billing.ts (extend)`

- `stripe.webhooks.constructEvent(body, sig, STRIPE_WEBHOOK_SECRET)`
- 400 on invalid signature, no DB write
- Idempotency: skip events with `event.id` already processed (KV or `webhook_events` table)

---

### 1e — `/api/settings ?action=site`
`model: sonnet · deps: 1b · files: src/pages/api/settings.ts (extend) · refs: roles.md §11`

- New JSON action `?action=site`, returns JSON
- Auth: `checkToken` (form path uses session-slug only — keep separate)
- Body: `{ slug, challenge, token, patch: Partial<WorkspaceConfig> }`
- Reads `{slug}/site.md`, merges patch (respecting parent locks via 1b), writes back
- Rejects keys locked by parent workspace
- Returns updated `WorkspaceConfig`

---

### 2a — Per-client override file
`model: sonnet · deps: 1b · files: src/lib/config.ts (extend resolveConfig), R2 path {slug}/clients/{clientSlug}.md · refs: roles.md §4, §11`

- Layer 3 read: `{slug}/clients/{clientSlug}.md` when `viewerSlug !== workspaceSlug`
- Merge after workspace, before team
- `parseSite()` already handles the format

---

### 2b — Per-team config file
`model: sonnet · deps: 1b · files: src/lib/config.ts (extend), src/env.d.ts · refs: roles.md §4, §5`

- Layer 4 read: `{slug}/teams/{gid}.md` when session carries `groupId`
- `groupId` from session cookie (future: TypeDB membership)
- Add `groupId?: string` to `WorkspaceContext`

---

### 6c — PaymentFailureBanner
`model: haiku · deps: 0d · files: src/components/billing/PaymentFailureBanner.tsx (new), src/layouts/Layout.astro · refs: lifecycles-ui.md §7.1`

- Mounted above main content
- Visible when `owners.payment_status` is `'failed'` or `'past_due'`
- Persistent across routes; dismiss = sessionStorage, reappears next session
- "Update payment" → portal redirect via `/api/billing?action=portal`
- Grace deadline = webhook timestamp + 7 days
- Style: `bg-destructive/10`, border-destructive, full-width strip

---

### 4e — DowngradeImpactModal
`model: sonnet · deps: 0d · files: src/components/billing/DowngradeImpactModal.tsx (new), src/pages/api/billing.ts (extend ?action=preview-downgrade) · refs: lifecycles-ui.md §7.3, lifecycles.md §9d`

- Triggered from PlanSection "Cancel subscription"
- Modal queries `?action=preview-downgrade` at open
- Backend computes: client count, count with locked attributions, count with custom domains, total active end_user sessions/30d
- Renders impact list per `lifecycles-ui.md §7.3`
- Effective date = end of current cycle (`owners.plan_renews_at`)
- "Confirm downgrade" → POST `?action=schedule-downgrade` (Stripe subscription update at period end)

---

### 3a — Settings: Branding section
`model: sonnet · deps: 1e, 1f · files: src/pages/u/[slug]/settings.astro, src/components/settings/BrandingSettings.tsx (new) · refs: groups.md §5`

- "Powered by ONE" toggle — disabled + tooltip if plan = free
- "Powered by [Agency]" — only when `parentWorkspace`; locked if agency locked it
- Writes to `{slug}/site.md` via `/api/settings ?action=site`

---

### 3b — Settings: Client manager
`model: sonnet · deps: 1e, 1f · files: src/components/settings/ClientManager.tsx (new), src/pages/api/provision.ts (extend with ?action=client-workspace) · refs: roles.md §6, groups.md §9`

- New action `?action=client-workspace` — creates child `owners` row + seeds site.md
- UI:
  - Plan gate — upgrade prompt if not agency/enterprise
  - List clients (`SELECT slug, display_name FROM owners WHERE parent_slug = ?`)
  - "New client" form: slug (auto-suggest `{agencySlug}-{name}`), display name; creates row with `parent_slug = agencySlug` and `plan = 'free'`; seeds `{clientSlug}/site.md` with agency tokens
  - Edit/revoke per client

---

### 3c — Settings: Team manager
`model: sonnet · deps: 1e, 1f, 2b · files: src/components/settings/TeamManager.tsx (new) · refs: roles.md §7, groups.md §1`

- List teams (D1 `teams` or TypeDB membership)
- Create team: name, slug (prefixed), member slugs
- Assign features per team
- Writes `{slug}/teams/{gid}.md`

---

### 3d — Settings: Nav override UI
`model: sonnet · deps: 1e, 1f · files: src/components/settings/NavSettings.tsx (new) · refs: roles.md §6, §8`

- Drag-to-reorder standard nav
- Add custom item: label, href, icon (Lucide name), viewer tiers (multiselect)
- Toggle visibility per tier
- Writes `nav.items` + `nav.footer` into `{slug}/site.md`

---

### 3e — Settings: Chat config UI
`model: sonnet · deps: 1e, 1f · files: src/components/settings/ChatSettings.tsx (new) · refs: roles.md §9`

- Welcome message textarea
- Input placeholder
- Default agent persona (dropdown)
- Starter chip override (≤5 per lifecycle×viewer cell)
- Attachments toggle: `enabled | images-only | disabled`
- Voice toggle: `enabled | disabled` (Pro plan gate)
- Writes `chat.*` into `{slug}/site.md`

---

### 3f — Sidebar mode setting (mini/full/hidden)
`model: sonnet · deps: 1e, 1f · files: src/components/settings/AppearanceSettings.tsx (new), src/layouts/Layout.astro · refs: roles.md §6, §10`

- Three-option radio in Appearance section (agency+owner only)
- `Layout.astro` passes `sidebar` prop to `<Sidebar>`:
  - `mini` — 56px default, hover/pin to expand (current)
  - `full` — always 240px
  - `hidden` — no sidebar, full-width content, mobile-only bottom nav
- Writes `sidebar` key to `{slug}/site.md`

---

### 3g — Mobile feature gates
`model: sonnet · deps: 1b · files: src/layouts/Layout.astro, src/lib/config.ts · refs: roles.md §10`

- `mobile.sidebar: sheet | hidden`
- `mobile.features` — subset active on mobile (e.g. `[chat, agents]`)
- `Layout.astro` reads `workspaceConfig.mobile`, conditionally renders `<SheetMenu>` and mobile-only surfaces

---

### 2c — Surface-matrix in-page guards
`model: sonnet · deps: 2a, 2b · files: src/pages/u/[slug]/[kind]/index.astro, src/pages/u/[slug]/skills/index.astro, etc. · refs: roles.md §7`

Menu hides items by viewer — pages need guards too.

- `/skills` — redirect `client` + `end_user` → `/chat`
- `/payments` — `client` sees own billing only; `end_user` redirects
- `/agents` — hide "Create" for `client` + `end_user`; `end_user` sees public only
- `/tools` — hide "Add tool" + "Configure" for `client`; redirect `end_user`
- `/settings` — `client` reaches passkeys/notifications/theme only; redirect from branding/domain/team
- Pattern: read viewer from `Astro.locals.workspaceContext.viewer`, redirect or conditionally render

---

### 4a — Plan gate enforcement (`src/lib/plan.ts`)
`model: opus · deps: 1d, 1e, 3b · files: src/lib/plan.ts (new), src/pages/api/settings.ts (extend ?action=site), src/pages/api/provision.ts (extend ?action=client-workspace) · refs: groups.md §8`

```ts
export function canRemoveAttribution(plan: Plan): boolean
export function canCreateClientWorkspace(plan: Plan): boolean
export function maxClientWorkspaces(plan: Plan): number
export function canEnableFeature(plan: Plan, feature: keyof Features): boolean
```

- `/api/settings ?action=site` — reject patches violating `canEnableFeature` for `attribution.one`, `features.skills`, `features.payments`, `chat.voice`
- `/api/provision ?action=client-workspace` — reject if `!canCreateClientWorkspace(plan)` or count exceeds `maxClientWorkspaces(plan)`

---

### 4b — UpgradePrompt (8 trigger points)
`model: sonnet · deps: 4a · files: src/components/settings/UpgradePrompt.tsx (new) · refs: lifecycles-ui.md §5.5, groups.md §8`

Replaces the gated control inline (not a toast).

- Props: `requiredPlan: 'pro' | 'agency' | 'enterprise'`, `feature: string`, `currentPlan: Plan`
- Renders: feature name + "Requires {plan}" + "Upgrade →" link to `/u/{slug}/settings#plan`
- Trigger points: Domain on free → Pro · Branding "Hide ONE" on free → Pro · Chat voice on free → Pro · Clients empty on free/pro → Agency · Domains "Add client" on free/pro → Agency · Branding "Lock for clients" on free/pro → Agency · Skills publish-paid on free → Pro · Agents voice on free → Pro

---

### 4c — Agency subdomain provisioning UI
`model: sonnet · deps: 4a, 3b · files: src/components/settings/DomainSettings.tsx (extend) · refs: groups.md §3, §11, lifecycles-ui.md §5`

- New section "Client domains" — lists where `parent_slug = agencySlug`
- Helper: guides agency through pointing `client.{agencyDomain}` at `{agencySlug}.one.ie`
- One-click setup link: `https://acme.com/u/[clientSlug]/settings#domain?host=client.com`
- Agency plan gate

---

### 4d — DangerSection
`model: sonnet · deps: 4a, H11 · files: src/components/settings/DangerSection.tsx (new), src/pages/api/settings.ts (extend ?action=delete-workspace) · refs: lifecycles-ui.md §7.2, lifecycles.md §9d`

- Visible only when session slug = workspace slug (no proxy delete)
- "Delete workspace" → modal with typed-slug confirmation
- Requires passkey re-challenge (not just session) — uses `/api/auth` ceremony
- Backend: deletes `owners` → CASCADE deletes invites + sets `domains.parent_slug = NULL` for sub-clients
- Async R2 purge of `{slug}/*` via queue
- Sub-clients survive: `parent_slug = NULL`, revert to platform defaults

---

### 6a — Revenue dashboard
`model: sonnet · deps: 4a, 0d · files: src/pages/u/[slug]/payments.astro (extend) · refs: groups.md §8`

- x402 earnings: per-skill/agent breakdown, split display
- Stripe subscription: current plan, next billing, invoice list
- Client billing sub-section (agency plan): per-client usage + plan

---

### 6b — x402 revenue split
`model: sonnet · deps: 4a · files: src/pages/api/x402.ts (extend) · refs: groups.md §8`

- On payment receipt, split: creator 85%, platform 10%, protocol 5%
- `revenue-split` in `site.md` adjustable per workspace (min platform 5%)
- Record split in D1 `payments` with `creator_slug`, `platform_pct`, `creator_pct`

---

## Deferred (TypeDB milestone)

- TypeDB `membership` relation for multi-group + cross-workspace membership
  - Currently: viewer derived from session cookie + slug comparison
  - Target: `deriveViewer()` queries TypeDB for the workspace
  - Unblocks: team membership without D1 `teams`, cross-workspace roles
  - Refs: `roles.md §1`

---

## Close

Each item closes individually:

```
/close --item <id>     # marks pheromone for that item only; does not gate other items
```

Cycle close (when all open boxes are checked):

```
/close --todo roles --cycle 1     # hard gate — appends one entry to learnings.md
```

Per-item rubric (security / stability / simplicity / speed) is scored at item close. Items below 0.65 re-enter their own W3 (max 3 loops) — they do not block siblings.

*One TODO. Many lanes. Real edges only. Claim Tier 1, fan out wide.*
