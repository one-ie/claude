# send-link.md

> Send a link from the CRM. The contact clicks it and arrives on a page that already knows them — hero copy matches their persona, chat agent has their full history, no cold start, no form friction.

---

## What this is

A **one-click action in the CRM** that generates a tracked URL bound to a specific contact's `actor_id`. When they click it:

1. Their identity jumps straight to rung 4 (known actor) — no cookie ladder required
2. `snapshotForActor()` fires instantly — their profile pre-warms the DO
3. The page hero transforms to their persona variant (already built — `PersonalizedHero`)
4. The chat agent opens with a greeting that knows their name, company, last interaction
5. Every subsequent action (scroll, click, message) deposits pheromone on their path

The contact experiences a page that feels built for them. The agent already knows them. There is no "who are you?" moment.

---

## Classifier

| Prior | Answer |
|---|---|
| Spec locked | Yes — identity ladder, snapshotForActor, PersonalizedHero, /go/:id all shipped |
| Variance known | Yes — extend tracked_links with actor_id; upgrade /go/[id].ts to set rung-4 cookie |
| Exit scalar | Yes — contact clicks link, page personalizes, chat agent has snapshot |
| Files known | Yes — see §Delta |

**Mode: lean** · **Lifecycle: evolution**

---

## What's already built

| Piece | File | Status |
|---|---|---|
| Tracked redirect Worker | `web/src/pages/go/[id].ts` | Shipped — resolves `tracked_links`, sets `_one` cookie, records click |
| Visitor identity (rung 0–1) | `/go/[id].ts` → `cookie_id` + `visitor_hash` | Shipped |
| Actor snapshot RPC | `snapshotForActor(actorId)` in Workspace DO | Shipped (C6) |
| Page personalization | `PersonalizedHero` + `useWatch('actor:<hash>')` + `index.astro` | Shipped — wired `client:idle` |
| Hero variant copy | `web/src/lib/personalize-map.ts` — 4 variants keyed by persona tag | Shipped |
| Chat hydration with snapshot | `POST /api/chat` injects system prompt from snapshot | Shipped (C1) |
| CRM contact model | `web/src/lib/crm/actor.ts` — `Person`, `Contact`, `ContactActivityRow` | Shipped |
| CRM detail pane | `web/src/components/in/EntityDetail.tsx` | Shipped |
| Activity timeline | `web/src/components/crm/ContactActivity.tsx` | Shipped |
| Pheromone on click | `mark(edge)` fires in `/go/[id].ts` via ANALYTICS_HUB broadcast | Shipped |

**Everything that makes this powerful is already running.** The delta is small.

---

## The delta (what to build)

### D1 migration — bind a link to an actor

```sql
-- Add to tracked_links table
ALTER TABLE tracked_links ADD COLUMN actor_id TEXT;
ALTER TABLE tracked_links ADD COLUMN context TEXT;         -- extra agent system-prompt injection
ALTER TABLE tracked_links ADD COLUMN greeting TEXT;        -- override chat opening line
ALTER TABLE tracked_links ADD COLUMN destination TEXT NOT NULL DEFAULT '/';
ALTER TABLE tracked_links ADD COLUMN created_by TEXT;      -- operator actor_id
ALTER TABLE tracked_links ADD COLUMN expires_at INTEGER;   -- epoch ms, null = never
```

### `/go/[id].ts` upgrade — rung 4 on actor-bound links

Current: always sets `visitor_hash` cookie (rung 1).

Extension: if `actor_id` is set on the resolved link:

```ts
// After resolving link from D1
if (link.actor_id) {
  // Rung 4 — identity is known, skip the ladder
  cookie.set('actor_id', link.actor_id, { maxAge: 60 * 60 * 24 * 365 })

  // Pre-warm snapshot in DO — page and chat get it on first WS frame
  ctx.waitUntil(
    env.ANALYTICS_HUB.get(stubId).fetch('/snapshot', {
      method: 'POST',
      body: JSON.stringify({ actorId: link.actor_id })
    })
  )

  // Inject extra context into actor's DO state for this session
  if (link.context || link.greeting) {
    ctx.waitUntil(
      env.ANALYTICS_HUB.get(stubId).fetch('/link-context', {
        method: 'POST',
        body: JSON.stringify({
          actorId: link.actor_id,
          context: link.context,
          greeting: link.greeting,
          linkId: link.id
        })
      })
    )
  }
}
```

Write `link:clicked` event (already happens) — event now carries `actor_id` at rung 4.

### `POST /api/links` — create a send-link

```ts
// Request
interface CreateLinkRequest {
  actorId: string           // contact being sent the link
  destination?: string      // default '/'
  campaignId?: string
  context?: string          // injected into agent system prompt for this session
  greeting?: string         // override chat opening message
  expiresInDays?: number    // default 90
}

// Response
interface CreateLinkResponse {
  id: string               // ULID
  url: string              // https://one.ie/go/:id
  shortUrl: string         // copy-ready
}
```

Writes to `tracked_links` with `actor_id`, `context`, `greeting`, `destination`, `created_by`, `expires_at`.

### CRM "Send Link" action

In `EntityDetail.tsx`, add a "Send Link" button to the contact action bar (alongside existing save/archive/complete actions):

```tsx
<button
  onClick={() => {
    emitClick('ui:crm:send-link', { actorId: contact.header.id })
    setShowSendLink(true)
  }}
  className="px-3 py-1.5 rounded-lg bg-primary text-on-primary text-sm"
>
  Send Link
</button>
```

`SendLinkSheet` (new component, `web/src/components/crm/SendLinkSheet.tsx`):
- Calls `POST /api/links` with `actorId`
- Shows the generated URL + one-click copy
- Optional: context override field ("add context for the agent"), greeting override
- Optional: destination picker (Homepage / Pricing / Chat / custom)
- Shows expiry (default 90 days)

No email sending in v1 — operator copies the URL and sends however they want (email, WhatsApp, LinkedIn DM, SMS). The link is the product.

---

## What the contact experiences

```
Operator clicks "Send Link" in CRM
  → URL created: one.ie/go/abc123

Contact receives link (email, DM, SMS — whatever)
  → Clicks
  → /go/abc123 resolves:
       - actor_id cookie set (rung 4)
       - snapshot pre-warmed in DO
       - link:clicked event fired
       - 302 → destination (e.g. /)

Page loads:
  → PersonalizedHero useWatch fires with actor snapshot
  → Hero: "Hey [Name]" variant — founder/agency/developer copy (not generic)
  → CTA copy matches their lifecycle stage
  → No flash-of-default — snapshot arrives in first WS frame

Chat opens:
  → System prompt already has: name, company, lifecycle, last 3 conversations,
      key events, persona tags, operator-injected context
  → Agent opens with greeting from snapshot (or operator-specified override)
  → No "What brings you here?" — the agent knows

Every click/scroll/message:
  → Pheromone marks their path in TypeDB
  → Activity timeline in CRM updates in real-time
  → Operator watching CRM sees them live
```

---

## Real sales and conversion applications

### 1. Warm outreach — the pre-qualified first impression

**Scenario**: Prospect has visited `/pricing` 3 times. CRM shows: `founder` persona, SaaS vertical, Dublin, 120 employees.

**Without send-link**: Cold email → generic landing page → agent asks "what are you looking for?"

**With send-link**: Sales rep sends one link. Contact lands on:
- Hero: "The fastest way to add AI agents to [product category]" (founder variant)
- Chat opens: "Hi [Name], I can see you've been evaluating [one] for [Company]. What's the biggest thing holding you back?"
- Agent knows their vertical, their size, their visit history — skips the qualification questions entirely

**Conversion lift**: First message is a follow-up, not a cold open. The prospect feels known, not tracked.

---

### 2. Demo follow-up — continuity across touchpoints

**Scenario**: 30-min discovery call. Notes in CRM. Contact goes cold.

**With send-link**: Follow-up email includes one link. Contact clicks it:
- Page shows the specific use case discussed on the call
- Chat agent: "Last time we talked you mentioned [pain point]. I've been thinking about your setup — want to see how it would actually work?"
- Agent has the call notes injected via `context` field on the link

**Why this works**: The usual follow-up email asks them to remember and re-engage with an idea. This link *is* the idea — alive, personalized, ready to continue the conversation.

---

### 3. Pipeline rescue — revive stalled deals

**Scenario**: Contact was "hot" 3 weeks ago at the pricing stage. Went silent. Pheromone shows their path strength fading.

**With send-link**: Automated trigger (or manual) sends them a rescue link. Context field: "This contact stalled at pricing — focus on ROI justification and offer a 30-day trial."

Contact lands on:
- Page variant: pricing page with their vertical's case study above the fold
- Chat: "I noticed you were close to a decision last month. A few things have changed — want a quick update?"
- No form, no "book a demo" friction — just continue the conversation

---

### 4. Post-event follow-up — conference/event networking

**Scenario**: Met someone at a conference. Added to CRM with tag `event:websummit-2026` and notes.

**With send-link**: Send within 24 hours. Context: "Met at WebSummit. They work on [vertical]. Mentioned [specific pain]."

Contact lands on:
- Hero variant matching their persona/vertical
- Chat: "Great to meet you yesterday. Based on what you mentioned about [pain], I pulled together something specific to your situation."
- Feels like a follow-up conversation, not a marketing funnel

---

### 5. Customer onboarding — personalised success path

**Scenario**: New customer just converted. CRM shows: plan tier, company size, use case tags.

**With send-link**: Welcome email contains their personalised onboarding link. They click:
- Page shows their specific onboarding checklist (generated from their plan + use case tags)
- Chat is their dedicated CSM agent — already knows their plan, their goals, their timeline
- Agent: "Welcome, [Name]. You're set up on [plan]. Let's get your first [outcome] live today."

Onboarding time drops because the agent skips everything they already know.

---

### 6. Renewal and expansion — show them their own ROI

**Scenario**: Customer approaching renewal. LTV tracked, usage data in CRM, expansion signals firing.

**With send-link**: Pre-renewal link with context: "Approaching renewal. Show usage growth, propose expansion to [plan]. Key metric: [X outcomes] delivered."

Contact lands on:
- Page personalised with their account stats (via `snapshotForActor`)
- Chat: "Your team has [achieved X] since you started. Here's what the next tier unlocks for you specifically."
- No generic "time to renew" email — a conversation about their specific results

---

### 7. Broadcast to a segment — one link per person, not one for all

**Campaign scenario**: Launching a new feature relevant to `persona:developer` segment.

**With send-link + campaign**: Bulk "Send Link" action in CRM segment view. Each contact gets their own link (bound to their `actor_id`). Same destination, but each person arrives with their full profile.

The chat agent:
- For a senior engineer: "I know you've been using [API] — this new feature plugs directly into your existing workflow."
- For a founder: "Your team's been growing — this unlocks the multi-seat feature you asked about last quarter."
- Same campaign, different conversations.

---

## Why this compounds

Every click doesn't just convert — it teaches the system:

- `link:clicked` fires with `actor_id` → pheromone marks `campaign:X → actor:Y → destination:Z` path
- If they engage deeply (chat, convert) → `mark(edge, weight)` strengthens that path
- If they bounce → `warn(edge)` weakens it — future links to similar contacts go to different destinations
- `highways()` surfaces which link→destination→persona combinations have highest conversion rate
- The system learns which message, sent at which stage, to which persona, converts — without any analytics configuration

**The send-link is both a sales tool and a learning signal.** Each use makes the next one smarter.

---

## Spec

### Mode: lean

**Goal**: CRM "Send Link" button → actor-bound tracked URL → rung-4 identity on click → personalised page + pre-seeded chat agent.

**Speed**: 2 cycles

| Cycle | Scope | Files |
|---|---|---|
| C1 | D1 migration + `/api/links` endpoint + `/go/[id].ts` actor upgrade | `web/src/migrations/0040_send_link.sql`, `web/src/pages/api/links.ts`, `web/src/pages/go/[id].ts` |
| C2 | `SendLinkSheet` component + "Send Link" button in `EntityDetail.tsx` | `web/src/components/crm/SendLinkSheet.tsx`, `web/src/components/in/EntityDetail.tsx` |

**Verify**:
- [ ] Contact clicks link → `actor_id` cookie set → `snapshotForActor` called
- [ ] `PersonalizedHero` renders non-default variant for known actor
- [ ] Chat system prompt contains name + last interaction
- [ ] `link:clicked` event appears in CRM activity timeline
- [ ] Link expires correctly after TTL
- [ ] `POST /api/links` returns URL within 200ms

**Close**: both cycles pass verify + pheromone fires on click.

---

## What's NOT in v1

- Email sending from the CRM (operator copies URL and sends themselves — keeps it simple, no ESP dependency)
- Analytics dashboard for link performance (use existing tracking/realtime — activity timeline shows clicks)
- SMS/push delivery (future — wire through campaign signals)
- Link editing after creation (immutable — create a new one)
- A/B variant forcing per link (future — `variant` field reserved but unused)

---

*The link is the CRM record coming alive for the prospect. Everything to make it work is already running.*
