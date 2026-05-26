# boq-todo.md — Poirier Technical Solutions demo

Source: conversation spec · `web/agents/` · `web/src/components/chat/` · `web/src/lib/`

**Mode:** mixed · **Lifecycle:** construction · **Closure scalar:**
lead qualifier routes correctly to sales/service bot; sales bot scoping card
appears mid-chat; map pins a site and shows service area; calendar shows
available slots; product card renders with Add to Cart; Stripe checkout
completes; Brad's dashboard shows the booking; service bot severity card
dispatches with ETA map — all at `localhost:4321/studio/ptcorp`.

**Client:** Poirier Technical Solutions Corp. — B2B fiber/telecom, Quinte West ON, national.
**Services:** FTTH/FTTX · MDU · Install/Repair · Consulting · Structured Cabling · Security Camera Systems.
**Segments:** ISP/carrier · MDU developer · Business · Municipality. **No residential.**

---

## Audiences

| Audience | Role | Surface |
|---|---|---|
| **Brad Poirier** | Demo subject + future platform owner | `/studio/ptcorp` + dashboard |
| **Donal / OO** | Agency running the BOQ flywheel | Demo URL to send clients |
| **Tony** | Platform builder | Local dev → deploy to one.ie |
| **End prospects** | ISP/carrier, MDU developers, businesses, municipalities | Chat widget embed on ptcorp.ca |

---

## How to run with `/do`

- `/do boq-todo.md --wave 0` — fan out **4 agents in one message** (agent MDs + card schema)
- `/do boq-todo.md --wave N` — drive a wave end-to-end
- `/do boq-todo.md --item Q1` — single item, own W1→W4 sandwich

---

## Dependency graph

```
WAVE 0 (no deps — 4 parallel)
┌──────────────────────────────────────────────────────┐
│  Q1           S1           SV1          SC1          │
│  qualifier    sales bot    service bot  card schemas  │
│  agent.md     agent.md     agent.md     + Zod types   │
└────┬──────────┬────────────┬────────────┬────────────┘
     │          │            │            │
     ▼          ▼            ▼            ▼
WAVE 1 (8 parallel — rich card components, deps: SC1)
┌──────────────────────────────────────────────────────┐
│  C1           C2           C3           C4           │
│  Service      Map          Scoping      Quote        │
│  Selector     Leaflet      inline form  range card   │
│               + area pin                             │
│  C5           C6           C7           C8           │
│  Calendar     Severity     Dispatch     Job          │
│  picker       triage       ETA + map    Tracker      │
└────┬──────────┬────────────┬────────────────────────-┘
     │          │            │
     ▼          ▼            ▼
WAVE 2 (3 parallel — catalog + cart + Stripe, deps: C1-C5)
┌──────────────────────────────────────────────────────┐
│  P1           P2           P3                        │
│  ProductCard  CartCard     Stripe                    │
│  + catalog    order total  deposit + subscription    │
└────┬──────────┬────────────┬─────────────────────────┘
     │          │            │
     ▼          ▼            ▼
WAVE 3 (2 parallel — booking engine, deps: C5, P3)
┌──────────────────────────────────────────────────────┐
│  B1                        B2                        │
│  Booking API               Brad's Dashboard          │
│  D1 schema + CRUD          bookings + orders         │
│  calendar availability     + emergency alerts        │
└────┬───────────────────────┬─────────────────────────┘
     │                       │
     ▼                       ▼
WAVE 4 (4 parallel — wiring + demo page)
┌──────────────────────────────────────────────────────┐
│  I1          I2            I3           I4           │
│  qualifier   sales flow    service flow demo page    │
│  routing     → catalog     → severity   /studio/     │
│              → cart        → dispatch   ptcorp       │
│              → stripe      → tracker                 │
│              → booking                               │
└──────────────────────────────────────────────────────┘
```

---

## Wave 0 — 4 parallel agents (no deps)

### Agent markdown files

- [ ] **Q1** `web/agents/ptcorp-qualifier.md` — Lead qualifier. 3-question gate: (1) new inquiry or existing client? (2) sector: ISP/carrier · MDU developer · Business · Municipality (3) urgency: planned project / timeline-driven / emergency. Routes to sales or service bot with full context pre-loaded. Starters: "I need fiber for a new build" · "We have an outage" · "Looking for a maintenance contract" · "I have a consulting question". No residential. · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **S1** `web/agents/ptcorp-sales.md` — Sales bot. Knows all 6 service lines. Speaks B2B: PON architecture, fiber counts, OSP/ISP scope, MDU unit counts, conduit, riser access, Cat6A, NVR, SLA tiers. Scopes the job per sector, generates estimate range, recommends catalog items, drops booking CTA. Never quotes exact prices — ranges + "Book an assessment to confirm". · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **SV1** `web/agents/ptcorp-service.md` — Service bot. Existing clients only. Triages severity (Critical / Urgent / Scheduled). Critical → dispatches Brad, shows ETA. Urgent → same-day booking. Scheduled → calendar. Speaks OTDR, splice closure, GPON, loss budget, XGSPON. Knows the client record (pulls from booking engine by email/company). 24/7 framing. · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

### Card schema + types

- [ ] **SC1** `web/src/lib/ptcorp-cards.ts` (NEW) — Zod schemas for all 10 rich card kinds emitted by ptcorp bots. Discriminated union on `kind`:
  - `service-selector` — `{ services: [{ id, label, icon, description }] }`
  - `map` — `{ center: [lat,lng], zoom, serviceArea: GeoJSON, pin?: [lat,lng], label? }`
  - `scoping` — `{ serviceId, fields: [{ id, label, type, options? }] }`
  - `quote` — `{ low, high, currency, notes, ctas: [{ label, action }] }`
  - `calendar` — `{ slots: [{ date, times: string[] }], jobType, location }`
  - `product` — `{ id, name, description, price, interval?: 'month'|'year'|'once', badge? }`
  - `cart` — `{ items: [{ id, name, price, interval? }], total }`
  - `severity` — `{ options: [{ level: 'critical'|'urgent'|'scheduled', label, description }] }`
  - `dispatch` — `{ ref, eta, etaMinutes, techName, phone, mapUrl }`
  - `job-tracker` — `{ ref, stages: [{ id, label, status: 'done'|'active'|'pending' }] }`
  · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

---

## Wave 1 — 8 parallel agents (deps: SC1)

### Rich card components

- [ ] **C1** `web/src/components/chat/cards/ServiceSelectorCard.tsx` (NEW) — renders `service-selector` kind. Grid of tappable tiles (icon + label + short description). On tap: emits `CustomEvent('chat:seed')` with sector-aware seed prompt. Icons from lucide-react: `cable` (FTTH), `building-2` (MDU), `wrench` (Install/Repair), `clipboard-list` (Consulting), `network` (Structured Cabling), `camera` (Security). Design system tokens only. · deps: SC1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C2** `web/src/components/chat/cards/MapCard.tsx` (NEW) — renders `map` kind. Leaflet (lazy-imported) with dark tile layer matching design system. Shows Quinte West base marker, national service area polygon overlay (Ontario primary, Canada-wide secondary). Customer can drag-drop a pin for their site. On pin: emits location to chat via `CustomEvent('chat:data', { location })`. `client:load` within the chat island. · deps: SC1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C3** `web/src/components/chat/cards/ScopingCard.tsx` (NEW) — renders `scoping` kind. Dynamic form: field types `text`, `number`, `select`, `radio`, `checkbox`. Different field sets per service: MDU (unit count, building stage, conduit, fiber type, timeline), FTTH (geographic scope, fiber count, OSP vs ISP), Consulting (scope, deliverables, timeline), Structured Cabling (Cat grade, rack count, floors), Security (camera count, indoor/outdoor, NVR vs cloud). Submit seeds a scoping summary into chat. · deps: SC1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C4** `web/src/components/chat/cards/QuoteCard.tsx` (NEW) — renders `quote` kind. Shows low–high range, currency (CAD), notes, and up to 2 CTAs (primary: "Book Assessment", secondary: "Get Full Proposal"). Range formatted as `$85,000 – $120,000`. Badge: "Estimate only — site assessment confirms". On CTA click: emits `CustomEvent('chat:seed')` with booking-intent prompt + `emitClick('ui:ptcorp:quote-cta')`. · deps: SC1 · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C5** `web/src/components/chat/cards/CalendarCard.tsx` (NEW) — renders `calendar` kind. Month grid, available dates highlighted (primary token), unavailable greyed. Time slot picker below selected date (Morning / Afternoon). On confirm: emits `CustomEvent('chat:data', { booking: { date, time, jobType, location } })`. Pulls available slots from `/api/ptcorp/slots?jobType=&lat=&lng=` which factors Brad's calendar + travel time from Quinte West. · deps: SC1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C6** `web/src/components/chat/cards/SeverityCard.tsx` (NEW) — renders `severity` kind. Three large tappable cards: 🔴 Critical (full loss, multi-client affected, dispatch now), 🟡 Urgent (degraded, same-day), 🟢 Scheduled (planned maintenance, book slot). On tap: emits severity level to chat + `emitClick('ui:ptcorp:severity')`. Critical path immediately routes to dispatch flow. · deps: SC1 · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C7** `web/src/components/chat/cards/DispatchCard.tsx` (NEW) — renders `dispatch` kind. Shows: reference number, technician name (Brad Poirier), ETA in minutes + formatted time, click-to-call phone button, small Leaflet map showing Quinte West → client site route. Green pulsing dot on tech location. Reference formatted as `PTC-2026-NNNN`. · deps: SC1, C2 (Leaflet) · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **C8** `web/src/components/chat/cards/JobTrackerCard.tsx` (NEW) — renders `job-tracker` kind. Horizontal pipeline: Received → Assigned → En Route → On Site → Resolved. Active stage highlighted (primary token), done stages with checkmark, pending stages muted. Reference number top-right. Updates via polling `/api/ptcorp/jobs/:ref/status` every 30s when active. · deps: SC1 · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

---

## Wave 2 — 3 parallel agents (deps: C1-C5)

### Product catalog + cart + Stripe

- [ ] **P1** `web/src/components/chat/cards/ProductCard.tsx` (NEW) + `web/src/lib/ptcorp-catalog.ts` (NEW) — renders `product` kind. Card: name, description, price (one-time or /yr), badge (e.g. "Most popular", "SLA included"). "Add to Cart" button emits `CustomEvent('cart:add', { product })` + `emitClick('ui:ptcorp:add-to-cart')`.

  Catalog in `ptcorp-catalog.ts`:
  - **Assessments:** Site Assessment $500 (credited to project) · OTDR Baseline Survey $800 · Network Audit $1,200
  - **Maintenance:** Basic (annual inspection) · Standard (quarterly + emergency) · Premium (24/7, 4hr SLA) — prices TBD by Brad
  - **Emergency SLA:** 4-hour / 8-hour / Next-day response contracts — prices TBD
  - **Consulting:** Technical Consulting (per hour) · OSP Design Package · Project Management (per hour) — prices TBD

  · deps: SC1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **P2** `web/src/components/chat/cards/CartCard.tsx` (NEW) — renders `cart` kind. Line items with name, price, interval (once / /yr). Subtotal. "Checkout" button. "Remove" on each line. Cart state held in `localStorage` under `ptcorp-cart`. On add: cart card re-renders inline via React state. On checkout: fires Stripe flow from P3. Emits `emitClick('ui:ptcorp:checkout')`. · deps: SC1, P1 · `haiku` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **P3** `web/src/pages/api/ptcorp/checkout.ts` (NEW) + Stripe wiring — `POST /api/ptcorp/checkout { items[] }` creates a Stripe Checkout Session (mixed: one-time line items + subscription items in same session). Returns `{ url }`. Client redirects. Success URL: `/studio/ptcorp?booking=confirm`. Cancel URL: `/studio/ptcorp`. Stripe key from `env.STRIPE_SECRET_KEY`. For demo: Stripe test mode, hardcoded price IDs for catalog items. · deps: P1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

---

## Wave 3 — 2 parallel agents (deps: C5, P3)

### Booking engine

- [ ] **B1** `web/migrations/00XX_ptcorp_bookings.sql` (NEW) + `web/src/pages/api/ptcorp/` — D1 schema:
  ```sql
  bookings(id, ref, company, contact_name, email, phone,
           job_type, sector, location_lat, location_lng, location_label,
           slot_date, slot_time, notes, status, stripe_session_id,
           created_at, updated_at)
  ```
  Endpoints:
  - `POST /api/ptcorp/book` — create booking, return `{ ref, confirmation }`
  - `GET /api/ptcorp/slots?jobType=&lat=&lng=` — return available dates/times (hardcoded Brad availability for demo: Mon-Fri 8am-4pm, travel time subtracted based on distance from Quinte West)
  - `GET /api/ptcorp/jobs/:ref/status` — return current stage for JobTrackerCard
  - `PATCH /api/ptcorp/jobs/:ref` — admin update (Brad's dashboard)
  · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **B2** `web/src/pages/studio/ptcorp-dashboard.astro` (NEW) — Brad's internal dashboard at `/studio/ptcorp-dashboard` (SERVER_SECRET gated). Shows:
  - **Bookings** — table: ref, company, job type, date, status. Click → detail modal.
  - **Orders** — Stripe session list: company, items, total, paid date.
  - **Emergency alerts** — any booking with `job_type=emergency` or severity=critical flagged red at top.
  - **Pipeline** — kanban: Received / Scheduled / En Route / On Site / Resolved. Drag to update status.
  Design system tokens. No external charting lib — native CSS grid. · deps: B1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

---

## Wave 4 — 4 parallel agents (deps: all prior)

### Wiring + integration

- [ ] **I1** `web/src/pages/api/chat.ts` extend + `web/agents/ptcorp-qualifier.md` — qualifier routing: when qualifier bot resolves sector + new/existing, emit a `route-to` tool call that switches the system prompt to sales or service bot for the rest of the session. Store resolved context in thread metadata. Test: "We have a 300-unit MDU going up in Hamilton" → routes to sales bot with MDU + Hamilton pre-loaded. · deps: Q1, S1, SV1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **I2** Wire sales flow — `web/src/pages/api/chat.ts` extend: sales bot emits card sequence via `emit_section` tool: ServiceSelectorCard → ScopingCard → QuoteCard → ProductCard(s) → CartCard → CalendarCard. On calendar confirm + payment: `POST /api/ptcorp/book`. Confirm message renders JobTrackerCard at "Received". Test path: new MDU inquiry → all 7 cards appear in sequence → Stripe session created → booking in D1. · deps: C1-C5, P1-P3, B1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **I3** Wire service flow — `web/src/pages/api/chat.ts` extend: service bot emits SeverityCard → on Critical: DispatchCard + Brad text alert (Cloudflare Email or SMS via Twilio if key present, else console log for demo) + JobTrackerCard. On Urgent/Scheduled: CalendarCard → `POST /api/ptcorp/book`. Test path: "Our fiber is down, 40 businesses affected" → SeverityCard → Critical → DispatchCard with ETA → JobTrackerCard live. · deps: C6-C8, B1, SV1 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

- [ ] **I4** `web/agents/ptcorp.md` (NEW, public entry point) + demo polish — master agent at `/studio/ptcorp`. Hero: "Poirier Technical Solutions — Fiber & Network Infrastructure". Eyebrow: "Quinte West, ON · National Coverage". 3 starter cards: "New build / project" → qualifier, "Existing client support" → qualifier, "Browse services & pricing" → catalog. Dark theme. Links to live `ptcorp.ca`. Wires to qualifier bot as first message handler. Update `MEMORY.md` reference with demo URL once deployed. · deps: I1, I2, I3 · `sonnet` · w1[ ] w2[ ] w3[ ] w4[ ]

---

## Product catalog (reference — prices to confirm with Brad)

| Category | Product | Price | Type |
|---|---|---|---|
| Assessment | Site Assessment | $500 CAD | Once (credited) |
| Assessment | OTDR Baseline Survey | $800 CAD | Once |
| Assessment | Network Audit | $1,200 CAD | Once |
| Consulting | Technical Consulting | TBD/hr | Hourly |
| Consulting | OSP Design Package | TBD | Once |
| Maintenance | Basic (annual inspection) | TBD | /yr |
| Maintenance | Standard (quarterly + emergency) | TBD | /yr |
| Maintenance | Premium (24/7, 4hr SLA) | TBD | /yr |
| Emergency SLA | 4-hour response contract | TBD | /yr |
| Emergency SLA | 8-hour response contract | TBD | /yr |
| Emergency SLA | Next-day response contract | TBD | /yr |

---

## Demo script (15 min, Brad watches)

```
Act 1 — New MDU lead (Sales flow)
  Open localhost:4321/studio/ptcorp
  Type: "I need fiber for a 300-unit condo going up in Hamilton"
  → ServiceSelectorCard (tap MDU)
  → MapCard (Hamilton pinned, service area shows Ontario coverage ✓)
  → ScopingCard (unit count, stage, conduit, fiber type, timeline)
  → QuoteCard ($85,000 – $120,000 · "Book assessment to confirm")
  → ProductCard (Site Assessment $500 + OTDR Baseline $800) → Add both
  → CartCard ($1,300 total) → Checkout
  → Stripe test checkout → pay
  → CalendarCard → pick date → confirm
  → JobTrackerCard: "Received ✓"
  → Brad's dashboard: booking + order appear

Act 2 — Emergency (Service flow)
  New chat: "I'm an existing client — our fiber is down, 40 businesses affected"
  → SeverityCard → tap 🔴 Critical
  → DispatchCard: Brad Poirier · ETA 2h 40min · map shows route
  → JobTrackerCard: "Received ✓ → Assigned ✓ → En Route ●"

Act 3 — Dashboard
  Open /studio/ptcorp-dashboard
  Show both jobs, the Stripe order, the emergency alert at top
```

---

## Closure scalars per wave

| Wave | Gate |
|---|---|
| W0 | All 3 agent MDs pass `oneie agent validate`; SC1 Zod union covers all 10 kinds; `safeParse` smoke test green |
| W1 | All 8 card components render without console errors in Storybook or `/design`; MapCard shows Quinte West + service area; CalendarCard returns slots from API |
| W2 | ProductCard renders catalog items; CartCard adds/removes items; Stripe checkout session created + redirects in test mode |
| W3 | `POST /api/ptcorp/book` writes to D1 and returns ref; dashboard shows booking; job status polling returns correct stage |
| W4 | Full demo script runs end-to-end: 7 cards in sequence, Stripe session, booking in D1, emergency dispatch, dashboard updated |

---

## Code rubric targets

- **Security ≥ 0.85** — Stripe webhooks verified, dashboard SERVER_SECRET gated, no PII in card payloads
- **Stability ≥ 0.80** — Stripe test mode isolated, D1 migrations idempotent, calendar slots never double-book
- **Simplicity ≥ 0.80** — each card is one file, one responsibility; catalog is a plain TS array Brad can edit
- **Speed ≥ 0.75** — Leaflet lazy-loaded, calendar slots cached 5min, Stripe redirect < 2s

Cycle gate: composite ≥ 0.65.

---

*3 bots. 10 rich cards. 1 catalog. 1 booking engine. 1 dashboard. The demo that wins Brad.*
