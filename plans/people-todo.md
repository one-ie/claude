# people-todo.md

<!-- classifier v2.1.0
spec: Y
variance: Y
exit: Y — bun run verify passes; PersonHero above fold; PeopleCard in actors list
files: Y
mode: mixed
lifecycle: construction
tier: COMPLEX
demo.command: bunx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0
requires_playwright: false
context_triggers:
  - pattern: "isa actor|has aid|typedbQuery"
    inject: one/marketing-schema.tql
  - pattern: "InboxEntity|filterInbox|TABS_BY_DIM"
    inject: web/src/data/in-types.ts
-->

---

## Status

- [x] **Cycle 1** — Types & Schema
  - [x] W0 Baseline
  - [x] W1 Recon
  - [x] W2 Decide
  - [x] W3 Edit
  - [x] W4 Verify
- [x] **Cycle 2** — PeopleCard + Sort
  - [x] W0 Baseline
  - [x] W1 Recon
  - [x] W2 Decide
  - [x] W3 Edit
  - [x] W4 Verify
- [x] **Cycle 3** — PersonHero
  - [x] W0 Baseline
  - [x] W1 Recon
  - [x] W2 Decide
  - [x] W3 Edit
  - [x] W4 Verify
- [x] **Cycle 4** — Profile Tabs
  - [x] W0 Baseline
  - [x] W1 Recon
  - [x] W2 Decide
  - [x] W3 Edit
  - [x] W4 Verify
- [x] **Cycle 5** — Power Features
  - [x] W0 Baseline
  - [x] W1 Recon
  - [x] W2 Decide
  - [x] W3 Edit
  - [x] W4 Verify

---

## LOCKED — Naming Rule

One word beats two. Plain beats formal. Schema.org is listed for traceability only.
The TS key and TypeDB attr are always the shortest clear name.

---

## LOCKED — Ontology Map

### Identity — schema.org/Person + vCard `N`/`FN`

| schema.org | vCard | TypeDB attr | TS key | Label |
|---|---|---|---|---|
| `name` | `FN` | `name` | `name` | Name |
| `givenName` | `N.given` | `first-name` | `firstName` | First |
| `familyName` | `N.family` | `last-name` | `lastName` | Last |
| `additionalName` | `N.additional` | `nickname` | `nickname` | Nickname |
| `honorificPrefix` | `N.prefix` | `title` | `title` | Title |
| `image` | `PHOTO` | `avatar` | `avatar` | Avatar |
| `description` | `NOTE` | `bio` | `bio` | Bio |
| `birthDate` | `BDAY` | `birthday` | `birthday` | Birthday |
| `gender` | `GENDER` | `gender` | `gender` | Gender |
| `nationality` | — | `nationality` | `nationality` | Nationality |
| — | `TZ` | `timezone` | `timezone` | Timezone |
| `knowsLanguage` | `LANG` | `language` | `languages` | Languages |

### Contact — schema.org/ContactPoint + vCard `ADR`/`TEL`/`EMAIL`/`URL`

| schema.org | vCard | TypeDB attr | TS key | Label |
|---|---|---|---|---|
| `email` | `EMAIL` | `email` | `email` | Email |
| `telephone` | `TEL` | `phone` | `phone` | Phone |
| `url` | `URL` | `website` | `website` | Website |
| `address.streetAddress` | `ADR.street` | `street` | `street` | Street |
| `address.addressLocality` | `ADR.locality` | `city` | `city` | City |
| `address.addressRegion` | `ADR.region` | `region` | `region` | Region |
| `address.postalCode` | `ADR.code` | `postcode` | `postcode` | Postcode |
| `address.addressCountry` | `ADR.country` | `country` | `country` | Country |

### Professional — schema.org/Person + vCard `ORG`/`TITLE`/`ROLE`

| schema.org | vCard | TypeDB attr | TS key | Label |
|---|---|---|---|---|
| `jobTitle` | `TITLE` | `job-title` | `jobTitle` | Job title |
| `worksFor.name` | `ORG.orgName` | `company` | `company` | Company |
| `department` | `ORG.orgUnit` | `department` | `department` | Department |
| `roleName` | `ROLE` | `role` | `role` | Role |

### Social Links — schema.org `sameAs` + FOAF `OnlineAccount`

TypeDB: `(person: $a, target: $l) isa link` where `$l` owns `platform` + `url` + `handle`.
Platforms: `linkedin` · `twitter` · `github` · `facebook` · `instagram` · `youtube` · `custom`

```ts
interface Link { platform: string; url: string; handle?: string }
```

### CRM Extensions

| Field | TypeDB attr | TS key | Label |
|---|---|---|---|
| Lifecycle | `lifecycle-stage` | `lifecycle` | Lifecycle |
| Fit 0–100 | `fit-score` | `fit` | Fit |
| Value | `ltv` | `value` | Value |
| Source | `source` | `source` | Source |
| NPS | `nps` | `nps` | NPS |
| CSAT | `csat` | `csat` | CSAT |
| Email ✓ | `consent-email` | `consent.email` | Email ✓ |
| SMS ✓ | `consent-sms` | `consent.sms` | SMS ✓ |
| Push ✓ | `consent-push` | `consent.push` | Push ✓ |
| Call ✓ | `consent-call` | `consent.call` | Call ✓ |
| First seen | derived | `firstSeen` | First seen |
| Last seen | derived | `lastSeen` | Last seen |
| Engagement | derived | `engagement` | Engagement |
| Messages | derived | `messages` | Messages |

---

## LOCKED — Detail Panel Design

Three questions answered before scrolling: **Who?** · **Reach?** · **Worth it?**

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  [Avatar 72px]  Full Name              ← text-xl    │
│   lifecycle      Job title @ Company   ← text-sm    │
│   ring +         Dublin, Ireland       ← text-xs    │
│   fit gap        🔗 li  tw  gh         ← icon row   │
│                                                      │
│  [Message]  [Call]  [Email]  [+ Note]               │
│                                                      │
│  ███████░░ Fit 84   ·   £24k   ·   ● Customer ▾     │
│                                                      │
└──────────────────────────────────────────────────────┘
  Overview · Personal · Professional · Notes · Messages ···
```

Ring colour = lifecycle stage. Ring gap = profile completeness.
Replaces ProfileCompletionBar (removed) and generic EntityDetail actor header (removed).
All fields click-to-edit inline via `useInlineEdit` hook — no edit mode.
Tabs: first 6 visible, rest `overflow-x-auto scrollbar-hide`.

---

## Cycle 1 — Types & Schema

**Goal:** Define `Person` TypeScript type, update TypeDB schema, enrich data pipeline.
No UI changes. All downstream cycles depend on this.

### W0 — Baseline

- [ ] `bun run verify` passes before any edits
- [ ] Capture `TSC_ERRORS=$(bunx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)`

### W1 — Recon
*(≥6 files → spawn w1-recon agents in one message, model: haiku)*

- [ ] `web/src/lib/crm/actor.ts` — current ContactHeader interface, getContact() attr mappings, existing field names
- [ ] `web/src/data/in-types.ts` — InboxEntity interface, EXPECTED_FIELDS.actors array
- [ ] `web/src/pages/api/export/actors.ts` — current TypeDB query fields returned
- [ ] `web/src/pages/api/actors/[id]/index.ts` — current response shape, existing query params
- [ ] `web/src/components/in/Inbox.tsx` lines 260–285 — actor entity construction, current mapped fields
- [ ] `one/marketing-schema.tql` — all attribute type declarations on actor (find existing attrs to avoid redeclaring)

Report per file: current field names, line numbers for key anchors, gaps vs ontology map.

### W2 — Decide
*(Opus — do not delegate)*

- [ ] Confirm: `Person` supersedes `ContactHeader`; keep `ContactHeader = Person` alias so existing imports don't break
- [ ] Confirm: `Consent` replaces `ConsentMatrix`; keep `ConsentMatrix = Consent` alias
- [ ] Confirm: `Address` replaces `ContactAddress`
- [ ] Compress check — `Person` type:
  - PRIMITIVE: Person interface with 30+ fields
  - COMPOSE: ContactHeader (id/name/email/phone/lifecycle/fit/ltv/consent/channels) + entity.tags + entity.properties
  - VERDICT: extend (ContactHeader → Person, alias preserved)
- [ ] Compress check — `link` relation in TypeDB:
  - PRIMITIVE: linked-profile entity + link relation
  - COMPOSE: same-as relation (identity merge), tag-based social URLs
  - VERDICT: new — social profiles are first-class contacts data, not identity merge candidates
- [ ] Confirm 7 enriched fields for export/actors: `jobTitle`, `company`, `avatar`, `lifecycle`, `fit`, `value`, `lastSeen`
- [ ] Confirm `?include=threads` on `/api/actors/[id]` (not a new endpoint — query param)
- [ ] Tag TODO type: `feature`
- [ ] Rubric targets: security 0.85 · stability 0.80 · simplicity 0.85 · speed 0.75

### W3 — Edit
*(5 agents in one message, model: sonnet)*

- [ ] **Agent A** · `web/src/lib/crm/actor.ts`
  - [ ] Add `Link`, `Address`, `Consent` interfaces (before `Person`)
  - [ ] Replace `ContactHeader` interface body with `Person` (all fields from ontology map)
  - [ ] Add `export type ContactHeader = Person` and `export type ConsentMatrix = Consent` aliases after
  - [ ] Extend `getContact()` `first()`/`list()` mappings for all new fields from ontology map
  - [ ] Add `buildAddress(attrs)` helper extracting street/city/region/postcode/country
  - [ ] Add second TypeDB query for `link` relation (platform + url + handle per actor)
  - [ ] Fix `fit` mapping: `Number(first('fit-score'))` not raw string; `value` from `ltv`

- [ ] **Agent B** · `web/src/data/in-types.ts`
  - [ ] Add `PersonMeta` interface: `jobTitle? company? avatar? lifecycle? fit? value? lastSeen? consent?`
  - [ ] Add `personMeta?: PersonMeta` field to `InboxEntity`
  - [ ] Add `'personMeta'` to `EXPECTED_FIELDS.actors` array

- [ ] **Agent C** · `one/contact-schema.tql` (new file)
  - [ ] Read `one/marketing-schema.tql` first — check which attrs already declared
  - [ ] Declare only missing attrs from ontology map: `first-name`, `last-name`, `nickname`, `title`, `avatar`, `bio`, `birthday`, `nationality`, `timezone`, `language`, `website`, `street`, `city`, `region`, `postcode`, `country`, `job-title`, `company`, `department`, `role`, `source`
  - [ ] Declare `linked-profile` entity owning `platform`, `url`, `handle`
  - [ ] Declare `link` relation: `actor plays link:person; linked-profile plays link:target`

- [ ] **Agent D** · `web/src/pages/api/export/actors.ts`
  - [ ] Extend TypeDB query to fetch `job-title`, `company`, `avatar`, `lifecycle-stage` (or `status`), `fit-score`, `ltv` attrs per actor
  - [ ] Map response: `jobTitle`, `company`, `avatar`, `lifecycle`, `fit` (as integer 0–100), `value`, `lastSeen`

- [ ] **Agent E** · `web/src/pages/api/actors/[id]/index.ts`
  - [ ] Add `include` query param check: `url.searchParams.get('include')`
  - [ ] When `include === 'threads'`: query D1 threads where `user_cookie = actorId`, append `threads[]` to response
  - [ ] Keep existing response shape intact — threads is additive

### W4 — Verify

- [ ] `bunx tsc --noEmit` — 0 errors (`delta_tsc ≤ 0`)
- [ ] `bun run verify` — biome + tsc pass
- [ ] `grep -r "ConsentMatrix\b" web/src --include="*.ts" --include="*.tsx"` — only alias declaration (no raw usage of old type)
- [ ] `grep -r "fitScore\|fit-score\|fit_score" web/src/lib/crm` — 0 hits (renamed to `fit`)
- [ ] `grep -r "ltv\b" web/src/lib/crm/actor.ts` — only in `first('ltv')` mapping line (field mapped to `value`)
- [ ] No runtime error on `GET /api/export/actors` — returns enriched shape

---

## Cycle 2 — PeopleCard + Sort

**Goal:** Rich list card for actors with lifecycle ring, fit strip, consent dots, value.
Sort controls in ListHeader. No changes to detail panel yet.

### W0 — Baseline

- [ ] `bun run verify` passes
- [ ] Capture baseline `TSC_ERRORS`

### W1 — Recon
*(4 files → read directly in main context)*

- [ ] `web/src/components/in/EntityCard.tsx` — exact selected/unread/tag render pattern to mirror
- [ ] `web/src/components/in/Inbox.tsx` lines 706–739 — EntityList function, current card render call
- [ ] `web/src/components/in/ListHeader.tsx` — current props, export shape
- [ ] `web/src/components/in/Inbox.tsx` lines 125–135, 163–166 — dimension/preset state, entities useMemo

Report: exact line + function name for the card render call in EntityList; ListHeader props interface.

### W2 — Decide

- [ ] Confirm: `PeopleCard` is a new component (not modifying EntityCard) — actors need different render
- [ ] Confirm: sort state (`sortBy`, `sortDir`) lives in `Inbox.tsx`, passed to `ListHeader` as props
- [ ] Confirm: sort is client-side only — no backend change
- [ ] Compress check — sort:
  - PRIMITIVE: sortBy/sortDir state + sort comparator
  - COMPOSE: existing `filterInbox()` in `in-types.ts` (already sorts by status)
  - VERDICT: extend — add optional `sortBy` param to `filterInbox()` or apply after in useMemo
- [ ] Tag TODO type: `feature`
- [ ] Rubric targets: security 0.85 · stability 0.85 · simplicity 0.80 · speed 0.80

### W3 — Edit
*(4 agents in one message, model: sonnet)*

- [ ] **Agent A** · `web/src/components/in/PeopleCard.tsx` (new file)
  - [ ] Avatar 36px circle with SVG lifecycle ring (coloured stroke) + `avatar` image or initials fallback
  - [ ] Lifecycle ring colours: lead=`var(--color-tertiary)` · prospect=`var(--color-secondary)` · customer=`var(--color-primary)` · advocate=`var(--color-success)` · default=`rgba(255,255,255,0.1)`
  - [ ] Name (`text-sm font-semibold`) + role line (`jobTitle @ company`, `text-xs text-font/60`, hidden if both null)
  - [ ] Fit strip: `h-0.5 w-full rounded-full bg-font/10` + fill `bg-tertiary` at `fit%`, hidden if `fit` null
  - [ ] Consent dots: 4 × 5px circles — `bg-success` granted · `bg-destructive` denied · `bg-font/20` unknown
  - [ ] Right meta: value (`£X.Xk`), lifecycle badge pill, last seen (`lastSeen` relative)
  - [ ] Selected state: `border-primary/30 bg-primary/5` + left `w-0.5 bg-primary` bar (mirrors EntityCard)
  - [ ] `emitClick('ui:people:select', { id: entity.id })` on click
  - [ ] `React.memo` wrapping

- [ ] **Agent B** · `web/src/hooks/use-inline-edit.ts` (new file)
  - [ ] `useInlineEdit(uid: string)` hook returns `edit(field: string, value: unknown) => void`
  - [ ] Optimistic: update caller's local state immediately (callback pattern)
  - [ ] `POST /api/signal/${encodeURIComponent(uid + ':update')}` with `{ field, value }`
  - [ ] On error: call revert callback + `toast.error('Failed to save')`
  - [ ] `isEditing: boolean` state — one field at a time
  - [ ] Returns `{ edit, isEditing }`

- [ ] **Agent C** · `web/src/components/in/Inbox.tsx`
  - [ ] Actor entity construction (~line 261): add `personMeta: { jobTitle, company, avatar, lifecycle, fit, value, lastSeen }` mapping from export response fields
  - [ ] `EntityList` function: when `entity.dimension === 'actors'` render `<PeopleCard>` instead of `<EntityCard>`
  - [ ] Add `sortBy: string, sortDir: 'asc' | 'desc'` state (default `'lastSeen'`, `'desc'`)
  - [ ] Apply sort in `entities` useMemo after `filterInbox()` call (actors only, switch on sortBy)

- [ ] **Agent D** · `web/src/components/in/ListHeader.tsx`
  - [ ] Add `sortBy?: string; sortDir?: 'asc'|'desc'; onSort?: (by: string, dir: 'asc'|'desc') => void` to props
  - [ ] When `dimension === 'actors'`: render inline sort picker (`text-[11px]`, right-aligned)
  - [ ] Options: Name · Fit · Value · Last seen · Status
  - [ ] Active option highlighted `text-primary`; click toggles dir, new selection resets to desc

### W4 — Verify

- [ ] `bunx tsc --noEmit` — 0 errors
- [ ] `bun run verify` — biome pass
- [ ] `grep -r "PeopleCard" web/src/components/in/Inbox.tsx` — 1 hit (import + render call)
- [ ] Actors list renders `PeopleCard` (not `EntityCard`) — confirm via grep: `<PeopleCard` in Inbox.tsx
- [ ] `grep -r "useInlineEdit" web/src/hooks/use-inline-edit.ts` — file exists, exports hook
- [ ] No TypeScript error on `personMeta` access in PeopleCard (field defined in C1)

---

## Cycle 3 — PersonHero

**Goal:** Above-fold contact identity. Replace both the generic EntityDetail actor header
and ContactHeader-in-Overview with PersonHero. Remove ProfileCompletionBar for actors.

### W0 — Baseline

- [ ] `bun run verify` passes
- [ ] Capture baseline `TSC_ERRORS`

### W1 — Recon
*(3 files → read directly in main context)*

- [ ] `web/src/components/in/EntityDetail.tsx` lines 195–260 — generic actor header block, ProfileCompletionBar, TABS_BY_DIM.actors array (exact line numbers)
- [ ] `web/src/components/crm/ContactHeader.tsx` — full file (75 lines) — what to retire
- [ ] `web/src/hooks/use-actor-contact.ts` — hook shape, return type

Report: exact `<header` block start/end lines in EntityDetail; exact ProfileCompletionBar component usage line.

### W2 — Decide

- [ ] Confirm: `PersonHero` is a new component (`web/src/components/crm/PersonHero.tsx`)
- [ ] Confirm: `EntityDetail.tsx` detects `entity.dimension === 'actors'` to render PersonHero instead of generic `<header>` + ProfileCompletionBar
- [ ] Confirm: `ContactHeader.tsx` is NOT deleted yet — keep as deprecated stub (Cycle 4 removes its usage from Overview tab)
- [ ] Confirm: avatar SVG ring uses `stroke-dasharray` for completeness gap + lifecycle colour
- [ ] Compress check — action row:
  - PRIMITIVE: 4 buttons (Message/Call/Email/Note) in hero
  - COMPOSE: `EntityActionBar` already has action buttons
  - VERDICT: extend — PersonHero uses same signal pattern but different layout (hero vs footer)
- [ ] Tag TODO type: `feature`
- [ ] Rubric targets: security 0.85 · stability 0.80 · simplicity 0.85 · speed 0.75

### W3 — Edit
*(3 agents in one message, model: sonnet)*

- [ ] **Agent A** · `web/src/components/crm/PersonHero.tsx` (new file)
  - [ ] Props: `{ person: Person; entity: InboxEntity; onAction: (verb: string) => void; viewer: Viewer }`
  - [ ] Avatar 72px: `<svg>` ring with `stroke-dasharray` — outer stroke = lifecycle colour, gap fraction = `1 - profileComplete(person)/100`
  - [ ] `profileComplete(person)`: count non-null across `[firstName,lastName,email,phone,jobTitle,company,bio,city,country,avatar]` → `filled/10 × 100`
  - [ ] Avatar image (`<img>`) if `person.avatar`; else initials div (`firstName[0] + lastName[0]` or `name[0..1]`)
  - [ ] Name: `text-xl font-bold text-font`, inline edit via `useInlineEdit` — click → `<input autoFocus>`
  - [ ] Role line: `{jobTitle} @ {company}` — `text-sm text-font/70`; each click-to-edit independently
  - [ ] Location: `{city}, {country}` — `text-xs text-font/40`; hidden if both null
  - [ ] Social icons row: map `person.links` → platform icon (Lucide `Linkedin`/`Twitter`/`Github`; else `ExternalLink`); 14px, `text-font/40 hover:text-font`, opens new tab
  - [ ] Action row: Message (primary `bg-primary text-on-primary`) · Call · Email · + Note (ghost); Call/Email disabled if phone/email null; Note click fires `onAction('note')` which switches tab
  - [ ] Metrics strip (`border-t border-white/7 mt-4 pt-3`): fit bar + integer fit number · `£{value.toLocaleString()}` · lifecycle stage badge with `▾` → popover (Lead/Prospect/Customer/Advocate/Churned); lifecycle click fires `onAction('lifecycle')` signal

- [ ] **Agent B** · `web/src/components/in/EntityDetail.tsx`
  - [ ] Import `PersonHero` + `useActorContact` (already imported)
  - [ ] Replace the generic `<header>` block (lines reported by W1) with: `{entity.dimension === 'actors' ? <PersonHero person={contact?.header ?? null} entity={entity} onAction={...} viewer={viewer} /> : <header>...existing generic header...</header>}`
  - [ ] Remove `<ProfileCompletionBar>` render when `entity.dimension === 'actors'`
  - [ ] Update `TABS_BY_DIM.actors` to the 10-tab ordered list (Overview · Personal · Professional · Notes · Messages · Activity · Social · Intel · Network · Sources)
  - [ ] Tab row div: add `overflow-x-auto scrollbar-hide` class
  - [ ] Pass `viewer` prop through to `EntityDetail` (add to props interface if missing)

- [ ] **Agent C** · `web/src/components/crm/ContactHeader.tsx`
  - [ ] Add `/** @deprecated — use PersonHero */` JSDoc
  - [ ] Fix `fit-score` label to `Fit`; display `fitScore` as integer (`Math.round(fitScore)`) not decimal
  - [ ] Fix `ltv` label to `Value`; keep `£` formatting
  - [ ] Fix `lifecycle` label to `Stage` (removes duplicate — badge AND grid cell both said "lifecycle")

### W4 — Verify

- [ ] `bunx tsc --noEmit` — 0 errors
- [ ] `bun run verify` — biome pass
- [ ] `grep -n "PersonHero" web/src/components/in/EntityDetail.tsx` — 1 import + 1 render call
- [ ] `grep -n "ProfileCompletionBar" web/src/components/in/EntityDetail.tsx` — 0 hits for actors path (bar still exists for non-actors)
- [ ] `grep -n "overflow-x-auto scrollbar-hide" web/src/components/in/EntityDetail.tsx` — 1 hit (tab row)
- [ ] PersonHero file exists and exports `PersonHero` function
- [ ] Above-fold visual gate: PersonHero renders avatar + name + role + action row + metrics strip before any tab content

---

## Cycle 4 — Profile Tabs

**Goal:** Populate all 10 actor tabs with real content. Remove ContactHeader from Overview.
Inline editing on bio, address, personal fields. Notes and Messages tabs wired.
*Note: EntityDetail.tsx was edited in C3 — W3 agents read current file state.*

### W0 — Baseline

- [ ] `bun run verify` passes
- [ ] Capture baseline `TSC_ERRORS`

### W1 — Recon
*(5 files → spawn w1-recon agents in one message, model: haiku)*

- [ ] `web/src/components/in/EntityDetail.tsx` — current tab render blocks after C3 edits; exact line numbers for Overview, Personal, Professional, Intel, Sources, Network tab cases
- [ ] `web/src/components/crm/ContactActivity.tsx` — props interface (used in Activity tab; Notes will reuse pattern)
- [ ] `web/src/components/crm/ContactPaths.tsx` — props interface (Network tab)
- [ ] `web/src/components/crm/ContactAppended.tsx` — props interface (Sources tab)
- [ ] `web/src/components/crm/ContactSameAs.tsx` — props interface (Overview tab)

Report: exact line ranges for each tab case in EntityDetail; existing component prop shapes.

### W2 — Decide

- [ ] Confirm: `ContactHeader` render removed from Overview tab — PersonHero (C3) replaced it
- [ ] Confirm: `ContactNotes` is a new component reading activity where `event === 'note'`
- [ ] Confirm: `ContactMessages` reads `GET /api/actors/[id]?include=threads` (wired in C1)
- [ ] Confirm: Personal tab renders real fields (not tag-prefix filter) but ALSO keeps `ContactConsent` at bottom
- [ ] Confirm: Intel tab is purely client-side — no new backend; NBA banner derives from `person` data
- [ ] Compress check — Notes:
  - PRIMITIVE: ContactNotes component + note creation signal
  - COMPOSE: ContactActivity already polls and displays events; signal already exists for `:note`
  - VERDICT: extend — ContactNotes wraps ContactActivity with a composer at top (note events are activity events)
- [ ] Tag TODO type: `feature`
- [ ] Rubric targets: security 0.85 · stability 0.80 · simplicity 0.80 · speed 0.75

### W3 — Edit
*(4 agents in one message, model: sonnet)*

- [ ] **Agent A** · `web/src/components/crm/ContactNotes.tsx` (new file)
  - [ ] Props: `{ actorId: string; viewer: Viewer }`
  - [ ] Textarea at top + "Add note" button
  - [ ] On submit: `POST /api/signal/${encodeURIComponent(actorId + ':note')}` with `{ content, kind: 'note', ts: Date.now() }`; `emitClick('ui:people:note-add', { actorId })`
  - [ ] Note list: fetch from `GET /api/actors/${actorId}/activity?event=note` (or filter from `ContactActivity` initial prop); reverse-chronological
  - [ ] Each note: `<time>` + content + delete button (owner/agency only per `viewer`)
  - [ ] Delete: `POST /api/signal/${encodeURIComponent(actorId + ':note-delete')}` with `{ id }`

- [ ] **Agent B** · `web/src/components/crm/ContactMessages.tsx` (new file)
  - [ ] Props: `{ actorId: string; slug?: string }`
  - [ ] Fetch: `GET /api/actors/${actorId}?include=threads` — uses `useActorContact` or direct fetch
  - [ ] Collapsible thread list: each row shows last message preview + relative date + message count
  - [ ] Expand: inline `Conversation`/`Message` components (already in `@/components/ai-elements`)
  - [ ] "Open in chat" link: `/u/${slug}/chat?thread=${tid}` (hidden if no slug)
  - [ ] Empty state: "No conversations yet"

- [ ] **Agent C** · `web/src/components/in/EntityDetail.tsx` (personal + professional + social + intel + sources + overview tabs)
  - [ ] **Overview**: remove `ContactHeader` render; keep `ContactSameAs`; add quick-facts 2-col grid using `MetricTile` (First seen · Last seen · Messages · Source · NPS · Engagement)
  - [ ] **Personal**: replace tag-prefix filter with real `Person` fields (birthday+age · gender · nationality · languages · timezone · full address block); `ContactConsent` at bottom; all text fields use inline-edit affordance (`border-b border-transparent hover:border-font/20 cursor-text`)
  - [ ] **Professional**: job title · company · department · role (all inline-edit); industry/company-size/seniority tags as pills; skills (`skill:*` tags) pill row with `+` add button
  - [ ] **Notes**: render `<ContactNotes actorId={actorUid} viewer={viewer} />`
  - [ ] **Messages**: render `<ContactMessages actorId={actorUid} slug={slug} />`
  - [ ] **Social**: map `contact?.header.links ?? []` → link rows with platform icon · `@handle` · url; `ExternalLink` for custom
  - [ ] **Intel**: contact summary (bio or "N signals in last 30 days"); persona/JTBD/awareness tags; NBA banner — amber `bg-amber-500/10 border-amber-500/20` strip, first-match logic:
    - `lastSeen > 7 days` → "Follow up — {N} days quiet"
    - `consent.email === null` → "Request email consent"
    - merge candidates pending (from `ContactSameAs`) → "Review identity match"
    - `fit > 70 && value === null` → "Qualify — high fit, no value yet"
    - `lifecycle === 'lead' && fit < 30` → "Review — low fit score"
  - [ ] **Sources**: render `<ContactAppended rows={appended} />` (already wired); add Enrich button → `POST /api/signal/${uid}:enrich`; show "Last enriched" date from most recent appended row

- [ ] **Agent D** · `web/src/components/in/EntityDetail.tsx` (Activity + Network tabs — same file, W3b after Agent C)
  - [ ] **Activity**: `<ContactActivity actorId={actorUid} initial={[]} />` — already wired, keep
  - [ ] **Network**: MetricTile grid (Referrals · Conversations) + `<ContactPaths paths={paths} />`
  - [ ] Remove "No data in this tab yet." fallback for all actor tabs — replace with specific empty states per tab

### W4 — Verify

- [ ] `bunx tsc --noEmit` — 0 errors
- [ ] `bun run verify` — biome pass
- [ ] `grep -n "ContactHeader" web/src/components/in/EntityDetail.tsx` — 0 hits (removed from tab content)
- [ ] `grep -n "No data in this tab yet" web/src/components/in/EntityDetail.tsx` — 0 hits for actor tabs
- [ ] `ContactNotes` and `ContactMessages` files exist and export named functions
- [ ] All 10 tab IDs present in `TABS_BY_DIM.actors` in EntityDetail.tsx
- [ ] Intel tab NBA banner logic: confirm first-match cases are distinct (no duplicates)

---

## Cycle 5 — Power Features

**Goal:** Kanban pipeline view, bulk actions, smart segments, CSV export.

### W0 — Baseline

- [ ] `bun run verify` passes
- [ ] Capture baseline `TSC_ERRORS`

### W1 — Recon
*(4 files → read directly in main context)*

- [ ] `web/src/components/in/Inbox.tsx` — current state declarations, liveEntities shape, existing tagRail fetch pattern (lines 98–115)
- [ ] `web/src/components/in/ListHeader.tsx` — current props after C2 edits
- [ ] `web/src/pages/api/in/drafts.ts` — existing PUT handler shape (segments will reuse this)
- [ ] `web/src/pages/api/export/actors.ts` — current response shape (CSV will share this query)

Report: exact `tagRail` splice pattern in Inbox.tsx; existing ListHeader props post-C2; drafts PUT body shape.

### W2 — Decide

- [ ] Confirm: Kanban is a view-mode toggle — `viewMode: 'list' | 'kanban'` state in Inbox.tsx, renders `PeopleKanban` or `EntityList` for actors
- [ ] Confirm: drag-to-stage fires `POST /api/signal/${uid}:lifecycle` + optimistic `personMeta.lifecycle` update
- [ ] Confirm: `BulkBar` floats above the list panel; checkbox state `selectedIds: Set<string>` lives in Inbox.tsx
- [ ] Confirm: segments stored via existing `PUT /api/in/drafts` (entityId: `segment:${name}`)
- [ ] Confirm: CSV export is a new endpoint — justified as binary/CSV response
- [ ] Compress check — kanban drag:
  - PRIMITIVE: drag-and-drop library or HTML5 drag events
  - COMPOSE: signal already exists for lifecycle update; optimistic update already done for save/archive
  - VERDICT: new (drag UI) + extend (reuse signal pattern) — use HTML5 drag events, no new library
- [ ] Tag TODO type: `feature`
- [ ] Rubric targets: security 0.85 · stability 0.75 · simplicity 0.75 · speed 0.80

### W3 — Edit
*(5 agents in one message, model: sonnet)*

- [ ] **Agent A** · `web/src/components/in/PeopleKanban.tsx` (new file)
  - [ ] Props: `{ entities: InboxEntity[]; onStageChange: (uid: string, stage: string) => void; onSelect: (id: string) => void; selectedId: string | null }`
  - [ ] 4 columns: Lead · Prospect · Customer · Advocate (Churned collapsed, toggle to show)
  - [ ] Each column header: label + count + total value sum (`£Xk`)
  - [ ] Column body: scrollable, sorted by `fit` desc; renders compact `PeopleCard` per entity
  - [ ] Drag: `draggable` attr on PeopleCard; `onDragOver` + `onDrop` on column; `onDrop` calls `onStageChange(uid, stage)` + `emitClick('ui:people:kanban-move', { uid, stage })`
  - [ ] Compact PeopleCard variant: hide contact line and consent dots; keep avatar + name + role + fit strip + value

- [ ] **Agent B** · `web/src/components/in/BulkBar.tsx` (new file)
  - [ ] Props: `{ count: number; onTag: () => void; onMessage: () => void; onExport: () => void; onArchive: () => void; onClear: () => void }`
  - [ ] Floats: `fixed bottom-4 left-1/2 -translate-x-1/2` or positioned above list
  - [ ] `{count} selected` · Tag · Message · Export · Archive · × Clear
  - [ ] Each button emits `emitClick('ui:people:bulk-{action}', { count })`

- [ ] **Agent C** · `web/src/components/in/Inbox.tsx`
  - [ ] Add `viewMode: 'list' | 'kanban'` state (default `'list'`); pass to ListHeader
  - [ ] Add `selectedIds: Set<string>` state (actors only); cleared on dimension change
  - [ ] In actors EntityList: checkbox on PeopleCard — `onChange` toggles `selectedIds`
  - [ ] Render `<PeopleKanban>` when `viewMode === 'kanban' && dimension === 'actors'`
  - [ ] `onStageChange` handler: optimistic update `personMeta.lifecycle` in `liveEntities` + fire signal
  - [ ] Render `<BulkBar>` when `selectedIds.size > 0`
  - [ ] BulkBar Export: `window.open('/api/export/people?ids='+[...selectedIds].join(',')+'&format=csv')`
  - [ ] Load saved segments on mount — same fetch pattern as tagRail (lines 98–115); `entityId` starts with `segment:` → splice into tagRail as TAGS zone items

- [ ] **Agent D** · `web/src/components/in/ListHeader.tsx`
  - [ ] Add `viewMode?: 'list' | 'kanban'; onViewMode?: (m: 'list'|'kanban') => void` to props
  - [ ] When `dimension === 'actors'`: render `List | Kanban` toggle (two buttons, active = `text-primary`)
  - [ ] When `dimension === 'actors'`: render bookmark icon → save-segment modal (name input + "Save" button)
  - [ ] Save segment: `PUT /api/in/drafts` with `{ entityId: 'segment:'+name, dimension, status, search: query }`
  - [ ] Emit `emitClick('ui:people:segment-save', { name })` on save

- [ ] **Agent E** · `web/src/pages/api/export/people.ts` (new file)
  - [ ] `GET /api/export/people?workspace=X&format=csv&ids=uid1,uid2&status=now`
  - [ ] Auth: same `workspaceContext` gate as export/actors.ts
  - [ ] Query: reuse actors TypeDB query; filter by `ids` param if present
  - [ ] CSV columns from ontology map: name · firstName · lastName · email · phone · website · jobTitle · company · city · country · lifecycle · fit · value · source · firstSeen · lastSeen
  - [ ] Response: `Content-Type: text/csv`, `Content-Disposition: attachment; filename="people.csv"`
  - [ ] Justified: binary/streaming response (CSV download)

### W4 — Verify

- [ ] `bunx tsc --noEmit` — 0 errors
- [ ] `bun run verify` — biome pass
- [ ] `grep -n "PeopleKanban\|BulkBar" web/src/components/in/Inbox.tsx` — 2 imports + 2 render calls
- [ ] `grep -n "viewMode" web/src/components/in/Inbox.tsx` — state declaration present
- [ ] `grep -n "selectedIds" web/src/components/in/Inbox.tsx` — Set state declared
- [ ] `web/src/pages/api/export/people.ts` exists; exports default handler
- [ ] CSV response: `Content-Type: text/csv` header present in handler
- [ ] Segment save: PUT body contains `entityId: 'segment:...'` — confirm shape matches drafts API

---

## Rubric targets (all cycles)

| Dimension | Weight | Target | Gate |
|---|---|---|---|
| Security | 0.35 | 0.85 | No PII leak, auth gates intact, no secrets in code |
| Stability | 0.30 | 0.80 | 0 tsc errors, 0 build errors, all handlers close loop |
| Simplicity | 0.25 | 0.80 | No duplicate headers, no raw attr names, clear naming |
| Speed | 0.10 | 0.75 | PersonHero lazy-loads Composer, no 281KB+ blocking imports |
| **Composite** | | **≥ 0.65** | All cycles must pass before Close |

---

## Close

```bash
/close --todo people --cycle 5
```

Pheromone: `mode:mixed lifecycle:construction surface:people`

Learnings entry (one line per cycle, append to `docs/learnings.md`):
`- {date} · people-c{N} · {wave}|{gate} · {one sentence} · rubric={composite} · source=w4`
