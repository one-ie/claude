# boq.md — BOQ Empire sales pipeline on ONE

**Principle.** BOQ Empire's discovery-call booking and lead pipeline run
entirely on ONE chat. One feature flag adds four branded cards, persists
every booked call to D1, and surfaces a pipeline dashboard for the team.

```
visitor message
  │
  ▼
chat agent (features: [discovery-pipeline])
  │   emit_boq_card → boq-package | boq-discovery | boq-quote | boq-onboarding
  │   discovery card confirm → POST /api/discovery/boq-empire → id
  │   status change          → PATCH /api/discovery/boq-empire { id, status }
  ▼
discovery_calls (D1, client_slug = 'boq-empire')
  │
  ▼
/studio/discovery-dashboard?slug=boq-empire&key=[SERVER_SECRET]
```

---

## Opt in

```yaml
features: [discovery-pipeline]
```

That one line on `boq-empire.md` enables the `emit_boq_card` tool and
routes discovery-call bookings to `/api/discovery/[agentSlug]`.

---

## The 4 card kinds

All rendered by `BoqCardRenderer` (dispatch in `MessageList.tsx`). The LLM
calls `emit_boq_card` with one of these `kind` values.

| Kind | Stage | What it shows |
|------|-------|---------------|
| `boq-package` | Pricing overview | Package grid with price, interval, features, CTA |
| `boq-discovery` | Ready to book | Date/time slot picker + agenda → books a discovery call |
| `boq-quote` | Custom quote | Tier, monthly/annual price, seat count, included features |
| `boq-onboarding` | Post-sale | Step-by-step onboarding checklist with owner and status |

### Schema reference

```typescript
// boq-package
{
  kind: 'boq-package',
  packages: [{
    id: string,
    name: string,
    price: number | 'custom',
    interval?: 'month' | 'year',
    badge?: string,
    features: string[],
    cta: string,
    tone?: 'primary' | 'secondary' | 'tertiary',
  }]
}

// boq-discovery
{
  kind: 'boq-discovery',
  host: string,          // e.g. "Donal O'Brien"
  role: string,          // e.g. "BOQ Empire Partner"
  agentSlug?: string,    // e.g. "boq-empire" — used to POST to /api/discovery/[slug]
  slots: [{ date: 'YYYY-MM-DD', times: ['10:00 AM', '2:00 PM'] }],
  duration: number,      // minutes, e.g. 30
  agenda: string[],      // bullet list shown on the card
  contactName?: string,  // pre-filled from conversation context
  contactEmail?: string,
  contactCompany?: string,
}

// boq-quote
{
  kind: 'boq-quote',
  tier: string,
  monthly: number,
  annual: number,
  seats: number | 'unlimited',
  includes: string[],
  ctas: [{ label: string, action: string }],
}

// boq-onboarding
{
  kind: 'boq-onboarding',
  title: string,
  steps: [{
    id: string,
    label: string,
    description: string,
    status: 'done' | 'active' | 'upcoming',
    owner?: string,
  }],
}
```

---

## API routes

Generic routes at `/api/discovery/[slug]`. The `[slug]` is the agent's `name`
field from frontmatter (e.g. `boq-empire`). Any agent with `features: [discovery-pipeline]`
gets its calls partitioned by slug in the shared `discovery_calls` table.

### `POST /api/discovery/[slug]`

Books a discovery call. Called by `BoqDiscoveryCard` on confirm (non-blocking).

```
Body (JSON):
  host*           string   — host name from the card
  callDate*       string   — YYYY-MM-DD
  callTime*       string   — e.g. "10:00 AM"
  duration        number   — minutes (default 30)
  contactName     string
  contactEmail    string
  contactCompany  string

Response 201:
  { id: uuid, confirmation: 'Discovery call scheduled.' }
```

### `PATCH /api/discovery/[slug]`

Updates the pipeline status or notes for a call. Scoped to the slug.

```
Body (JSON):
  id*     string   — UUID from the POST response
  status  string   — one of the pipeline values below
  notes   string   — free-text notes (stored verbatim)

Response:
  { ok: true }
```

### `GET /api/discovery/[slug]`

Returns the 100 most recent calls for the slug. Used by the dashboard.

```
Response:
  { calls: Call[] }
```

---

## Pipeline status lifecycle

```
scheduled
  │
  ├─ completed ─── qualified ─── proposal-sent ─── closed-won
  │
  └─ no-show ────────────────────────────────────── closed-lost
```

| Status | Meaning |
|--------|---------|
| `scheduled` | Call booked, not yet occurred |
| `completed` | Call happened, outcome TBD |
| `no-show` | Prospect didn't attend |
| `qualified` | Post-call: prospect is a fit |
| `proposal-sent` | Quote sent |
| `closed-won` | Deal signed |
| `closed-lost` | Deal lost |

Status advances forward; the dashboard's action buttons PATCH
`/api/discovery/[slug]` to move a call along.

---

## Database

Migration `0030_discovery_calls.sql` creates the shared `discovery_calls` table.
All agents with `features: [discovery-pipeline]` share this table, partitioned
by `client_slug`.

```sql
CREATE TABLE discovery_calls (
  client_slug TEXT NOT NULL,   -- agent name / slug
  id TEXT PRIMARY KEY,
  host TEXT NOT NULL,
  contact_name TEXT,
  contact_email TEXT,
  contact_company TEXT,
  call_date TEXT NOT NULL,        -- YYYY-MM-DD
  call_time TEXT NOT NULL,        -- e.g. "10:00 AM"
  duration INTEGER NOT NULL DEFAULT 30,
  status TEXT NOT NULL DEFAULT 'scheduled',
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- status values: scheduled | completed | no-show | qualified | proposal-sent | closed-won | closed-lost
```

Indexes: `status`, `host`, `created_at DESC`.

---

## Pre-populating contact details

If the conversation has already captured the prospect's name, email, or
company, pass those into the discovery card so the booking is richer:

```json
{
  "kind": "boq-discovery",
  "host": "Donal O'Brien",
  "role": "BOQ Empire Partner",
  "duration": 30,
  "slots": [
    { "date": "2026-05-20", "times": ["10:00 AM", "2:00 PM", "4:00 PM"] },
    { "date": "2026-05-21", "times": ["9:00 AM", "11:00 AM"] }
  ],
  "agenda": [
    "Current marketing setup and pain points",
    "BOQ Empire platform walkthrough",
    "Package fit and pricing"
  ],
  "contactName": "Jane Smith",
  "contactEmail": "jane@acme.com",
  "contactCompany": "ACME Corp"
}
```

These are stored alongside the booking in D1 and shown in the dashboard.

---

## Pipeline dashboard

`/studio/discovery-dashboard?slug=boq-empire&key=[SERVER_SECRET]`

The dashboard is generic — any `discovery-pipeline` agent uses the same page,
filtered by `?slug=`. Omit `slug` to see all agents' calls in one view.

- Auth: `?key=` param matched against `SERVER_SECRET` env var
- **No-show alerts** — calls with `status=no-show` shown as an alert strip
- **Upcoming calls** — calls with `status=scheduled` and future date
- **Stats** — total calls, this week, qualified, closed-won
- **Pipeline funnel** — proportional bar chart across all 5 forward stages
- **Full table** — all calls, with inline status advancement buttons
- Action buttons form-POST to `/api/discovery/[slug]` with `{ id, status: next }`

---

## Card usage guide (for agent prompts)

```
Asking about BOQ                   → boq-package (show tiers)
Specific requirements / budget     → boq-quote (custom numbers)
Ready to talk to a human           → boq-discovery (book a call)
Deal signed, onboarding starts     → boq-onboarding (track steps)
```

Copy this table into the agent's system prompt so the LLM knows when to
emit which card.

---

## See also

- `agent-authoring.md` — full frontmatter reference, `features` field
- `agent-features.md` — platform feature registry (`discovery-pipeline` entry)
- `agents/boq-empire.md` — live agent with `features: [discovery-pipeline]`
- `migrations/0030_discovery_calls.sql` — D1 schema (multi-tenant, `client_slug`)
- `src/lib/boq-cards.ts` — Zod schemas for all 4 card kinds
- `src/components/chat/cards/BoqDiscoveryCard.tsx` — discovery card component
- `src/pages/api/discovery/[slug].ts` — GET / POST / PATCH endpoint
- `src/pages/studio/discovery-dashboard.astro` — generic pipeline dashboard
