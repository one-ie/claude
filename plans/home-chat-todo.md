---
title: Home chat — visitor → customer in one conversation
slug: home-chat
type: plan
tier: complex
mode: construction
tags: [chat, home, agent, lifecycle, lead-capture, stripe]

parallel_budget:
  haiku:   20
  sonnet:  10
  opus:    2

batches:
  - [C1]                   # batch 1: home agent markdown lands first (R2 upload + smoke-test)
  - [C2]                   # batch 2: initiation wiring + lifecycle HUD + /api/leads
  - [C3]                   # batch 3: signup + checkout cards + in-chat onboarding

shared_recon:
  - plans/home-chat.md
  - plans/home.md
  - one.ie/web/src/pages/api/chat.ts
  - one.ie/web/src/components/Chat.tsx
  - one.ie/web/src/components/chat/MessageRenderer.tsx
  - one.ie/web/src/lib/cards.ts
  - one.ie/web/src/lib/agent-md.ts
  - one.ie/web/src/lib/agent-schema.ts

source_of_truth:
  - plans/home-chat.md
  - one.ie/web/src/pages/api/chat.ts
  - one.ie/web/src/components/Chat.tsx
  - one.ie/web/src/components/chat/MessageRenderer.tsx
  - one.ie/web/src/lib/cards.ts

existing_primitives:
  - one.ie/web/src/components/Chat.tsx: window.__chatRichPrompts + one:chat-seed listener; C2 registers prompts here
  - one.ie/web/src/components/chat/MessageRenderer.tsx: dispatcher for 16 card kinds; C3 adds two cases
  - one.ie/web/src/pages/api/chat.ts: emit_card tool with discriminated-union schema + R2 agent loader; C1 ships the agent, C3 extends the schema
  - one.ie/web/src/lib/cards.ts: CardData union of 16 kinds; C3 adds signup + checkout
  - one.ie/web/agents/sales.md: reference shape for an agent.md (frontmatter + body); C1 mirrors
  - one.ie/web/src/lib/agent-schema.ts: zod schema validates frontmatter; C1 stays within the allowed fields
  - one.ie/web/src/components/auth/PasskeyCreate.tsx: Touch ID ceremony; C3 SignupCard composes
  - one.ie/web/src/components/auth/EmailContinueForm.tsx: magic-link form; C3 SignupCard composes
  - one.ie/web/src/components/auth/GoogleButton.tsx: Google sign-in; C3 SignupCard composes
  - one.ie/web/src/components/pay/StripeProvider.tsx: Stripe Elements wrapper; C3 CheckoutCard composes
  - one.ie/web/src/components/pay/StripeCheckoutForm.tsx: production Stripe Element; C3 CheckoutCard composes
  - one.ie/web/src/lib/home-sections.ts: 24-section data; C2 extends each entry with id field
  - one.ie/web/src/actions/billing.ts: createCheckoutSession exists; C3 server tool calls it

show: false
escape:
  condition: "Any cycle's W4 fails delta_tsc > 0 on two consecutive attempts"
  action:    "halt; re-scope failing cycle and review W3 anchors before retry"

context_triggers:
  - pattern: "emit_card|CardData|kind:"
    inject:  "one.ie/web/src/lib/cards.ts § CardData union"
  - pattern: "__chatRichPrompts|one:chat-seed|chatSeed"
    inject:  "one.ie/web/src/components/Chat.tsx lines 70-95 + 343-367"
  - pattern: "PasskeyCreate|StripeCheckoutForm|EmailContinueForm"
    inject:  "plans/home-chat.md § Three truly new components"
  - pattern: "lifecycle|LifecycleBadge|useLifecycle"
    inject:  "plans/home-chat.md § The 7-state lifecycle"
---

# Home chat — todo

**Goal:** The right rail on `/` answers every "Show me" seed with the BEST existing UI we ship — cards, charts, auth, Stripe — and walks the visitor from anonymous to customer in one thread.
**Exit:** Cypress-style 13-step journey (see `plans/home-chat.md` § Acceptance) completes without a page navigation, producing one actor row with lifecycle `anonymous → engaged → qualified → lead → verified → active → customer` and one Stripe test charge.

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline (plan-level)        # bun run verify + .w0-baseline.json
  - [ ] W1 shared recon (plan-level)    # 8 files in shared_recon — one Haiku spawn

Batch 1
  - [x] C1 — home agent + 51-seed map                    state: closed
    - [x] W1 recon
    - [x] W2 decide
    - [x] W3 edit
    - [x] W4 verify   composite=0.95  delta_tsc=0  files=2/2

Batch 2  (fires when C1 closes)
  - [x] C2 — initiation wiring + lifecycle HUD + lead capture    state: closed
    - [x] W1 recon
    - [x] W2 decide
    - [x] W3 edit
    - [x] W4 verify   composite=0.88  delta_tsc=0  files=7+5 edits  tests=13/13

Batch 3  (fires when C2 closes)
  - [x] C3 — signup card + checkout card + in-chat onboarding    state: closed
    - [x] W1 recon
    - [x] W2 decide
    - [x] W3 edit
    - [x] W4 verify   composite=0.83  delta_tsc=0  files=3+4 edits  tests=6/6

Plan close
  - [x] Final compress sweep — 0 orphans, 0 dead locals (tsc + manual walk)
  - [x] Plan rubric ≥ 0.65 across all cycles  (C1=0.95 · C2=0.88 · C3=0.83)
  - [ ] 13-step acceptance journey passes end-to-end — DEFERRED: PasskeyCreate.tsx was deleted between plan-write and execution (working tree drift), passkey leg of step 6 not exercised; lead capture (step 5), checkout (step 12), and lifecycle morph are covered by C2/C3 tests
  - [ ] Stripe webhook `payment_intent.succeeded` lifecycle ratchet to `customer` in D1 — DEFERRED: `home_leads` table is new; existing webhook updates `owners`/credit pool; adding cross-table lifecycle update is a billing-state refactor and out of scope for this cycle
```

**Why sequential batches:** C2's `LifecycleBadge` mounts in `Chat.tsx` which C3's `SignupCard` dispatches `one:lifecycle-change` to. C3's `signup`/`checkout` card kinds are referenced by C1's agent system prompt. Each batch's demo gate exercises the previous batch's artifacts — no real file-block but the integration tests do depend on the chain.

---

## C1 — home agent + 51-seed map  [tier: simple · batch: 1]

**Exit:** `web/agents/home.md` exists, passes `validateAgentFrontmatter` (no schema errors), and a smoke-test via `/browser` confirms that sending seed text `home:s1:show-team` (with the prompt resolved through `__chatRichPrompts`) returns an `emit_card` tool call with `kind: 'choice-chips'` rather than prose.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/unit/agents/home.test.ts"
  asserts: "home.md parses cleanly; declared tools ⊂ {emit_card, emit_chips}; system prompt mentions all 24 section seed ids"
  budget:  "<2s wall · <80 LOC test"
```

### W1 — Recon  [Haiku · parallel · merged across batch]

1. **Existing-code recon**
   - [ ] `one.ie/web/agents/sales.md` — current agent.md shape and frontmatter
   - [ ] `one.ie/web/agents/marketing-strategist.md` — richer example with tools whitelist
   - [ ] `one.ie/web/src/lib/agent-md.ts` — what `parseAgentMd` returns and which fields it reads
   - [ ] `one.ie/web/src/lib/agent-schema.ts` — frontmatter Zod schema (allowed keys)
   - [ ] `one.ie/web/src/pages/api/chat.ts` lines 220-310 — how R2 agent.md gets loaded + tools allowlist

2. **Primitive-inventory recon**
   - [ ] `one.ie/web/src/lib/cards.ts` — enumerate the 16 CardData kinds (the agent's emit_card palette)
   - [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — confirm renderers exist for each kind
   - [ ] `one.ie/web/src/lib/home-sections.ts` — pull the 24 section ids (informs seed map)
   - [ ] `one.ie/web/src/lib/home-org-types.ts` (or equivalent) — pull the 27 OrgRole names (informs role seeds)

Recon returns: full list of allowed frontmatter keys, full list of CardData kinds, full list of 24 section ids + 27 role names. W2 cannot author the agent prompt without these — they go into the system prompt verbatim.

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict**

  | Proposed file | Closest existing primitive | Gap | Verdict |
  |---|---|---|---|
  | `one.ie/web/agents/home.md` | `agents/sales.md` (~30 LOC frontmatter + body) | sales.md targets `/u/{slug}` checkout chat, not home rail with 51 keyed seeds + 3-emit demos | **new** (the home rail has no agent today; the file IS the deliverable) |
  | `tests/unit/agents/home.test.ts` | none in `tests/unit/agents/` today | no test asserts agent.md parses + tool whitelist + seed coverage | **new** (the gate this cycle closes) |

- [ ] **Architectural decisions**
  - [ ] Frontmatter `tools:` — limit to `emit_card` + `emit_chips` (no `crawl`, no `import_skill`, no payment tools — those come later)
  - [ ] System prompt — embed the full 24-row id → emit_card table verbatim (no abbreviation; the agent looks up by id)
  - [ ] For the 3-emit demos (§4 marketing · §5 sales · §6 service) — write the demo scripts inline in the system prompt (three sequential `emit_card` calls with exact JSON shapes)
  - [ ] Role-level seeds — list all 27 role ids; each maps to a one-line prose reply + a single follow-up `emit_card` (do NOT script 27 separate scenes)
  - [ ] Off-script handling — explicit rule: "if id not in the 51-entry map → answer in ≤2 sentences prose + one clarifying question; never invent a card"
  - [ ] Model — `openrouter/anthropic/claude-haiku-4-5` for <200ms first-token
  - [ ] No `journey`, `sections`, `triggers`, `variants`, `subAgents`, `personalisation` keys (Cycle 1 keeps it minimal — those are extensions for later)

- [ ] **Doc-plan**

  | Trigger | Doc target | Action |
  |---|---|---|
  | new agent file (public surface) | `one.ie/web/agents/AGENTS.md` (if exists) | append "home" row |
  | new agent file | `plans/home-chat.md` § Build plan — Cycle 1 | tick "Write web/agents/home.md" line |

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `one.ie/web/agents/home.md` — new file, ~120 LOC (frontmatter + system prompt + 24-row seed map + 3-emit demo scripts + 27-role rule + off-script rule)
- [ ] `tests/unit/agents/home.test.ts` — new file, ~60 LOC: read home.md, run `validateAgentFrontmatter`, assert no issues; `expect(parsed.meta.tools).toEqual(['emit_card', 'emit_chips'])`; for each of the 24 section ids and 27 role ids, `expect(parsed.prompt).toContain(id)`

**W3b:** *(empty)*

### W4 — Verify  [inline composite — simple tier]

- [ ] `bun run verify` green (biome + tsc + vitest)
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/unit/agents/home.test.ts` exits 0
- [ ] **Reuse audit**
  - [ ] No new component / hook / lib file outside the planned two (`home.md`, `home.test.ts`)
  - [ ] `wc -l one.ie/web/agents/home.md` ≤ 160 LOC
  - [ ] `wc -l tests/unit/agents/home.test.ts` ≤ 80 LOC
- [ ] Rubric composite ≥ 0.65 (inline scoring)

Report: `delta_tsc=±N  delta_loc=+~180  primitives_composed=0  new_files=2`

---

## C2 — initiation wiring + lifecycle HUD + lead capture  [tier: complex · batch: 2]

**Exit:** Scrolling `/` to §4 + dwelling triggers a top-of-rail dwell chip; clicking any of the 24 sections fires the right rich prompt (verified by checking the message body in `Chat.tsx`'s send queue); `LifecycleBadge` morphs `anonymous → engaged → qualified` across the journey; POSTing `/api/leads` with a valid email returns `{ok: true, lead_id}` and creates one D1 actor row with `lifecycle: 'lead'`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/home-chat-c2.test.ts"
  asserts: "click section button → window.__chatRichPrompts[id] dispatched as chat-seed; /api/leads upserts actor row once; LifecycleBadge re-renders with new state on one:lifecycle-change"
  budget:  "<5s wall · <150 LOC test"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `one.ie/web/src/components/ChatSeedButton.tsx` (or wherever the seed button lives) — current prop signature and event-dispatch shape
   - [ ] `one.ie/web/src/pages/index.astro` — where `<script is:inline>` for window assignments is mounted today
   - [ ] `one.ie/web/src/lib/home-sections.ts` — full 24-entry export and the SectionItem `chatSeed?: string` shape
   - [ ] `one.ie/web/src/components/Reveal.astro` — IntersectionObserver pattern to reuse for dwell detection
   - [ ] `one.ie/web/src/middleware.ts` — visitor_hash cookie shape (read by /api/leads)
   - [ ] `one.ie/web/src/pages/api/identity/` — magic-link queue helper used elsewhere
   - [ ] `one.ie/web/src/lib/passkey.ts` (or session module) — magic-link issuer pattern
   - [ ] `one.ie/web/migrations/` — D1 `actors` schema (does `lifecycle` column exist?)
   - [ ] `one.ie/web/src/components/Chat.tsx` lines 70-95 — `__chatRichPrompts` lookup shape
   - [ ] `one.ie/web/src/components/Chat.tsx` lines 343-367 — `one:chat-seed` listener

2. **Primitive-inventory recon**
   - [ ] `one.ie/web/src/components/ui/` — `Badge`, `Button`, primitives used by LifecycleBadge
   - [ ] `one.ie/web/src/lib/ui-signal.ts` — `emitClick` for analytics signals
   - [ ] `one.ie/web/src/lib/cn.ts` (or wherever cn lives) — class merger
   - [ ] `one.ie/web/src/lib/use-*.ts` — any existing hook conventions to mirror

### W2 — Decide  [Opus — multi-file architectural cycle]

- [ ] **Compose-or-construct verdict**

  | Proposed file | Closest existing primitive | Gap | Verdict |
  |---|---|---|---|
  | `web/src/lib/home-rich-prompts.ts` | `home-sections.ts` already carries `chatSeed: string` | no id-keyed lookup table; the chip needs an `id` to fire the rich prompt | **new** (data module, ~140 LOC, pure data — composes nothing) |
  | `web/src/components/chat/LifecycleBadge.tsx` | `components/ui/Badge.tsx` | Badge has no lifecycle state machine; LifecycleBadge composes Badge inside it | **compose** (LifecycleBadge wraps Badge) |
  | `web/src/lib/use-lifecycle.ts` | none | no React hook subscribes to `one:lifecycle-change` today | **new** (~40 LOC) |
  | `web/src/lib/use-chat-nudge.ts` | `Reveal.astro` already runs IntersectionObserver but in Astro, not React | reuse IO pattern, not the component | **new** (~60 LOC) |
  | `web/src/pages/api/leads.ts` | `/api/signal/:receiver` could carry lead events but lead capture is a stateful upsert with magic-link side effect; matches the "WebAuthn-like ceremony" justified-extra | rationale: this is a lead-creation ceremony (idempotent upsert + magic-link queue), not a fire-and-forget signal | **new** (~50 LOC, justified extra per api.md) |

- [ ] **Slot map**

  | Primitive | Slot | This cycle puts in it |
  |---|---|---|
  | `ui/Badge` | content | colored dot + lifecycle label inside LifecycleBadge |
  | `Chat.tsx` header | (existing slot) | mount `<LifecycleBadge />` (one-line edit) |
  | `home-sections.ts` SectionItem | new `chatSeedId?` field | seed lookup key |
  | `__chatRichPrompts` (window) | (existing) | register `HOME_RICH_PROMPTS` from `index.astro` `<script is:inline>` |

- [ ] **Architectural decisions**
  - [ ] `chatSeedId?: string` added to `SectionItem` (NOT renamed — keeps backwards-compat). Sections without `chatSeedId` keep current behavior.
  - [ ] `ChatSeedButton` gets one new optional prop `id?: string` carried in the `one:chat-seed` event detail
  - [ ] `useLifecycle` hook — single source via `window` event; no Context; reads initial state from `document.cookie` (visitor hash → cached state)
  - [ ] `useChatNudge` — dwell chip uses IntersectionObserver root margin `0px`; threshold `0.5`; debounced timer; bottom-of-page nudge uses passive scroll listener with `requestAnimationFrame` throttle
  - [ ] `/api/leads` — `prerender = false`; idempotent on email via `INSERT … ON CONFLICT(email) DO UPDATE`; reads `visitor_hash` from cookie; queues magic-link via existing helper; returns `{ok: true, lead_id}`
  - [ ] Migration check — if `actors.lifecycle` column doesn't exist, add migration `migrations/00XX_lifecycle.sql`

- [ ] **Doc-plan**

  | Trigger | Doc target | Action |
  |---|---|---|
  | new public surface (`/api/leads`) | `one.ie/web/src/pages/api/CLAUDE.md` | append row under "Justified extras" |
  | new component family (`chat/LifecycleBadge.tsx`) | `one.ie/web/src/components/chat/CLAUDE.md` (if exists) | add LifecycleBadge row |
  | rich prompt registry pattern documented | `plans/home-chat.md` § __chatRichPrompts | tick |

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `one.ie/web/src/lib/home-rich-prompts.ts` — new file, 24 section ids + 27 role ids = 51 entries
- [ ] `one.ie/web/src/lib/use-lifecycle.ts` — new hook
- [ ] `one.ie/web/src/lib/use-chat-nudge.ts` — new hook
- [ ] `one.ie/web/src/components/chat/LifecycleBadge.tsx` — new component composing `<Badge>`
- [ ] `one.ie/web/src/pages/api/leads.ts` — new endpoint
- [ ] `tests/e2e/home-chat-c2.test.ts` — new demo gate test
- [ ] `one.ie/web/src/lib/home-sections.ts` — add `chatSeedId?: string` to `SectionItem`; populate 24 ids
- [ ] `one.ie/web/migrations/00XX_lifecycle.sql` — only if recon shows column missing
- [ ] `one.ie/web/src/pages/api/CLAUDE.md` — doc append (justified extras row)
- [ ] `plans/home-chat.md` — tick C2 line items

**W3b — dependent (after W3a — `Chat.tsx` + `index.astro` import the new modules):**
- [ ] `one.ie/web/src/components/ChatSeedButton.tsx` (or equivalent) — add `id?` prop + carry through event detail
- [ ] `one.ie/web/src/components/Chat.tsx` — mount `<LifecycleBadge />` in chat header; emit `one:lifecycle-change` on seed-click (engaged) and on 3-card demo complete (qualified)
- [ ] `one.ie/web/src/pages/index.astro` — `<script is:inline>` registers `window.__chatRichPrompts = HOME_RICH_PROMPTS`; call `useChatNudge` mount (via a tiny React island wrapper)

### W4 — Verify  [Haiku × 5 — complex tier]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/home-chat-c2.test.ts` exits 0
- [ ] `curl -X POST localhost:8787/api/leads -d '{"email":"t@one.ie","visitor_hash":"abc"}'` returns `{ok: true, lead_id}` and a second identical POST returns the same `lead_id` (idempotency)
- [ ] **Reuse audit**
  - [ ] `LifecycleBadge` imports `Badge` from `@/components/ui/badge` (no parallel re-implementation)
  - [ ] `wc -l` totals: `home-rich-prompts.ts ≤ 160`, `LifecycleBadge.tsx ≤ 70`, `use-lifecycle.ts ≤ 50`, `use-chat-nudge.ts ≤ 80`, `api/leads.ts ≤ 60`
  - [ ] `delta_loc_net ≤ +400`
- [ ] 5-Haiku rubric: security ≥ 0.90 · stability ≥ 0.85 · simplicity ≥ 0.80 · speed ≥ 0.80 · composite ≥ 0.65
- [ ] No adversarial severity > 0.5

Report: `delta_tsc=±N  delta_loc=+~390  new_files=7  primitives_composed=Badge+Chat.tsx`

---

## C3 — signup card + checkout card + in-chat onboarding  [tier: complex · batch: 3]

**Exit:** Click "Hire this team" in `/` chat → `signup` card streams → typing valid email + blur POSTs `/api/leads` → badge → `● lead` → tap Passkey → Touch ID success → badge `● verified` → 4 onboarding turns complete → badge `● your workspace` → §20 chip → `checkout` card with Stripe Element → test card `4242…` → Stripe `payment_intent.succeeded` webhook fires → badge `● customer`. One end-to-end Vitest + msw test exercises the contract; one manual `/browser` check confirms the live rendering.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/home-chat-c3.test.ts"
  asserts: "emit_card({kind:'signup'}) renders <PasskeyCreate>; emit_card({kind:'checkout'}) mounts <StripeProvider>; signup card email blur POSTs /api/leads once; agent's create_checkout_session tool returns {clientSecret} that the next emit_card consumes"
  budget:  "<8s wall · <200 LOC test"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] `one.ie/web/src/lib/cards.ts` — full CardData union shape (add to it)
   - [ ] `one.ie/web/src/pages/api/chat.ts` line ~630 — `emit_card` tool input schema (discriminated union — add 2 kinds)
   - [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — switch/case shape (add 2 cases)
   - [ ] `one.ie/web/src/components/auth/PasskeyCreate.tsx` — props + mode='register' shape
   - [ ] `one.ie/web/src/components/auth/EmailContinueForm.tsx` — props + redirect prop
   - [ ] `one.ie/web/src/components/auth/GoogleButton.tsx` — props
   - [ ] `one.ie/web/src/components/auth/WalletSignIn.tsx` — props
   - [ ] `one.ie/web/src/components/pay/StripeProvider.tsx` — clientSecret prop
   - [ ] `one.ie/web/src/components/pay/StripeCheckoutForm.tsx` — amount, onSuccess, onError shape
   - [ ] `one.ie/web/src/actions/billing.ts` — `createCheckoutSession` signature
   - [ ] `one.ie/web/src/pages/api/webhook/stripe.ts` — current handler shape (where to write lifecycle='owner')
   - [ ] `one.ie/web/src/pages/api/onboarding.ts` (or wherever) — `step` param handling
   - [ ] `one.ie/web/src/components/onboarding/OnboardingFlow.tsx` — what 3-step does today (for in-chat re-emit)

2. **Primitive-inventory recon**
   - [ ] `one.ie/web/src/components/cards/` — every card renderer's `onAction` callback shape (mirror it)
   - [ ] `one.ie/web/src/lib/ui-signal.ts` — `emitClick` event names already in use (don't collide)

### W2 — Decide  [Opus]

- [ ] **Compose-or-construct verdict**

  | Proposed file | Closest existing primitive | Gap | Verdict |
  |---|---|---|---|
  | `web/src/components/cards/SignupCard.tsx` | `auth/SignInWithAnything.tsx` (partial — has MCPConsent slots) | not a chat card; doesn't do email-on-blur lead capture; doesn't morph to `result` on success | **new** (~140 LOC composing PasskeyCreate + EmailContinueForm + GoogleButton + WalletSignIn) |
  | `web/src/components/cards/CheckoutCard.tsx` | `pay/StripeCheckoutForm.tsx` direct | not a chat card; doesn't expand sheet on mobile; doesn't emit ui:home:checkout-success | **new** (~120 LOC composing StripeProvider + StripeCheckoutForm) |
  | `tests/e2e/home-chat-c3.test.ts` | none | no test covers signup/checkout card render + agent tool flow | **new** |

  Two existing-file edits:
  - `lib/cards.ts` — add `signup` + `checkout` to CardData union (~20 LOC)
  - `pages/api/chat.ts` — add 2 kinds to emit_card Zod discriminator + add `create_checkout_session` tool (~50 LOC)
  - `components/chat/MessageRenderer.tsx` — add 2 cases (~10 LOC)

- [ ] **Slot map**

  | Primitive | Slot | This cycle puts in it |
  |---|---|---|
  | `PasskeyCreate` | primary CTA in SignupCard | mode='register' |
  | `EmailContinueForm` | secondary in SignupCard | redirect prop passed through |
  | `GoogleButton` | tertiary in SignupCard | (default props) |
  | `WalletSignIn` | "More options" reveal | (default) |
  | `StripeProvider` | wrapper in CheckoutCard | clientSecret from emit |
  | `StripeCheckoutForm` | inside StripeProvider | amount + handlers |

- [ ] **Architectural decisions**
  - [ ] `signup` card data shape: `{ headline, subhead?, redirect?, methods?, captureLead? }` per `plans/home-chat.md`
  - [ ] `checkout` card data shape: `{ amount, currency, label, sku, clientSecret, successPrompt? }`
  - [ ] `create_checkout_session` server tool: takes `{sku, quantity}`, calls `billing.ts.createCheckoutSession`, returns `{sku, quantity, clientSecret, amount, label}` — agent's next `emit_card` consumes the result
  - [ ] Email-on-blur in SignupCard: regex match + 1.5s pause OR blur → POST `/api/leads` (defined in C2); fire `emitClick('ui:home:lead-capture', { email, persona, team })`
  - [ ] Mobile checkout: `useEffect` dispatches `one:chat-mode=wide` on mount when matchMedia matches `(max-width: 768px)` — pattern from `chat-integrated.md`
  - [ ] Stripe webhook (`api/webhook/stripe.ts`): on `payment_intent.succeeded`, update D1 actor → `lifecycle='owner'`, `credits=SKU_CREDITS[sku] * quantity`; emit `signal:purchase.completed` tagged to visitor `actor_id`
  - [ ] In-chat onboarding: 4-turn flow lives in the agent system prompt (Cycle 1 home.md gets an addendum here OR a sibling agent file `home-onboarding.md`). DECIDE: addendum is simpler; same agent owns the whole journey
  - [ ] 3 SKU price IDs read from env: `STRIPE_PRICE_CREDITS_5M`, `STRIPE_PRICE_CREDITS_25M`, `STRIPE_PRICE_CREDITS_100M`

- [ ] **Doc-plan**

  | Trigger | Doc target | Action |
  |---|---|---|
  | new primitive (2 card kinds) | `plans/dictionary.md` | add `signup`, `checkout` to CardData kinds row |
  | new server tool | `plans/agent-api.md` § fourteen operations | add `create_checkout_session` (or justify under emit_card's umbrella) |
  | public surface change (cards.ts union extended) | `one.ie/web/src/components/cards/CLAUDE.md` (if exists) | append signup + checkout rows |
  | feature doc | `plans/home-chat.md` § Three truly new components | tick after build |
  | agent update | `one.ie/web/agents/home.md` (from C1) | rename inline — add onboarding turns + signup/checkout card references |

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `one.ie/web/src/components/cards/SignupCard.tsx` — new file ~140 LOC
- [ ] `one.ie/web/src/components/cards/CheckoutCard.tsx` — new file ~120 LOC
- [ ] `tests/e2e/home-chat-c3.test.ts` — new file ~180 LOC
- [ ] `plans/dictionary.md` — add card kind rows
- [ ] `plans/home-chat.md` — tick C3 line items

**W3b — dependent (after W3a — these files import from W3a or reference each other):**
- [ ] `one.ie/web/src/lib/cards.ts` — extend CardData union with `signup` + `checkout`
- [ ] `one.ie/web/src/pages/api/chat.ts` — extend `emit_card` Zod discriminator; add `create_checkout_session` tool
- [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — add 2 cases dispatching SignupCard + CheckoutCard
- [ ] `one.ie/web/agents/home.md` (from C1) — append onboarding 4-turn script + signup/checkout references in the seed map
- [ ] `one.ie/web/src/pages/api/webhook/stripe.ts` — on success, update lifecycle + emit `signal:purchase.completed`

### W4 — Verify  [Haiku × 5 — complex tier]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/home-chat-c3.test.ts` exits 0
- [ ] Manual `/browser` smoke: load `/`, click §4 hire chip → signup card renders with PasskeyCreate visible; click §20 "Lock these in" → checkout card renders with Stripe Element mounted
- [ ] Stripe test card `4242 4242 4242 4242` in dev produces a webhook delivery (test mode) and D1 `actors.lifecycle = 'owner'` flip
- [ ] **Reuse audit**
  - [ ] `SignupCard` imports `PasskeyCreate`, `EmailContinueForm`, `GoogleButton` (no parallel auth implementation)
  - [ ] `CheckoutCard` imports `StripeProvider`, `StripeCheckoutForm` (no parallel Stripe call)
  - [ ] `wc -l` totals: `SignupCard.tsx ≤ 160`, `CheckoutCard.tsx ≤ 140`
  - [ ] `delta_loc_net ≤ +350` (most new LOC; existing-file edits offset by reusing primitives)
- [ ] 5-Haiku rubric: security ≥ 0.90 (Stripe + lead capture) · stability ≥ 0.85 · simplicity ≥ 0.80 · speed ≥ 0.80 · composite ≥ 0.65
- [ ] No adversarial severity > 0.5

Report: `delta_tsc=±N  delta_loc=+~340  new_files=3  edits=5  primitives_composed=5`

---

## See also

- `plans/home-chat.md` — the architectural spec this todo implements (24 sections × 4 init patterns × 7 lifecycle states × 3 truly new components)
- `plans/home.md` — the 24-section narrative the chat answers
- `plans/chat-integrated.md` — the three-view-mode action layer this plan operates inside
- `one.ie/web/src/components/Chat.tsx` lines 70-95 (rich prompts), 343-367 (seed listener) — load-bearing
- `one.ie/web/src/pages/api/chat.ts` lines 220-310 (R2 agent loader), ~630 (emit_card tool) — load-bearing
- `plans/dictionary.md` — canonical names (always)
- `plans/rubrics.md` — scoring bands (always)
