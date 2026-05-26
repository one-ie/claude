---
name: home-chat
description: Specialize the right-rail chat on `/` so every "Show me" seed answers with the BEST existing UI we ship today — cherry-picked across cards/, chat/cards/, funnel/, dashboard/, cro/, pay/, auth/. The chat showcases Marketing · Sales · Service live, captures the visitor as a lead, and signs them up inline.
status: planning
owner: web
mode: mixed
lifecycle: construction

classifier:
  spec_locked:    Y    # home.md owns the 24 sections; this owns the chat half
  variance_known: Y    # emit_card already wired; 16 card kinds shipping; auth flows shipping
  exit_scalar:    Y    # 10-click acceptance test ends with a real signup + onboarding redirect
  files_known:    Y    # 1 new agent .md, 1 rich-prompts file, 2 new card kinds, ~40 LOC in 3 existing files

source_of_truth:
  - plans/home.md
  - plans/chat-integrated.md
  - one.ie/web/src/pages/api/chat.ts             # emit_card tool already wired (line ~600); discriminated-union schema
  - one.ie/web/src/components/chat/MessageRenderer.tsx   # 16 card kinds already dispatched
  - one.ie/web/src/components/Chat.tsx           # __chatRichPrompts + one:chat-seed consumer (lines 70-95, 344-367)
  - one.ie/web/src/lib/cards.ts                  # CardData union — 16 kinds shipping
  - one.ie/web/agents/                           # NEW: web/agents/home.md is the only new agent file
  - text/01-brand.md … text/16-speed.md          # claims and numbers each card cites

existing_primitives:
  # Already shipping — 16 card kinds the agent can call right now via emit_card
  - components/cards/AgentPreviewCard            # — agent named/status — used for §4-§6 team demo
  - components/cards/CompareCard                 # — A/B value comparison — used for §3 agency pitch, §16 learning, §19 escrow
  - components/cards/BrandPalette                # — 6-token swatch — used for §7 brand
  - components/cards/PriceCard                   # — labeled price + CTA — used for §20 math, §24 final CTA
  - components/cards/MarketplaceMini             # — agent listing — used for §9 skills
  - components/cards/SkillToggleRow              # — toggle a skill — used for §9 skills demo
  - components/cards/TraceMini                   # — signal/depth/outcome — used for §6 service path, §16 hardened paths
  - components/cards/VerifyCard                  # — claim + check rows — used for §5 BANT, §22 FAQ
  - components/cards/OnboardingChecklist         # — 4-step checklist — used post-signup
  - components/cards/DeployStatusCard            # — deploy ms + state — used for §8 agents, §17 development
  - components/cards/ResultCard                  # — title/ok/detail — used for tool confirmations
  - components/cards/EmptyStateCard              # — fallback for unrecognized seeds
  - components/cards/ChoiceChips                 # — discrete next-step picker
  - components/chat/cards/CampaignCardRenderer   # — already used by chat; live campaign with audience/budget/agents — the marketing showcase

  # Already shipping — best-of-breed UI we already have and should reuse inside cards
  - components/TeamOrgChart                      # — 27 roles, rendered three times on / already; the visual centerpiece
  - components/SpeedReceipt                      # — live page-load + first-token receipt; reuses for §18
  - components/funnel/FunnelChart                # — Lifecycle stages + drop-off — used inside §5 sales demo + §15 analytics
  - components/funnel/LiveEventStream            # — animated event ticker — used inside §10/§13 activity feed
  - components/funnel/EngagementTrendCard        # — trend chart — used inside §6 service CSAT
  - components/dashboard/RingTriple              # — 3-ring KPI — used inside §18 speed
  - components/dashboard/Sparkline               # — micro-trend — used inside multiple cards
  - components/dashboard/ArcPath                 # — animated arc — used inside §16 learning loop
  - components/dashboard/HotAccounts             # — ranked list — used inside §14 CRM
  - components/dashboard/LivePulseDot            # — live indicator
  - components/cro/ComparisonTable               # — production comparison table — already used on landing
  - components/cro/Testimonials                  # — quote carousel
  - components/cro/PricingSection                # — 3-tier price (could embed in §20)
  - components/pay/StripeCheckoutForm            # — Stripe Element (amount/onSuccess/onError) — production-tested in PayPanel
  - components/pay/StripeProvider                # — Elements wrapper — production-tested
  - components/auth/PasskeyCreate                # — full Touch ID + recovery-phrase ceremony
  - components/auth/EmailContinueForm            # — magic-link + WebAuthn autofill
  - components/auth/GoogleButton                 # — Google sign-in
  - components/auth/WalletSignIn                 # — wallet sign-in
  - components/auth/SignInWithAnything           # — tabbed unified surface (partial: MCPConsent + BrandLoader slots forward-declared)
  - components/onboarding/OnboardingFlow         # — 3-step name/color/agent, posts /api/onboarding (shipping)

  # Chat plumbing already wired
  - Chat.tsx:cardActionToMessage                 # — card click → user message → conversation advances
  - Chat.tsx:__chatRichPrompts                   # — page-scoped {id → full prompt} registry; chips/seeds with an `id` fire the rich prompt
  - Chat.tsx:one:chat-seed listener (344-367)    # — already consumes seeds + opens the rail in wide mode
  - api/chat.ts:emit_card                        # — tool already takes the 16-kind discriminated union and emits frames
  - api/chat.ts:agent.md loader                  # — reads {slug}/agents/{agentId}.md from R2 with frontmatter tools whitelist
  - api/onboarding.ts                            # — endpoint exists; OnboardingFlow already posts to it
---

# home-chat — what changes, in one paragraph

The right rail on `/` today runs the default chat prompt and answers in paragraphs. **Nothing else.** The 16 card kinds, the `emit_card` tool, the `__chatRichPrompts` registry, the auth flows, the Stripe form, the org chart, the funnel charts — all ship today and the home rail uses none of them. This plan changes one thing: it gives the home rail a dedicated agent (`web/agents/home.md`) with a tool whitelist and a system prompt that, for each of the 24 home-page seeds, calls `emit_card` with a kind we already render — and for two seeds (signup, checkout) emits one of two new card kinds that compose existing auth + Stripe components. The journey ends with the visitor as a lead in TypeDB + a session cookie, without leaving the conversation.

---

## Cherry-picking the best UI we already ship

The home page already mounts `TeamOrgChart` three times (§4 Marketing · §5 Sales · §6 Service) — the visual centerpiece of `home.md`. The chat half mirrors that: when a visitor clicks **"Show me [team] in action"**, the rail streams a **three-card demo** that uses the best UI primitives we have. Cherry-picked per team:

### §4 Marketing — the live campaign demo

Three sequential card emits, ~800ms apart, on the one seed:

| Card kind (existing) | What it renders | Reuses |
|---|---|---|
| `brand-palette` | The client's 6-token palette materializing live | `cards/BrandPalette.tsx` — production card |
| `campaign` *(via CampaignCardRenderer)* | A real campaign card: persona, audience reach (`{ type: 'count', value: 12_400 }`), 4 agents working (idle/working/done states), budget bar, warnings | `chat/cards/CampaignCardRenderer.tsx` — already wired in `MessageRenderer.tsx` |
| `marketplace-mini` | The `brand-voice-check` skill earning £840 in margin (citation: `text/06-skills.md`) | `cards/MarketplaceMini.tsx` |

Final chip row: **"Hire this team — £800k payroll, ~£400/mo substrate"** → fires the signup card.

### §5 Sales — the inbound-lead qualification demo

| Card kind (existing) | What it renders | Reuses |
|---|---|---|
| Plain assistant message (LiveEventStream nested) | "47-second first response: a tier-1 inbound lead just arrived" with `<LiveEventStream agentId="home-sales-demo">` ticking | `funnel/LiveEventStream.tsx` |
| `verify` | BANT checks: Budget ✓ · Authority ✓ · Need ✓ · Timeline ✗ (subject: "Inbound — Kate from Acme") | `cards/VerifyCard.tsx` |
| `price` | A draft proposal: $4,800/mo with CTA "Send for approval" — chip-fires next msg | `cards/PriceCard.tsx` |

Final chip row: **"Hire this team — pipeline filled day one"** → fires the signup card.

### §6 Service — the resolution demo

| Card kind (existing) | What it renders | Reuses |
|---|---|---|
| `trace-mini` | Signal: "Refund request — order #4421" · depth: 3 · outcome: `mark` | `cards/TraceMini.tsx` |
| `result` | "Refund processed in 14 seconds — no human required" with `ok: true` | `cards/ResultCard.tsx` |
| Plain message embedding `<EngagementTrendCard>` | CSAT week-1 4.1 → week-12 4.7 sparkline | `funnel/EngagementTrendCard.tsx` |

Final chip row: **"Hire this team — repeat queries drop 40-60%"** → fires the signup card.

All three demos are scripted on the agent side (system prompt instructs three sequential `emit_card` calls with the exact JSON), zero new server logic. **What ships today renders all of this.** The only thing missing is the agent that knows to do it.

---

## The 7-state lifecycle — the actor row at every step

The substrate is already the CRM (`text/12-crm.md` — "Actors as records, no separate CRM seat"). The visitor IS an actor; the question is what `lifecycle` they're at. Seven states, six transitions, each tied to one substrate event the home agent or signup card writes:

```
  anonymous ──signal──► engaged ──signal──► qualified ──signal──► lead ──mark──► verified ──harden──► active ──harden──► customer
   (cookie)    seed     (persona)  team     (intent)    email      (link        (Touch ID         (brand+   Stripe charge
                                  demo'd               on blur     clicked       done)             agent
                                                       /api/leads  /verify       /api/onboarding   set)
                                                                   -magic-link)
```

| # | State | Trigger | Substrate write | What changes in the chat header |
|---|---|---|---|---|
| 1 | **anonymous** | First page hit | `actor:visitor_hash` row exists from middleware | `● anonymous` |
| 2 | **engaged** | First seed click | `signal:home.seed.<id>` on visitor actor + `persona?` attr | `● engaged` |
| 3 | **qualified** | Team demo finished OR math card interacted | `signal:home.team_intent=<dept>` OR `signal:home.math_run` | `● qualified — Marketing` |
| 4 | **lead** | Email blurred in signup card → POST `/api/leads` | `actor.lifecycle = 'lead'`, `actor.email`, magic-link queued | `● lead — link sent to t…@one.ie` |
| 5 | **verified** | Passkey created OR magic link clicked | `mark` on the lead path; session cookie set | `● verified — welcome back` |
| 6 | **active** | In-chat onboarding finished (brand + first agent saved) | `harden` on the activation path; `actor.lifecycle = 'active'`; agent .md in R2 | `● your workspace — acme.one.ie` |
| 7 | **customer** | Stripe charge succeeds | `harden` on the customer path; `actor.lifecycle = 'owner'` | `● customer — 5M credits` |

Two important properties:

- **Lead is captured one state BEFORE verification.** Email-on-blur writes the lead row before the visitor finishes auth. If they bounce, we still have them (magic-link + persona + team + math). Most visitors won't sign up on first visit; this is the only state that recovers them.
- **Backwards transitions are not allowed.** Once verified, you can't go back to lead. Once customer, you can't go back to active. The substrate enforces — `harden` paths don't fade.

A small `LifecycleBadge` (~50 LOC, the third new component) sits at the top of the chat rail. It morphs through the 7 labels as the session advances. **The badge is the visitor's only HUD** — they always know what state they're in without thinking about it.

---

## How the chat is initiated from the main content

Four always-on initiation patterns + two ambient ones. Restrained — the chat should feel summoned, never pushy.

### Always-on (visitor-driven)

| # | Pattern | Where on the page | What fires |
|---|---|---|---|
| 1 | `ChatSeedButton` click | Bottom-right of every section's copy block (one per §, two on §4-§6) | `__chatRichPrompts[id]` → `one:chat-seed` event → agent emit |
| 2 | Persona chip (§3) | Three chips in §3: agency / business / consultant | Sets `persona` on the seed event; agent re-anchors tone for the whole thread |
| 3 | Role card click inside `TeamOrgChart` (§4·§5·§6) | Any of the 27 role cards (already on page per `home.md`) | Role-specific seed: `home:role:copywriter` → "Show me what the Copywriter actually does for the dentist client" → agent emits a role-specific card |
| 4 | FAQ row click (§22) | Each FAQ row | Each row is itself a `ChatSeedButton` with `id=home:s22:<rowId>` → agent emits a `verify` card with the claim + 3 evidence rows |

### Ambient (page-driven, dismissible)

| # | Pattern | When it fires | What appears | Dismiss |
|---|---|---|---|---|
| 5 | **Dwell chip** | Reader scrolls into §4 and dwells > 8s without clicking | A single chip at the TOP of the chat rail: *"Marketing — see them work? →"* | Clicking dismisses; chip never re-appears in the thread |
| 6 | **Bottom-of-page nudge** | Reader reaches §24 scroll-bottom without engaging chat once | One card emitted at thread head: *"Have a question before you go?"* with `choice-chips` of the 3 top FAQs | Auto-fades after 12s |

**No popups. No exit-intent modals. No tooltips covering content.** Everything happens INSIDE the chat rail that's already on screen. The chat is the modal.

Wiring: dwell detection uses `IntersectionObserver` already running in `Reveal.astro`; the bottom-of-page nudge listens for `scroll` + `document.body.scrollHeight - window.innerHeight - window.scrollY < 24`. ~30 LOC in a new `useChatNudge.ts` hook called from `index.astro`.

---

## Lead capture — the explicit design (this has to be right)

Lead capture happens in **one place** — the `signup` card — and at **one moment** — email field blur OR a 1.5s typing pause. Everywhere else, the visitor is anonymous-but-tracked (state 1-3).

### The signup card, designed

```
┌──────────────────────────────────────────────────────┐
│  Keep your workforce                                  │
│  Marketing · Sales · Service — saved to your email   │
│                                                        │
│  [ your.email@company.com           ]  ← on blur:    │
│                                          ✓ saved      │
│  ┌────────────────────────────────────────────┐      │
│  │  ⚡ Sign in with Touch ID (5 seconds)       │ ←   │
│  └────────────────────────────────────────────┘ primary
│                                                        │
│  or  ⓒ Google  ·  ✉ Email link  ·  ⓦ Wallet         │
│                                                        │
│  No password. No seed phrase. Touch ID only.         │
│  text/15-security.md — Secure Enclave-rooted         │
└──────────────────────────────────────────────────────┘
```

### Three lead-capture moments inside this one card

1. **First keystroke in email field** — `LifecycleBadge` flips to `● typing…` (visual only, no write).
2. **Blur OR 1.5s pause after a valid email regex match** — `fetch('/api/leads', { method: 'POST', body: { email, visitor_hash, persona, team, math, source: 'home-chat' } })`. Server-side: idempotent upsert into `actors` table with `lifecycle: 'lead'`; queues magic-link email; emits `signal:lead.captured`. Badge flips to `● lead — link sent`. **No redirect, no page reload.** The visitor stays in the conversation.
3. **Passkey or Google or magic-link clicked** — full auth; session cookie set; the same actor row upgrades to `lifecycle: 'verified'`. Badge flips to `● verified`. Card morphs to a `result` ok=true. Agent's next message emits the `onboarding-checklist`.

If the visitor bounces between steps 2 and 3, **we still have them** — they receive the magic-link in email and can return any time. The agent's last card is preserved in the thread so when they come back, the conversation resumes exactly where they left it.

### The new `/api/leads` endpoint (~40 LOC)

```ts
// web/src/pages/api/leads.ts
export const POST: APIRoute = async ({ request, locals }) => {
  const { email, visitor_hash, persona, team, math, source } = await request.json()
  if (!isValidEmail(email)) return new Response('invalid email', { status: 400 })
  const env = locals.runtime.env
  const id = `lead_${hash(email)}`
  await env.DB.prepare(`
    INSERT INTO actors (id, email, visitor_hash, lifecycle, persona, attrs, source, created_at)
    VALUES (?, ?, ?, 'lead', ?, ?, ?, datetime('now'))
    ON CONFLICT(email) DO UPDATE SET
      visitor_hash = COALESCE(actors.visitor_hash, excluded.visitor_hash),
      persona      = COALESCE(actors.persona, excluded.persona),
      attrs        = json_patch(COALESCE(actors.attrs, '{}'), excluded.attrs)
  `).bind(id, email, visitor_hash, persona ?? null, JSON.stringify({ team, math }), source).run()
  await queueMagicLink(env, email, { redirect: `/dashboard?welcome=1&lead=${id}` })
  return Response.json({ ok: true, lead_id: id })
}
```

Idempotent on email (visitor can type, edit, re-blur — only one row). Carries `visitor_hash` so the anonymous state-1-3 history attaches to the lead row. Magic-link redirect carries `?lead=` so on click we know which lead became verified.

---

## In-chat onboarding — the card sequence after signup

The existing `OnboardingFlow` component is a 3-step form on `/get-yours`. In chat, we don't mount it — we **re-emit it as 4 sequential card turns**, one step per turn, because chat-native UX is one decision per message.

| Turn | Agent says (≤ 2 sentences) | Card emitted | User input | What's saved |
|---|---|---|---|---|
| 1 | "Welcome. Let's pick your name — it'll appear on every invoice and email." | `signup` morphed to a single text input (re-uses email field shape) | Display name | `actor.display_name` |
| 2 | "Pick your brand colour. The whole platform will tint to it." | `brand-palette` (interactive — clicking a swatch saves immediately) | 6 token picks | `workspace.tokens` (already endpoint-supported by `/api/onboarding`) |
| 3 | "Now your first agent. Pick the team you saw earlier?" | `choice-chips` Marketing · Sales · Service | One chip | Server scaffolds `{slug}/agents/{dept-director}.md` in R2 |
| 4 | "Done. Your workspace is `{slug}.one.ie` — your agent is live." | `result` ok=true + `deploy-status` state=live ms=107000 (the 107s deploy from `text/16-speed.md`) | (none) | `actor.lifecycle = 'active'`; `LifecycleBadge` flips to `● your workspace` |

After turn 4 the agent's next message: *"Ready to mark it up and distribute? Run the math →"* with a chip back to §20. If the visitor doesn't continue, they're saved as `active` — they can return any time.

All four turns use the existing `/api/onboarding` endpoint (already shipping, accepts `slug, displayName, tokens, agentName, agentOneLiner, agentPrompt, skip`). The chat just feeds it piecewise instead of all at once.

---

## The chat is a lead funnel — four conversion moments (recap)

| Moment | State transition | Trigger | Card | Capture |
|---|---|---|---|---|
| **1. Qualification** | engaged → qualified | First team demo ends OR §20 math interacted | `choice-chips` "Which client first?" | `signal:home.team_intent` on visitor |
| **2. Lead capture** | qualified → lead | Email blur in signup card | `signup` *(NEW)* | `actor.lifecycle = 'lead'` + magic-link queued |
| **3. Verification** | lead → verified | Touch ID OR magic-link click | inline morph of `signup` card | session cookie + `actor.lifecycle = 'verified'` |
| **4. Activation** | verified → active | 4-turn in-chat onboarding | sequence above | `actor.lifecycle = 'active'` + agent .md in R2 |
| **5. Purchase** | active → customer | §20 → checkout | `checkout` *(NEW)* | Stripe charge + `actor.lifecycle = 'owner'` |

Most visitors stop at moment 2 or 3 — that's fine. **Moment 2 is the only one that matters for the funnel; moments 3-5 can happen any time later.**

---

## The 3 truly new components

Thin compositions of existing primitives. Total ~330 LOC across three files.

### `signup` card

Composes `SignInWithAnything`-style options in one card:

```ts
// lib/cards.ts — add to CardData union
| {
    kind: 'signup'
    headline: string                                    // e.g. "Keep your workforce — sign in"
    subhead?: string
    redirect?: string                                   // post-success redirect — default '/dashboard'
    methods?: ('passkey'|'email'|'google'|'wallet')[]  // default: ['passkey','email','google']
    captureLead?: { email?: string; persona?: string; team?: string }   // pre-fills + writes lead row before any auth completes
  }
```

Renderer: `components/cards/SignupCard.tsx` — wraps:
- `<PasskeyCreate mode="register" />` (primary CTA — 5s wallet per `text/15-security.md`)
- `<EmailContinueForm redirect={redirect} />` (secondary — magic link)
- `<GoogleButton />` (tertiary)
- `<WalletSignIn />` (hidden behind "More options")

On email-blur **before** the user submits, fire `emitClick('ui:home:lead-capture', { email, persona, team })` → POST `/api/leads` (new tiny endpoint, ~30 LOC, inserts actor row with `lifecycle: 'lead'`). This means **we capture the lead the moment they type their email**, even if they bounce from auth. The endpoint is idempotent on email.

### `checkout` card — Stripe streams in, the visitor actually buys

This is the conversion endpoint. **A real Stripe Element streams into the chat thread; the visitor enters card details and completes a real purchase without leaving the conversation.** Existing `StripeProvider` + `StripeCheckoutForm` (production-tested inside `PayPanel`) do the heavy lifting; the card is the conduit.

```ts
| {
    kind: 'checkout'
    amount: number                                    // dollars (500 = 5M credits; 50000 = 100-client agency starter)
    currency: 'USD'
    label: string                                     // e.g. "5,000,000 credits — your workforce"
    sku: 'credits-5m' | 'credits-25m' | 'credits-100m' // catalog reference; maps to Stripe price IDs
    clientSecret: string                              // arrives with the streamed tool-output frame
    successPrompt?: string                            // optional next-turn seed, e.g. "Distribute these to my first 5 clients"
  }
```

**Renderer: `components/cards/CheckoutCard.tsx`** (~120 LOC)

```tsx
import { Elements } from '@stripe/react-stripe-js'
import { StripeProvider } from '@/components/pay/StripeProvider'
import { StripeCheckoutForm } from '@/components/pay/StripeCheckoutForm'
import { emitClick } from '@/lib/ui-signal'
import { useLifecycle } from '@/lib/use-lifecycle'

export function CheckoutCard({ data, onAction }: CardProps) {
  const { setLifecycle } = useLifecycle()
  const d = data as Extract<CardData, { kind: 'checkout' }>

  // Mobile: expand chat sheet to 90vh so the Stripe Element has room (per chat-integrated.md)
  useEffect(() => {
    if (window.matchMedia('(max-width: 768px)').matches) {
      window.dispatchEvent(new CustomEvent('one:chat-mode', { detail: 'wide' }))
    }
  }, [])

  return (
    <article className="bg-background border rounded-2xl p-5" style={{ borderColor: 'var(--color-border)', boxShadow: 'var(--shadow-card)' }}>
      <header className="mb-4">
        <p className="text-sm text-font/60">{d.label}</p>
        <p className="text-2xl font-bold mt-1">${d.amount.toLocaleString()} <span className="text-base font-normal text-font/60">{d.currency}</span></p>
      </header>

      <StripeProvider clientSecret={d.clientSecret}>
        <StripeCheckoutForm
          amount={d.amount}
          onSuccess={(paymentIntentId) => {
            emitClick('ui:home:checkout-success', { sku: d.sku, amount: d.amount, paymentIntentId })
            setLifecycle('customer')                                        // badge → ● customer
            onAction('pay-success', { paymentIntentId, sku: d.sku, amount: d.amount, successPrompt: d.successPrompt })
          }}
          onError={(msg) => {
            emitClick('ui:home:checkout-error', { error: msg })
            onAction('pay-error', { error: msg })                           // agent surfaces a `result` ok=false card with retry option
          }}
        />
      </StripeProvider>

      <p className="mt-3 text-xs text-font/40">Secured by Stripe. No card data touches our servers.</p>
    </article>
  )
}
```

**Server side — the streaming session creation**

The agent does **not** invent a `client_secret`. It calls a dedicated tool that hits `billing.ts.createCheckoutSession` (already exists), then `emit_card` with the result. This means the secret is server-minted under the visitor's session, not LLM-generated.

```ts
// Added to chat.ts tool list — alongside emit_card
create_checkout_session: tool({
  description: 'Create a real Stripe payment intent for one of the catalog SKUs. Call this only after the visitor has explicitly said they want to buy. The result includes a client_secret that you MUST then pass into emit_card({kind:"checkout"}).',
  inputSchema: z.object({
    sku: z.enum(['credits-5m', 'credits-25m', 'credits-100m']),
    quantity: z.number().int().min(1).max(100).default(1),
  }),
  execute: async ({ sku, quantity }, { request }) => {
    const env = request.env
    const session = await createCheckoutSession(env, {
      priceId: PRICE_IDS[sku],                                    // env.STRIPE_PRICE_CREDITS_5M etc.
      quantity,
      mode: 'payment',
      clientReferenceId: request.headers.get('x-actor-id') ?? request.headers.get('x-visitor-hash'),
      metadata: { source: 'home-chat', sku },
    })
    return {
      sku, quantity,
      clientSecret: session.client_secret,
      amount: SKU_PRICES[sku] * quantity,
      label: SKU_LABELS[sku],
    }
  },
}),
```

The agent's pattern is fixed: `create_checkout_session` → `emit_card({ kind: 'checkout', ...result })`. The card data streams over the same SSE channel as every other emit — `clientSecret` lands in the frame payload; React mounts the Stripe `<Elements>` provider; the Element renders inline.

**The webhook → conversation advance loop**

Stripe `payment_intent.succeeded` already routes through `pages/api/webhook/stripe.ts` (existing). On success:

1. Webhook updates `actors` row: `lifecycle = 'owner'`, `credits = SKU_CREDITS[sku] * quantity`.
2. Webhook writes a `signal:purchase.completed` event tagged with the visitor's `actor_id`.
3. The chat session subscribes to this signal via the existing `WsHub` DO (per `web/CLAUDE.md` middleware).
4. On signal receipt, the agent's next-turn system message is augmented: *"The payment landed. Send a celebration card and the distribution checklist."*
5. Next user-side render shows: `result` ok=true ("$500 received — 5,000,000 credits in your workspace") then an `onboarding-checklist` with 5 distribution steps (mark up · pick first client · brand their workspace · send invite · go live).

**Two important things this design gets right:**

1. **The visitor never leaves the chat.** No redirect to `/checkout`, no popup, no Stripe-hosted page. The Element renders in the same scroll position as every other card. The agent's next message arrives in the same thread once the webhook fires.
2. **It's real money, not a demo.** Production Stripe keys, real card processing. Tested with test cards (`4242…`) in `bun run dev:wrangler`; the same code path handles live cards on production. Refunds, declines, 3DS challenges — all handled by the existing `StripeCheckoutForm` which already runs in production at `/pay`.

**Three SKUs in the catalog** (matched to `text/16-speed.md` math + persona-tailored):

| SKU | Stripe price | Visible price | Credits | Targeted persona |
|---|---|---|---|---|
| `credits-5m` | env.STRIPE_PRICE_CREDITS_5M | $500 | 5,000,000 | business owner / consultant first purchase |
| `credits-25m` | env.STRIPE_PRICE_CREDITS_25M | $2,250 | 25,000,000 | agency owner first purchase |
| `credits-100m` | env.STRIPE_PRICE_CREDITS_100M | $8,000 | 100,000,000 | agency scaling, 100+ clients |

The agent picks the SKU based on `persona` and `team_intent` carried through the thread. The visitor can override via a `choice-chips` card before the checkout streams in: *"Which package?"* — three chips, one tap, then checkout.

**Failure modes handled:**

| Failure | Recovery |
|---|---|
| `StripeProvider` fails to init | `CheckoutCard` shows `result` ok=false + retry chip; agent's next emit is a fresh `create_checkout_session` call |
| Card declined / 3DS failed | `StripeCheckoutForm.onError` fires → `result` ok=false with the message; agent emits a `choice-chips` "try another card · try a different SKU · talk to founder" |
| User closes tab mid-payment | `lifecycle` stays at `verified`; lead row keeps `pending_checkout` attr; magic-link return resumes the chat with the same `checkout` card re-emitted (idempotent on visitor session) |
| Webhook delayed > 5s | `StripeCheckoutForm.onSuccess` flips badge to `customer` optimistically; backend reconciles on webhook arrival; if webhook never arrives, a 60s reconciliation worker (existing in `web/src/workers/`) catches it |

Both kinds: add to `cards.ts` union, add to the `emit_card` Zod discriminator in `chat.ts`, add a `case` in `MessageRenderer.tsx`. Three edits, ~40 LOC total in existing files.

### `LifecycleBadge` (the chat-header HUD)

`components/chat/LifecycleBadge.tsx` — ~50 LOC. Renders one pill at the top of the chat rail, morphing through the 7 states. Reads from a single source: `useLifecycle()` (new hook, ~40 LOC) that subscribes to `one:lifecycle-change` events and reflects the current `actor.lifecycle` value.

```tsx
<div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-foreground border" style={{ borderColor: 'var(--color-border)' }}>
  <span className={cn('w-2 h-2 rounded-full', toneFor(state))} />
  <span className="text-xs text-font/80">{LABELS[state]}</span>
</div>
```

Tones: anonymous=neutral · engaged=primary/40 · qualified=primary · lead=tertiary · verified=secondary · active=secondary (solid) · customer=tertiary (solid). The badge IS the visitor's progress bar — no separate stepper UI.

The agent emits a `one:lifecycle-change` event after every successful transition (signup card on email-blur, after passkey success, after onboarding turn 4, after Stripe success). Three lines per emit point — see Cycle 2 below.

---

## The home agent — one markdown file

`web/agents/home.md` is the entire new agent. Per `web/agents/CLAUDE.md`, agents are markdown loaded from R2; per `chat.ts:agent.md loader`, the frontmatter `tools:` list is the whitelist. The home agent uses only existing tools + the two new kinds.

```markdown
---
id: home
name: ONE — workforce demo
surface: /
model: openrouter/anthropic/claude-haiku-4-5
fallback: openrouter/google/gemini-2.0-flash-001
tools:
  - emit_card                      # already wired — fires the 16+2 kinds
  - emit_chips                     # already wired — discrete next-steps
voice: |
  Be Anthony. Direct. No "great question." Every reply: ≤ 2 sentences of framing then one emit_card. Never two cards per turn. Card CTAs carry the conversation forward (cardActionToMessage already maps card clicks to follow-up user messages).
guardrails:
  - first-token must beat 200ms p50 — model is haiku, no chain-of-thought
  - if the visitor's seed doesn't match a known rich-prompt id, answer in prose + a single follow-up question — never invent a card
  - signup card fires after the FIRST high-intent moment (team-hire click, math interaction, "I'm ready"); never on first page-load
---

# Home agent — system prompt

You are the right rail of one.ie. Visitor scrolls a 24-section page about an AI workforce on the left. Reply only when seeded.

## The 24-seed map

The visitor's seed text always carries an `id` like `home:s4:hire-marketing`. Look up the rich-prompt by id (already injected via __chatRichPrompts). Each id maps to ONE card-emit pattern:

| Section | Seed id | First emit_card call (cards from existing 16 + 2 new) | Then |
|---|---|---|---|
| §1 hero | home:s1:show-team | choice-chips: [Marketing, Sales, Service] | each chip → §4/§5/§6 demo |
| §3 agency | home:s3:agency | compare a={"Current cost-to-serve","£2M payroll"} b={"ONE substrate","~£400/client/mo"} | chip: "Run the math" → §20 |
| §3 business | home:s3:business | choice-chips: [Marketing, Sales, Service] | same as hero |
| §3 consultant | home:s3:consultant | marketplace-mini agentId="brand-voice-check" name="Brand voice check" price="$0.04/call" | chip: "Publish my first skill" → signup |
| §4 marketing | home:s4:demo | THREE EMITS: brand-palette · campaign · marketplace-mini | chip: "Hire this team" → signup |
| §5 sales | home:s5:demo | THREE EMITS: live-event-stream msg · verify (BANT) · price | chip: "Hire this team" → signup |
| §6 service | home:s6:demo | THREE EMITS: trace-mini · result · engagement-trend msg | chip: "Hire this team" → signup |
| §7 brand | home:s7:whitelabel | brand-palette (interactive — clicking a swatch advances the convo) | chip: "Use this palette" → signup |
| §8 agents | home:s8:show-file | deploy-status service="qualifier-agent" state="live" ms=107000 | chip: "Deploy mine" → signup |
| §9 skills | home:s9:example | skill-toggle id="brand-voice-check" name="Brand voice check" enabled=false description="..." | chip: "Earn from this" → marketplace-mini |
| §10 models | home:s10:routing | compare a={"Support","haiku $0.25/Mtok"} b={"Sales","sonnet $3/Mtok"} | chip: "Apply" → verify |
| §11 tools | home:s11:slack-oauth | verify subject="Slack OAuth" checks=[{Connect ✓},{Scopes ✓},{Post-as ✓}] | chip: "Show me 5 more" |
| §12 memory | home:s12:export | result title="oneie corpus export" ok=true detail="217MB → ./acme.tar" | — |
| §13 tracking | home:s13:wa-web-joined | verify subject="One record" checks=[{WhatsApp 9:14 ✓},{Web visit Tue ✓},{Same Sara ✓}] | chip: "See her record" |
| §14 crm | home:s14:built-itself | (existing HotAccounts inside a message) ranked list of 5 actors | chip: "Add custom field" |
| §15 analytics | home:s15:sample-report | (existing FunnelChart inside a message) + result detail="6-block report, drillable" | chip: "Try with my numbers" → math |
| §16 learning | home:s16:before-after | compare a={"Week 1 CSAT","4.1"} b={"Week 12 CSAT","4.7"} | chip: "Hardened path" → trace-mini |
| §17 dev | home:s17:edit-flow | deploy-status service="agent-edit" state="live" ms=30000 | — |
| §18 speed | home:s18:lighthouse | (existing SpeedReceipt inside a message) | — |
| §19 security | home:s19:escrow | compare a={"If we vanish","corpus export + escrowed source"} b={"If your VC vanishes","you keep the corpus"} | — |
| §20 math | home:s20:math | price label="5,000,000 credits" amount="$500" currency=USD cta="Lock these in" | CTA → checkout |
| §22 faq | home:s22:* | verify (one per FAQ row) | — |
| §24 final | home:s24:ready | signup headline="Hire your workforce" captureLead={persona,team} | success → onboarding-checklist |

## When the visitor says something off-script
Reply in ≤ 2 sentences of prose. If they're qualified (mentions specific clients, asks pricing, asks integration), follow with a `signup` card to capture the lead. Else ask one clarifying question and wait.
```

That's the whole agent. ~90 lines of markdown.

---

## The `__chatRichPrompts` registry — the seed pre-bake

`Chat.tsx` already reads `window.__chatRichPrompts` (verified line 70). The home page registers all 24 ids on mount via a tiny module:

```ts
// web/src/lib/home-rich-prompts.ts (~80 LOC, data only)
export const HOME_RICH_PROMPTS: Record<string, string> = {
  'home:s1:show-team':    "Walk me through how I get a full marketing, sales, and service team live this week.",
  'home:s4:demo':         "Show me the marketing team in action for a new retail client.",
  'home:s4:hire':         "I want the marketing team. Show me how to start.",
  'home:s5:demo':         "Walk me through a sales agent qualifying an inbound lead in real time.",
  'home:s6:demo':         "Demo the service team for a returning customer with a complaint.",
  // ... 19 more
}
```

`SectionBlock` (already on the page) pulls `chatSeed` from `home-sections.ts`; we extend each section's seed shape with an `id`, then install the registry once in `index.astro`'s frontmatter. `ChatSeedButton` (already designed in `home.md`) gets a 4-line `id` pass-through so the chat receives `{ text, id, persona }` instead of just `{ text, persona }`.

---

## What's NOT done yet (honest gaps)

| Status | Item | Effort |
|---|---|---|
| ✅ shipping | 16 card kinds + renderers + emit_card tool + agent.md loader + Chat.tsx seed listener + all auth components + StripeCheckoutForm + onboarding endpoint | — |
| 🟡 partial | `SignInWithAnything` — `MCPConsent` + `BrandLoader` slots are forward-declared (try/catch null) | Not on home critical path; signup card uses the buttons directly, not the full surface |
| 🟡 partial | `__chatRichPrompts` registry — pattern exists but no entries are written from `/` today | Cycle 2 — one ~80-line file |
| ❌ not built | `web/agents/home.md` — the home agent does not exist | Cycle 1 — ~90 lines of markdown |
| ❌ not built | `signup` card kind — composes existing auth components + email-on-blur lead capture | Cycle 3 — ~140 LOC |
| ❌ not built | `checkout` card kind — composes existing Stripe components | Cycle 3 — ~120 LOC |
| ❌ not built | `LifecycleBadge.tsx` + `useLifecycle.ts` hook — the 7-state chat-header pill | Cycle 2 — ~90 LOC |
| ❌ not built | `/api/leads` — idempotent upsert into actors + magic-link queue | Cycle 2 — ~40 LOC |
| ❌ not built | `useChatNudge.ts` — dwell chip on §4-§6 + bottom-of-page nudge | Cycle 2 — ~60 LOC |
| ❌ not built | `ChatSeedButton.id` pass-through — extend signature so `one:chat-seed` carries `{ text, id, persona }` | Cycle 2 — ~10 LOC across 2 files |
| ❌ not built | `home-sections.ts` seed entries need `id` field for all 24 sections + role-level seeds for the 27 TeamOrgChart roles | Cycle 2 — data edit in 1 file |
| ❌ not built | `lib/home-rich-prompts.ts` — 24 section ids + 27 role ids = 51 rich prompts | Cycle 2 — data file ~140 LOC |
| ❌ not built | In-chat onboarding turn-by-turn flow (server side: `/api/onboarding` already accepts piecewise inputs) | Cycle 3 — agent prompt + 4 emits, no new endpoint |

**Total truly new code: ~720 LOC across 9 files. Total edits to existing files: ~50 LOC across 3 files.** Everything else is wiring data.

---

## Build plan — three cycles

### Cycle 1 — home agent + the 51-seed map (mode: lean)
- Write `web/agents/home.md` with system prompt covering 24 section seeds + 27 role seeds + Marketing/Sales/Service 3-emit demo scripts
- Upload to R2 at `one.ie/agents/home.md`; verify `chat.ts:agent.md loader` picks it up
- Smoke-test 5 seeds via `/browser`: `home:s1`, `home:s4:demo`, `home:s5:demo`, `home:s6:demo`, `home:role:copywriter`
- W4 gate: each seed produces the expected card kind sequence (not prose); first-token < 200ms; demos emit 3 cards in correct order

### Cycle 2 — initiation wiring + lifecycle HUD + lead capture (mode: full)
- Add `id` field to each of 24 entries in `home-sections.ts` plus 27 role entries
- Add `id` prop to `ChatSeedButton`; carry through `one:chat-seed` event detail
- Create `lib/home-rich-prompts.ts` — 51 entries (24 sections + 27 roles)
- Register `window.__chatRichPrompts = HOME_RICH_PROMPTS` in `index.astro` `<script is:inline>`
- Build `LifecycleBadge.tsx` + `useLifecycle.ts` hook; mount in Chat.tsx header (one-line edit)
- Build `useChatNudge.ts` hook — dwell timer on §4·§5·§6 + bottom-of-page nudge — call from `index.astro`
- Build `/api/leads` endpoint with idempotent email upsert + magic-link queue
- Emit `one:lifecycle-change` from `Chat.tsx` after seed click (engaged) and after 3-card demo completes (qualified)
- W4 gate: scroll to §4 + dwell → dwell chip appears in chat; click any section → rich prompt fires; badge morphs anonymous → engaged → qualified across the journey

### Cycle 3 — signup + checkout cards + in-chat onboarding (mode: full)
- Add `signup` and `checkout` to `CardData` union in `lib/cards.ts`
- Add both kinds to `emit_card` discriminator in `chat.ts`
- Add both `case`s to `MessageRenderer.tsx`
- Build `SignupCard.tsx`:
  - composes `PasskeyCreate` (primary) + `EmailContinueForm` (secondary) + `GoogleButton` + `WalletSignIn` (behind "More")
  - email-on-blur OR 1.5s typing pause + valid regex → POST `/api/leads` + flip badge to `● lead`
  - on passkey/google/email-link success → POST `/api/onboarding?step=verify` + flip badge to `● verified` + emit `one:lifecycle-change`
  - card morphs to `result` ok=true and agent emits onboarding turn 1
- Build `CheckoutCard.tsx` composing `StripeProvider` + `StripeCheckoutForm`
- Wire server-side checkout session: home agent prompt instructs `emit_card({kind:'checkout', clientSecret})` — secret fetched by inline server tool calling `billing.ts.createCheckoutSession` (exists)
- Wire the 4-turn in-chat onboarding via the agent system prompt — each turn calls `/api/onboarding?step={n}` with piecewise data
- W4 gate: end-to-end — click §4 "Hire this team" → signup card → email blur creates lead row + badge `● lead` → passkey → 4-turn onboarding completes → badge `● your workspace` → §20 → checkout → Stripe test card → badge `● customer`. Refresh page mid-thread; conversation + badge restore.

---

## Acceptance — the 12-click journey

Fresh incognito on `/`. Zero typed input until step 5.

| # | Action | Expected card / badge state |
|---|---|---|
| 1 | Page load | Badge: `● anonymous`. Chat shows agent intro. |
| 2 | §1 hero "Show me my team" | Badge → `● engaged`. Emit: `choice-chips` [Marketing · Sales · Service] |
| 3 | Tap "Marketing" chip | THREE emits ~800ms apart: `brand-palette` → `campaign` → `marketplace-mini`. Badge → `● qualified — Marketing` |
| 4 | Inside campaign card, tap "Hire this team" | Emit: `signup` card |
| 5 | Type `t@one.ie`, blur the field | Network: POST `/api/leads` 200. Badge → `● lead — link sent`. Card shows ✓ saved |
| 6 | Tap "Passkey" inside signup card | Touch ID prompt → session cookie set. Badge → `● verified`. Card morphs to `result` ok=true |
| 7 | Onboarding turn 1 emit | "Pick your name" → type → onboarding turn 2 |
| 8 | Onboarding turn 2 | `brand-palette` interactive → pick swatches → turn 3 |
| 9 | Onboarding turn 3 | `choice-chips` [Marketing director] → tap → turn 4 |
| 10 | Onboarding turn 4 | `result` + `deploy-status` live ms=107000. Badge → `● your workspace — t-at-one-ie.one.ie` |
| 11 | Back-scroll to §20, click "Run the math" → "Lock these in" | `checkout` card with Stripe Element |
| 12 | Stripe test card `4242…` → submit | `result` ok=true. Badge → `● customer — 5M credits`. New `onboarding-checklist` ("distribute to clients") emitted |
| 13 | **Refresh page** | Session persists. Badge restores to `● customer`. Chat opens to same thread |

**Pass criteria:**
- All 13 steps complete without a single page nav (chat is the only surface)
- First-token p50 < 200ms across all turns (haiku)
- Zero generic prose replies — every seed produces a card
- One actor row in TypeDB with lifecycle progression: `anonymous → engaged → qualified → lead → verified → active → customer`
- `visitor_hash` from middleware attaches to the lead row (no orphaned cookies)
- One Stripe test charge captured

**Bonus — the dropout-recovery test:**
1. Repeat steps 1-5 in incognito; close the tab at step 5 (lead captured but no auth).
2. Open the email inbox; click the magic link.
3. The link should land on `/dashboard?welcome=1&lead=<id>`; session cookie set; actor `lifecycle` upgrades to `verified`.
4. Visit `/` again — chat opens with a personalized intro: *"Welcome back. You were looking at Marketing — pick up where you left off?"* — using the persisted `team_intent` from the lead row.

This is the test that proves the funnel actually catches drop-offs.

---

## Risks & honest tradeoffs

| Risk | Mitigation |
|---|---|
| Agent emits wrong card kind for off-script seeds | System prompt has 24 explicit id mappings + "if no id match → prose + clarifying question". No invention. |
| The 3-emit team demos feel scripted, not "intelligent" | They are scripted. That's the point — the rail is the demo; demos beat improvisation. The agent picks WHICH demo (per persona); the demo content is locked. |
| `campaign` card type already exists but isn't in the 16-kind `emit_card` schema | Already handled — `chat.ts` has separate `emit_section`, `emit_field_service_card`, `emit_boq_card` tools that already cover non-16-union kinds. Add `campaign` to the home agent's tool list. |
| Lead-on-blur feels invasive | The signup card framing makes it explicit ("Sign in or we'll send you a magic link"). The blur capture is the magic-link path — the user is opting in by typing their email in a signup form. |
| Stripe inline checkout on mobile too cramped | Existing `ChatWidget` expands sheet to 90vh on `one:chat-mode=wide`; `CheckoutCard` emits that event on mount. Verified pattern from `chat-integrated.md`. |

---

## See also

- `plans/home.md` — the 24-section narrative the chat answers
- `plans/chat-integrated.md` — the three-view-mode action layer this plan operates inside
- `text/09-teams.md` — Marketing/Sales/Service role lists + payroll numbers cited by the team demos
- `text/15-security.md` — passkey/Secure Enclave story the signup card delivers
- `text/12-crm.md` — actor-as-record (why leads land in the same brain)
- `web/src/components/Chat.tsx` lines 70-95 (rich prompts) and 344-367 (seed listener) — entry points
- `web/src/pages/api/chat.ts` `emit_card` tool — discriminator add point
- `web/src/components/chat/MessageRenderer.tsx` — case-add point

---

*One agent file. Three new components (signup card · checkout card · lifecycle badge). Seven lifecycle states, six transitions, one HUD that morphs through them. The rail is summoned by the page, the lead is captured before auth completes, the signup happens in the conversation, and the visitor never leaves the chat from "Show me my team" to "you're a customer."*
