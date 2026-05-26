# field-service.md — field-service agents on ONE

**Principle.** Any trade, maintenance, or on-site service business can run
a chat-driven booking and dispatch workflow on ONE by declaring one feature
flag. No custom code. The platform supplies the cards, the API, the calendar,
the Stripe checkout, and the ops dashboard.

```
visitor message
  │
  ▼
chat agent (features: [field-service])
  │   emit_field_service_card → service-selector | map | scoping | quote
  │   emit_field_service_card → calendar (fetch /api/field-service/[slug]/slots)
  │   booking JSON in message → POST /api/field-service/[slug]/book → ref
  │   emit_field_service_card → job-tracker (ref, stage: Received)
  ▼
field_service_bookings (D1, client_slug = agentId)
  │
  ▼
/studio/field-service-dashboard?slug=[agentId]
```

---

## Opt in

Add one line to your agent's frontmatter:

```yaml
# Sales / scoping bot (no dispatch)
features: [field-service]

# Service desk / dispatch bot
features: [field-service, field-service-dispatch]
```

`field-service` enables the `emit_field_service_card` tool with the sales
description (service-selector → scoping → quote → calendar → cart).

`field-service-dispatch` changes the tool description to the service-desk
flow (severity → dispatch → job-tracker) and activates the booking
auto-detection that persists to D1 and injects the ref back into the
system prompt.

---

## The 10 card kinds

All rendered by `FieldServiceCardRenderer`. The LLM calls
`emit_field_service_card` with one of these `kind` values.

| Kind | Stage | What it shows |
|------|-------|---------------|
| `service-selector` | Opening | Grid of service lines with icon + description |
| `map` | Location mentioned | Map centered on service area with optional pin |
| `scoping` | Service chosen | Dynamic form (text/number/select/radio/checkbox fields) |
| `quote` | Scoping complete | Low/high price range with currency + CTAs |
| `calendar` | Ready to book | Date list with available time slots |
| `product` | Recommending an item | Single catalog item: name, price, interval, badge |
| `cart` | Items selected | Line-item list with total + checkout CTA |
| `severity` | Emergency triage | Critical / Urgent / Scheduled options with colors |
| `dispatch` | Tech assigned | Tech name, phone, ETA minutes, map link |
| `job-tracker` | Post-booking | Pipeline stages: Received → Assigned → En Route → On Site → Resolved |

### Schema reference

```typescript
// service-selector
{ kind: 'service-selector', services: [{ id, label, icon, description }] }

// map
{ kind: 'map', center: [lat, lng], zoom: number, pin?: [lat, lng], label?: string }

// scoping
{ kind: 'scoping', serviceId: string, title: string,
  fields: [{ id, label, type: 'text'|'number'|'select'|'radio'|'checkbox',
             options?: string[], required?: boolean }] }

// quote
{ kind: 'quote', low: number, high: number, currency: string,
  notes?: string, ctas: [{ label, action }] }

// calendar
{ kind: 'calendar', slots: [{ date: 'YYYY-MM-DD', times: ['9:00 AM', '1:00 PM'] }],
  jobType: string, location?: string }

// product
{ kind: 'product', id, name, description, price: number,
  interval?: 'month'|'year'|'once', badge?: string }

// cart
{ kind: 'cart', items: [{ id, name, price, interval? }], total: number }

// severity
{ kind: 'severity', options: [{ level: 'critical'|'urgent'|'scheduled',
  label, description, color }] }

// dispatch
{ kind: 'dispatch', ref: string, etaMinutes: number, etaFormatted: string,
  techName: string, phone: string, mapUrl?: string }

// job-tracker
{ kind: 'job-tracker', ref: string,
  stages: [{ id, label, status: 'done'|'active'|'pending' }] }
```

---

## API routes

All routes live under `/api/field-service/[slug]/`. The `[slug]` is the
agent's `name` field (e.g. `ptcorp-service`, `my-plumber`). Requests are
proxied by the Cloudflare Worker; D1 is the datastore.

### `GET /api/field-service/[slug]/slots`

Returns the next 10 business days with available time slots.

```
Query params (optional, for future per-agent slot config):
  jobType    — job type string
  lat, lng   — location coordinates

Response:
  { slots: [{ date: 'YYYY-MM-DD', times: ['9:00 AM', '1:00 PM'] }] }
```

### `POST /api/field-service/[slug]/book`

Creates a booking in `field_service_bookings`. Called automatically by
chat.ts when booking JSON is detected in a user message.

```
Body (JSON):
  company*        string
  contactName*    string
  email*          string
  phone           string
  jobType*        string
  sector          string
  locationLat     number
  locationLng     number
  locationLabel   string
  slotDate        string   YYYY-MM-DD
  slotTime        string   e.g. "9:00 AM"
  notes           string
  stripeSessionId string

Response 201:
  { ref: 'ABC-2026-1234', confirmation: 'Booking received.' }
```

Ref prefix is auto-derived from the slug: first word uppercased to 3 chars
(e.g. `ptcorp-service` → `PTC`, `my-plumber` → `MYP`).

### `POST /api/field-service/[slug]/checkout`

Creates a Stripe Checkout session for cart items. Requires
`STRIPE_SECRET_KEY` env var; falls back to a demo redirect if not set.

```
Body: { items: [{ id, name, price, interval? }] }

Response: { url: string }   — Stripe hosted page or demo redirect
```

Success URL: `/studio/[slug]?booking=confirm`
Cancel URL: `/studio/[slug]`

### `GET /api/field-service/[slug]/jobs/[ref]`

Returns a booking by ref with computed stage pipeline.

```
Response:
  { ref, clientSlug, status, company, contactName, jobType,
    locationLabel, slotDate, slotTime, createdAt, updatedAt,
    stages: [{ label, done }] }
```

### `PATCH /api/field-service/[slug]/jobs/[ref]`

Advances a booking's status.

```
Body: { status: 'received'|'scheduled'|'en-route'|'on-site'|'resolved' }
Response: { ok: true }
```

---

## Database

Migration `0029_field_service_bookings.sql` creates `field_service_bookings`:

```sql
CREATE TABLE field_service_bookings (
  id TEXT PRIMARY KEY,
  client_slug TEXT NOT NULL,   -- agent name / slug
  ref TEXT NOT NULL UNIQUE,    -- e.g. PTC-2026-1234
  company TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  job_type TEXT NOT NULL,
  sector TEXT,
  location_lat REAL,
  location_lng REAL,
  location_label TEXT,
  slot_date TEXT,
  slot_time TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'received',
  stripe_session_id TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

All queries are filtered by `client_slug`. The ptcorp legacy table
(`ptcorp_bookings`, migration 0028) is kept intact for backward compatibility.

---

## Ops dashboard

`/studio/field-service-dashboard?key=[SERVER_SECRET]&slug=[agentId]`

- Auth: `Authorization: Bearer [SERVER_SECRET]` header or `?key=` param
- `?slug=` filters to one agent; omit to show all agents
- Shows: emergency alerts, 4 stats (total / active / emergencies / this week), booking table
- Action buttons PATCH the job status via the generic API

The ptcorp-specific dashboard (`/studio/ptcorp-dashboard`) remains for
existing bookmarks; it reads from `ptcorp_bookings` directly.

---

## Booking flow (automatic)

When `field-service-dispatch` is active, `chat.ts` watches every user
message for a booking JSON object emitted by the calendar card:

```json
{
  "booking": {
    "date": "2026-05-20",
    "time": "9:00 AM",
    "jobType": "Fiber repair",
    "location": "Ottawa, ON",
    "company": "ACME Corp",
    "contactName": "Jane Smith",
    "email": "jane@acme.com"
  }
}
```

On detection:
1. POSTs to `/api/field-service/[agentId]/book`
2. Stores the returned `ref`
3. Injects a suffix into the system prompt: `[Booking confirmed — ref: PTC-2026-1234. Call emit_field_service_card with kind "job-tracker" ...]`
4. The LLM emits the `job-tracker` card confirming the booking

---

## Card usage guide (for agent prompts)

```
Opening message            → service-selector
Location / geography       → map
Service chosen             → scoping form
Scoping answers complete   → quote (low/high range)
Catalog recommendation     → product
Multiple items selected    → cart → checkout
Ready to book slot         → calendar (fetch /api/field-service/[slug]/slots)
Emergency triage           → severity
Critical severity selected → dispatch
Booking confirmed          → job-tracker (ref from auto-booking)
```

Copy this table into your agent's system prompt so the LLM knows when to
emit which card.

---

## Template

`agents/templates/field-service-agent.md` is a copy-paste starter. It
includes the frontmatter, card usage guide, and booking flow docs.

---

## See also

- `agent-authoring.md` — full frontmatter reference, `features` field
- `agents/ptcorp-sales.md` / `agents/ptcorp-service.md` — live examples
- `agents/templates/field-service-agent.md` — copy-paste starter
- `migrations/0029_field_service_bookings.sql` — D1 schema
- `src/lib/field-service-cards.ts` — Zod schemas for all 10 card kinds
- `src/components/chat/FieldServiceCardRenderer.tsx` — card renderer
