---
title: Channel Integration — Unified Inbox
slug: channels
type: plan
tier: complex
mode: construction
tags: [channels, messaging, inbox, signal, slack, telegram, discord]

goal: "A message sent in Slack, Telegram, or Discord becomes a signal in the substrate, appears in /in within 2s, and an agent bound to that channel can read and reply back out to the platform."
outcome: "bun vitest run tests/e2e/channels.test.ts"
outcome_asserts: "ingest() turns a platform payload into a contact actor + a signal + a deduped channel_inbox row; send() posts outbound; /api/export/all emits channel threads in the conversations shape; a bound agent is dispatched."

deliverables:
  - schema: schema/channels.tql — single channel entity (binding anchor) (C1)
  - migration: web/migrations/0060_channels.sql — channels + channel_inbox D1 tables (C1)
  - lib: agents/src/channels/connect.ts — connectChannel (TypeDB entity + D1 row + KV secret) (C1)
  - lib: agents/src/channels/inbound.ts — ingest(): verify-agnostic normalize→dedup→resolve-actor→write signal→write D1→notify relay (C2)
  - api: agents/src/channels/slack.ts — Slack webhook (verify+parse→ingest) + send adapter (C3)
  - api: agents/src/channels/telegram.ts — Telegram webhook + send adapter (C4)
  - api: agents/src/channels/discord.ts — Discord webhook + send adapter (C5)
  - api: web/src/pages/api/export/all.ts — channel_inbox → conversations branch (C6)
  - component: web/src/components/in/Inbox.tsx — 1-line tag passthrough + network rail filters (C6)
  - api: web/src/pages/api/threads/[id].ts — channel-thread reply → egress (C6)
  - api: web/src/pages/api/channels/bind.ts — capability binding + KV cache (C7)
  - lib: agents/src/channels/dispatch.ts — KV binding lookup → agent → egress reply (C7)
  - api: web/src/pages/api/integrations/oauth/[network].ts — OAuth start+callback → connectChannel (C8)
  - component: web/src/pages/settings/integrations.astro — Messaging group (Slack/Telegram/Discord connect) (C8)
  - doc: plans/channels.md — architecture spec (shipped)

ux_before: "Messages from Slack, Telegram, and Discord are invisible to ONE; an operator opens three apps and an agent cannot participate."
ux_after: "All channel messages appear in /in beside existing conversations; the operator replies from one place; bound agents respond automatically and their replies go back out to the platform."
ux_delta: "Three platform tabs become one inbox, channel senders become CRM contacts, and agent participation needs no human routing."

parallel_budget:
  haiku:   20
  sonnet:  10
  opus:    2

batches:
  - [C1]
  - [C2]
  - [C3, C4, C5]
  - [C6, C7, C8]

shared_recon:
  - plans/channels.md
  - schema/channels.tql
  - schema/one.tql
  - one.ie/web/src/components/in/Inbox.tsx
  - one.ie/web/src/pages/api/export/all.ts

source_of_truth:
  - plans/channels.md
  - schema/channels.tql
  - schema/one.tql

existing_primitives:
  - schema/one.tql signal relation: every channel message is a signal(sender,receiver,payload,ts) — C2 writes these, never a new message entity
  - one.ie/web/src/components/in/Inbox.tsx: renders conversations under dimension 'events' with SSE + reply — C6 reuses; only a tag passthrough + filter rows change
  - one.ie/web/src/pages/api/export/all.ts: aggregates workspace data into AllData.conversations — C6 adds one D1 query branch emitting the SAME conversation shape
  - one.ie/web/src/workers/AnalyticsRelay.ts: DO SSE fan-out on topic inbox:{slug}; Inbox already subscribes via /api/analytics/watch — C2 notifies it, NO new SSE endpoint
  - one.ie/web/src/pages/api/threads/[id].ts: existing thread reply handler the Inbox already POSTs to — C6 adds a channel→egress branch
  - schema/one.tql capability relation: capability(provider:actor, offered:channel) IS the agent binding — C7 writes these, never a new binding entity
  - schema/one.tql actor entity: channel senders are find-or-created actors (CRM contacts) — C2 reuses the existing contact resolution, never a new sender store

show: false
escape:
  condition: "C3/C4/C5 W4 shows duplicate channel_inbox rows (dedup unique index not firing) twice"
  action: "halt; re-verify INSERT OR IGNORE + unique(channel_id, message_external_id) in C1 migration before retrying"
context_triggers:
  - pattern: "signal\\(|signal.payload|dimension.*events"
    inject: "plans/channels.md § 2. The insight"
  - pattern: "AnalyticsRelay|analytics/watch|notify.*relay"
    inject: "plans/channels.md § 5. Architecture"
  - pattern: "conversations|convEntities|export/all"
    inject: "plans/channels.md § 6. pages/in"
---

# Channel Integration — Unified Inbox

## Goal, outcome, deliverables, UX

### Goal

A message sent in Slack, Telegram, or Discord becomes a `signal` in the substrate, appears in `/in` within 2s, and an agent bound to that channel can read and reply back out to the platform.

### Outcome (the kill-switch)

```bash
bun vitest run tests/e2e/channels.test.ts
```

**What passing proves:** `ingest()` turns a platform payload into a contact actor + a signal + a deduped `channel_inbox` row; `send()` posts outbound; `/api/export/all` emits channel threads in the `conversations` shape so the existing Inbox renders them; a bound agent is dispatched.

### Deliverables

| Kind | Path | What ships |
|---|---|---|
| schema | `schema/channels.tql` | single `channel` entity — the capability binding anchor (C1) |
| migration | `web/migrations/0060_channels.sql` | `channels` + `channel_inbox` D1 tables (C1) |
| lib | `agents/src/channels/connect.ts` | `connectChannel` — TypeDB entity + D1 row + KV secret (C1) |
| lib | `agents/src/channels/inbound.ts` | `ingest()` — the whole inbound pipeline (C2) |
| api | `agents/src/channels/{slack,telegram,discord}.ts` | webhook (verify+parse→ingest) + `send` adapter (C3/C4/C5) |
| api | `web/src/pages/api/export/all.ts` | `channel_inbox` → conversations branch (C6) |
| component | `web/src/components/in/Inbox.tsx` | tag passthrough + network rail filters (C6) |
| api | `web/src/pages/api/threads/[id].ts` | channel-thread reply → egress (C6) |
| api | `web/src/pages/api/channels/bind.ts` | capability binding + KV cache (C7) |
| lib | `agents/src/channels/dispatch.ts` | KV lookup → agent → egress reply (C7) |

### UX: before → after

| | Today | After |
|---|---|---|
| **Who** | Operator juggling Slack + Telegram + Discord | Same operator |
| **Steps** | Open three apps; context-switch to reply; agent can't help | Open `/in`; reply once; bound agents auto-respond |
| **Friction** | No unified view; senders aren't contacts; no agent participation | One inbox; senders are CRM actors; agents reply and route themselves |
| **Feedback** | Silent — missed messages have no fallback | message → signal → D1 → existing SSE → inbox in <2s |

**The delta:** three tabs become one inbox; channel senders become CRM contacts; agent participation needs no human routing.

---

## Reuse contract

The whole plan is a reuse argument. The substrate already has messaging (`signal`), the inbox already renders it (`conversations` under `dimension:'events'`), SSE already pushes it (`AnalyticsRelay` + `/api/analytics/watch`), and the reply handler already exists (`/api/threads/[id]`). Channels are a thin verify→ingest shell on the way in and a thin post on the way out.

**Deleted vs the prior plan:** `channel-message` entity (it's a signal), `channel-thread` entity (emergent), `channel-authorship` relation (it's `signal.sender`), `/api/events/inbox` (reuse existing SSE), `AllData.channelMessages` + a `mapAllToEntities` branch (reuse the `conversations` shape).

**Transport is a deployment concern, never schema.** Slack/Telegram/Discord are inbound webhooks → stateless Worker routes; C3 pins Slack to the **Events API, not Socket Mode** (we have a public URL). Persistent-connection channels (Matrix, Signal) need a `ChannelConnection` Durable Object holding the sync loop; local bridges (iMessage, Emacs) POST to the same ingress from the user's machine. Both reuse `ingest()` unchanged and are **out of scope for C3–C5** — the DO is the named extension point, not built here.

**Anti-patterns rejected on sight:** a new message/thread/binding entity; a new SSE endpoint; a new contact store; a new inbox component; a `mapAllToEntities` branch when a tag passthrough suffices.

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline
  - [ ] W1 shared recon

Batch 1
  - [ ] C1 — Substrate (channels.tql + D1 + connect)        state: ready
    - [ ] W1 · W2 · W3 · W4

Batch 2  (fires when C1 closes)
  - [ ] C2 — Inbound pipeline (ingest)                       state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4

Batch 3  (fires when C2 closes)
  - [ ] C3 — Slack webhook + send                            state: blocked-on-C2
  - [ ] C4 — Telegram webhook + send                         state: blocked-on-C2
  - [ ] C5 — Discord webhook + send                          state: blocked-on-C2
  - [ ] demo batch (vitest run c3 c4 c5)

Batch 4  (fires when C3+C4+C5 close)
  - [ ] C6 — Inbox render + reply→egress                     state: blocked-on-C3,C4,C5
  - [ ] C7 — Agent binding + dispatch                        state: blocked-on-C3,C4,C5
  - [ ] C8 — Connect flow (OAuth + token)                    state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4
  - [ ] demo batch (vitest run c6 c7 c8)

Plan close
  - [ ] Plan outcome command exits 0
  - [ ] Every deliverables row shipped and reachable
  - [ ] ux_after journey walkable end-to-end
  - [ ] Final compress sweep
  - [ ] Final docs/improvements.md append
  - [ ] Plan rubric ≥ 0.65
```

---

## C1 — Substrate  [tier: simple · batch: 1]

**Goal delta:** the `channel` entity exists in TypeDB, both D1 tables exist, and `connectChannel` can register a channel (entity + D1 row + KV secret) — every downstream cycle has somewhere to write and a way to resolve a workspace.

**Deliverable:** `schema/channels.tql` + `web/migrations/0060_channels.sql` + `agents/src/channels/connect.ts`.

**UX delta:** internal-only. Justified: nothing ingests without a channel to resolve.

**Cycle outcome:** `bun run db:migrate:local` exits 0; `connectChannel(...)` writes a `channels` row, a KV secret, and a `channel` entity (TypeDB write skipped if unavailable).

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c1-substrate.test.ts"
  asserts: "both D1 tables exist with correct columns + unique indexes; connectChannel writes row + KV secret"
  budget: "<2s wall · <80 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `schema/one.tql` — confirm `name`, `status`, `capability` shapes (channel reuses these)
   - [ ] `schema/channels.tql` — confirm final single-entity form
   - [ ] `one.ie/web/migrations/` — highest migration number (new = 0060)
   - [ ] `one.ie/web/src/lib/` — KV binding + D1 write helpers; how secrets are stored elsewhere
2. Primitive-inventory
   - [ ] TypeDB client helper — how a `.tql` file is loaded against the instance

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta confirmed
- [ ] `channels` + `channel_inbox` column sets match channels.md §4 (incl. both unique indexes)
- [ ] KV secret key convention: `channel:{channel_id}:secret`
- [ ] `connectChannel` signature + write order (D1 first, KV, then TypeDB best-effort)
- [ ] Compose-or-construct verdict (all three files are new infra — justified)
- [ ] Diff specs output

### W3 — Edit
**W3a:**
- [ ] `schema/channels.tql` — verify single `channel` entity, valid TypeDB 3.0
- [ ] `one.ie/web/migrations/0060_channels.sql` — both tables + unique indexes
- [ ] `agents/src/channels/connect.ts` — `connectChannel`
- [ ] `tests/e2e/c1-substrate.test.ts`

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun run db:migrate:local` exits 0; both tables present
- [ ] `unique(network, external_account_id)` and `unique(channel_id, message_external_id)` enforced (insert-dup test)
- [ ] `channels.tql` loads alongside `one.tql` (skip if no TypeDB — per CLAUDE.md no-mock rule)
- [ ] Reuse audit: 0 redeclared one.tql attributes (`grep -c "attribute name\|attribute status" schema/channels.tql` = 0)
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C2 — Inbound pipeline  [tier: complex · batch: 2]

**Goal delta:** `ingest(network, payload, env)` turns a verified platform payload into a contact actor + a signal + a deduped `channel_inbox` row and notifies the inbox SSE relay — the single path every channel shares.

**Deliverable:** `agents/src/channels/inbound.ts`.

**UX delta:** internal-only. Justified: C3/C4/C5 are thin shells over this.

**Cycle outcome:** `bun vitest run tests/e2e/c2-inbound.test.ts` — fixture payload → 1 contact actor (find-or-create), 1 signal, 1 D1 row; repeat → deduped (no second row, no second actor); relay notified with `{dim:'events'}`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c2-inbound.test.ts"
  asserts: "ingest writes contact + signal + D1 row, dedups on repeat, notifies relay"
  budget: "<2s wall · <140 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `schema/one.tql` — `signal` payload/ts/sender/receiver; `actor` aid convention
   - [ ] CRM contact resolution — find-or-create actor helper (grep `aid`, lead/contact creation in `api/actors` or `lib/`)
   - [ ] `one.ie/web/src/workers/AnalyticsRelay.ts` + any publish helper — how to notify topic `inbox:{workspace}` server-side
   - [ ] `agents/src/channels/connect.ts` (C1) — channel/workspace resolution shape
   - [ ] `0060_channels.sql` (C1) — exact columns for INSERT OR IGNORE
2. Primitive-inventory
   - [ ] `agents/src/` — existing signal-write helper (reuse, don't hand-roll TypeDB write)
   - [ ] `one.ie/web/src/lib/in/` — `writethrough.ts` D1 write pattern

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta confirmed
- [ ] Canonical normalized shape: `{ threadExternalId, messageExternalId, body, senderExternalId, senderName, ts }`
- [ ] Actor aid convention: `"{network}:{senderExternalId}"`; find-or-create reuses CRM helper (named in recon)
- [ ] Signal write: `signal(sender: contact, receiver: workspace-agent, payload: {network,channelId,threadExternalId,messageExternalId,body}, ts)` — reuse existing signal-write helper
- [ ] Dedup: D1 `INSERT OR IGNORE`; `changes()==0` → early return before actor/signal writes (cheapest dedup point)
- [ ] Relay notify: exact server-side publish call to AnalyticsRelay (from recon)
- [ ] Per-network normalize is a thin map passed IN by C3/C4/C5 — `ingest` takes a normalized record, OR a `normalize` fn; decide the seam so platform code stays in C3/4/5
- [ ] Compose-or-construct verdict (inbound.ts new; everything it calls is reused)
- [ ] Diff specs output

### W3 — Edit
**W3a:**
- [ ] `agents/src/channels/inbound.ts` — `ingest()` orchestrating reused helpers (verify is caller's job)
- [ ] `tests/e2e/c2-inbound.test.ts`

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c2-inbound.test.ts` exits 0
- [ ] First ingest → contact actor + signal + D1 row all written
- [ ] Repeat ingest (same channel_id+message_external_id) → no second row, no duplicate actor, no second signal
- [ ] Relay notified with `{dim:'events'}` for the workspace
- [ ] Reuse audit: inbound.ts imports the CRM actor helper + signal-write helper + relay publish (greps non-empty); does NOT hand-roll a TypeDB write
- [ ] `wc -l agents/src/channels/inbound.ts` ≤ 120
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C3 — Slack webhook + send  [tier: simple · batch: 3]

**Goal delta:** a Slack event webhook (HMAC-verified) flows through `ingest`, and `send()` posts an outbound message to Slack + writes the outbound D1 row.

**Deliverable:** `agents/src/channels/slack.ts` — webhook handler + `send` adapter.

**UX delta:** Slack messages appear in `/in` (after C6); replies reach Slack.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c3-slack.test.ts"
  asserts: "verified webhook → ingest; bad sig → 401; url_verification challenge echoed; send posts + writes outbound row"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `agents/src/channels/inbound.ts` (C2) — `ingest` seam (normalized record vs normalize fn)
   - [ ] `one.ie/web/src/pages/api/webhook/` — existing webhook handler shape (if any)
   - [ ] `agents/src/` — Hono route registration; KV secret read
2. Primitive-inventory
   - [ ] Slack Events API: `url_verification` challenge; `event_callback`→`message`; `X-Slack-Signature` HMAC-SHA256; `team_id` (workspace resolution key)

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta
- [ ] **Transport: Slack Events API (webhook), NOT Socket Mode** — we have a public URL, so a stateless Worker beats a held WebSocket/DO
- [ ] HMAC verify (timestamp + v0 scheme); 200 ack within 3s
- [ ] Slack payload → normalized record (`ts`→messageExternalId, `channel`→threadExternalId, `user`→senderExternalId, `team_id`→external_account_id)
- [ ] `send`: `chat.postMessage` with KV bot token; then write outbound `channel_inbox` row (echo swallowed by unique index)
- [ ] Compose-or-construct verdict
- [ ] Diff specs output

### W3 — Edit
**W3a:**
- [ ] `agents/src/channels/slack.ts` — webhook (verify+parse→ingest) + `send`
- [ ] `tests/e2e/c3-slack.test.ts`

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c3-slack.test.ts` exits 0
- [ ] `url_verification` → `{challenge}` 200; bad sig → 401; valid → `ingest` called once
- [ ] `send()` posts (mocked) + writes outbound row; replayed inbound echo deduped
- [ ] Reuse audit: imports `ingest` from C2; no normalize/dedup re-implementation
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C4 — Telegram webhook + send  [tier: simple · batch: 3]

**Goal delta:** a Telegram update (secret-token-verified) flows through `ingest`; `send()` posts via `sendMessage` + writes outbound row.

**Deliverable:** `agents/src/channels/telegram.ts`.

**UX delta:** Telegram messages in `/in`; replies reach Telegram.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c4-telegram.test.ts"
  asserts: "verified update → ingest; bad token → 401; send posts + writes outbound row"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `agents/src/channels/inbound.ts` (C2) · `agents/src/channels/slack.ts` (C3, pattern)
2. Primitive-inventory
   - [ ] Telegram Bot API: update `{message:{message_id,from,chat,text,date}}`; `X-Telegram-Bot-Api-Secret-Token`; bot id (workspace key)

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta
- [ ] Secret-token header verify
- [ ] payload → normalized (`message_id`→messageExternalId, `chat.id`→threadExternalId, `from.id`→senderExternalId)
- [ ] `send`: `sendMessage` with KV token; write outbound row
- [ ] Diff specs output

### W3 — Edit
**W3a:**
- [ ] `agents/src/channels/telegram.ts`
- [ ] `tests/e2e/c4-telegram.test.ts`

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c4-telegram.test.ts` exits 0
- [ ] bad token → 401; valid → `ingest` once; `send` posts + outbound row; echo deduped
- [ ] Reuse audit: imports `ingest`; no re-implementation
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C5 — Discord webhook + send  [tier: simple · batch: 3]

**Goal delta:** a Discord interaction/event (Ed25519-verified) flows through `ingest`; `send()` posts a message + writes outbound row.

**Deliverable:** `agents/src/channels/discord.ts`.

**UX delta:** Discord messages in `/in`; replies reach Discord.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c5-discord.test.ts"
  asserts: "PING→{type:1}; bad sig→401; verified message→ingest; send posts + writes outbound row"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `agents/src/channels/inbound.ts` (C2) · `agents/src/channels/slack.ts` (C3, pattern)
2. Primitive-inventory
   - [ ] Discord: Ed25519 verify (`X-Signature-Ed25519` + `X-Signature-Timestamp`); PING type 1; `MESSAGE_CREATE`; application id (workspace key)

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta
- [ ] Ed25519 verify (different from HMAC); PING → `{type:1}`
- [ ] payload → normalized (`id`→messageExternalId, `channel_id`→threadExternalId, `author.id`→senderExternalId)
- [ ] `send`: create-message API with KV token; write outbound row
- [ ] Diff specs output

### W3 — Edit
**W3a:**
- [ ] `agents/src/channels/discord.ts`
- [ ] `tests/e2e/c5-discord.test.ts`

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c5-discord.test.ts` exits 0
- [ ] PING → `{type:1}`; bad sig → 401; valid → `ingest` once; `send` posts + outbound row; echo deduped
- [ ] Reuse audit: imports `ingest`; no re-implementation
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C6 — Inbox render + reply→egress  [tier: complex · batch: 4]

**Goal delta:** `/in` and `/u/[slug]/in` show channel threads beside existing conversations, filterable by network, and replying to a channel thread sends back out via the egress adapter.

**Deliverable:** `/api/export/all.ts` channel branch + `Inbox.tsx` tag passthrough + `/api/threads/[id].ts` egress branch.

**UX delta:** operator sees Slack/Telegram/Discord threads in `/in` and replies without leaving the page.

**Cycle outcome:** `bun vitest run tests/e2e/c6-inbox.test.ts` — `/api/export/all` returns channel threads in the `conversations` shape with `tags:['channel','network:slack']`; the existing `convEntities` map renders them; a channel-thread reply triggers `send()`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c6-inbox.test.ts"
  asserts: "export emits channel threads as conversations with network tags; reply routes to egress"
  budget: "<2s wall · <120 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `one.ie/web/src/pages/api/export/all.ts` — conversations query + shape; where to add the channel branch
   - [ ] `one.ie/web/src/components/in/Inbox.tsx` — `convEntities` map (~line 127) hardcodes `tags:['chat','conversation']`; `RAIL_ORDER` (~line 62)
   - [ ] `one.ie/web/src/pages/api/threads/[id].ts` — current reply handler the Inbox POSTs to
   - [ ] `agents/src/channels/{slack,telegram,discord}.ts` (C3/4/5) — `send` signature
2. Primitive-inventory
   - [ ] `one.ie/web/src/data/in-types.ts` — `InboxEntity`/`Dimension` (confirm conversation shape needs no new field)
   - [ ] Existing `hasTag` helper in Inbox.tsx (reused for rail filters)

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta
- [ ] export branch: `SELECT ... FROM channel_inbox WHERE workspace=? ORDER BY created_at DESC` grouped by `thread_external_id` → conversation objects `{ id:'conv:{thread}', messages:[...], lastMessage, ts, tags:['channel','network:{n}'] }`
- [ ] Inbox.tsx change confirmed as **1 line**: `c.tags ?? ['chat','conversation']` in `convEntities`
- [ ] RAIL_ORDER: append one filter row per network (`hasTag('network:slack')` etc.) — optional sidebar
- [ ] threads/[id] branch: if thread is a channel thread (lookup channel_inbox), create outbound signal + call `send(channel,msg)`; else existing behavior unchanged
- [ ] Compose-or-construct verdict (all extends; zero new components)
- [ ] Diff specs output

**Compose-or-construct verdict:**

| Proposed change | Closest primitive | Gap | Verdict |
|---|---|---|---|
| export channel branch | existing conversations query | new table | **extend** — same output shape |
| Inbox tag passthrough | `convEntities` map | hardcoded tags | **extend** — 1 line |
| network rail filters | `RAIL_ORDER` + `hasTag` | no channel rows | **extend** — append rows |
| reply→egress | `api/threads/[id].ts` | no channel branch | **extend** — one branch |

### W3 — Edit
**W3a — independent:**
- [ ] `one.ie/web/src/pages/api/export/all.ts` — channel_inbox→conversations branch
- [ ] `one.ie/web/src/pages/api/threads/[id].ts` — channel-thread → egress branch
- [ ] `tests/e2e/c6-inbox.test.ts`
- [ ] `plans/channels.md` — confirm Phase 4 file paths

**W3b — dependent (after export shape exists):**
- [ ] `one.ie/web/src/components/in/Inbox.tsx` — tag passthrough + RAIL_ORDER filter rows

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c6-inbox.test.ts` exits 0
- [ ] `/api/export/all?slug=demo` includes channel threads in `conversations` with network tags
- [ ] `hasTag('network:slack')` rail filter returns only Slack threads
- [ ] channel-thread reply → `send()` invoked (mocked) + outbound row
- [ ] Reuse audit: NO new component file; Inbox diff is the tag line + RAIL rows; NO `AllData.channelMessages`; NO new SSE endpoint (`grep -r "api/events/inbox" returns 0`)
- [ ] `delta_loc_net` for Inbox.tsx ≤ 15
- [ ] Deliverable shipped · ux_after walkable · plan outcome re-check
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C7 — Agent binding + dispatch  [tier: simple · batch: 4]

**Goal delta:** binding an agent to a channel writes `capability(agent, channel)` + a KV cache; an inbound signal is dispatched to bound agents; an agent reply sends via egress.

**Deliverable:** `web/src/pages/api/channels/bind.ts` + `agents/src/channels/dispatch.ts`.

**UX delta:** operator binds an agent to a channel; the agent replies automatically, visible in the inbox thread with an agent badge.

**Cycle outcome:** `bun vitest run tests/e2e/c7-binding.test.ts` — `bind` writes capability + KV; `dispatch` calls the agent when bound (KV read, not TypeDB), skips when unbound; agent reply calls `send()`.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c7-binding.test.ts"
  asserts: "bind writes capability+KV; dispatch routes to bound agent via KV; agent reply → egress"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `schema/one.tql` — `capability(provider,offered)`; `schema/channels.tql` — `channel plays capability:offered`
   - [ ] `agents/src/` — agent handler/dispatch pattern; how an agent is invoked
   - [ ] `agents/src/channels/inbound.ts` (C2) — where dispatch hooks in (after signal write)
   - [ ] `agents/src/channels/{slack,...}.ts` (C3/4/5) — `send` for the reply
   - [ ] KV binding cache pattern (from C1/C2 recon)
2. Primitive-inventory
   - [ ] `web/src/pages/api/agents/[id].ts` — API shape for the bind endpoint

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta
- [ ] `bind`: write `capability(provider:agent, offered:channel)` to TypeDB + write-through KV `channel:{channel_id}:agents`
- [ ] `dispatch(signal, env)`: read KV bound agents (NOT TypeDB — hot path); invoke each; agent reply = outbound signal + `send`
- [ ] dispatch hook point in `ingest` (after signal write, fire-and-forget)
- [ ] Compose-or-construct verdict (both new; reuse capability + send + agent handler)
- [ ] Diff specs output

### W3 — Edit
**W3a:**
- [ ] `web/src/pages/api/channels/bind.ts`
- [ ] `agents/src/channels/dispatch.ts`
- [ ] `tests/e2e/c7-binding.test.ts`

**W3b:** *(empty)*

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c7-binding.test.ts` exits 0
- [ ] `bind` → capability written + KV populated; `DELETE` removes both
- [ ] `dispatch` with binding → agent invoked once (via KV read); without → not invoked
- [ ] agent reply → `send()` called + outbound row
- [ ] Reuse audit: dispatch reads KV not TypeDB; reuses `send` from C3/4/5; no new agent runtime
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C8 — Connect flow  [tier: simple · batch: 4]

**Goal delta:** a client connects Slack/Discord via OAuth and Telegram via a pasted token from `settings/integrations`, each ending in `connectChannel` — the channel goes live without a developer.

**Deliverable:** `web/src/pages/api/integrations/oauth/[network].ts` (start + callback) + a Messaging group on `web/src/pages/settings/integrations.astro`.

**UX delta:** operator clicks "Connect Slack" (or pastes a Telegram token) and the channel is live — three clicks for OAuth, one paste for Telegram.

**Cycle outcome:** `bun vitest run tests/e2e/c8-connect.test.ts` — OAuth callback with a mock code calls `connectChannel` (writes `channels` row + KV secret); Telegram token submit does the same via `getMe`+`setWebhook` (mocked).

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/c8-connect.test.ts"
  asserts: "OAuth callback and Telegram token submit both write a channels row + KV secret via connectChannel"
  budget: "<2s wall · <100 LOC test"
```

### W1 — Recon
1. Existing-code
   - [ ] `one.ie/web/src/pages/settings/integrations.astro` — current groups + how rows link to connect; where to add Messaging group
   - [ ] `one.ie/web/src/components/in/IntegrationsList.tsx` — `handleConnect` → `/api/integrations/oauth/{id}` convention to reuse
   - [ ] `one.ie/web/src/pages/api/integrations/oauth/` — existing OAuth start/callback handlers (pattern + state/cookie handling)
   - [ ] `agents/src/channels/connect.ts` (C1) — `connectChannel` signature
2. Primitive-inventory
   - [ ] `one.ie/web/src/components/settings/SettingsLayout.astro` — page chrome to reuse
   - [ ] OAuth secrets: where client_id/client_secret for Slack/Discord live (env vars)

### W2 — Decide
- [ ] Goal-delta · deliverable · UX-delta
- [ ] **Reuse, don't reinvent:** Messaging rows reuse the `IntegrationsList` Connect/Disconnect pattern + `/api/integrations/oauth/{network}` convention; do NOT touch `ChannelCreateForm` (CRM-segment, different concept)
- [ ] OAuth (Slack, Discord): start sets `state=workspace`; callback exchanges code → `{ externalAccountId, token }` → `connectChannel`
- [ ] Telegram: token form → `getMe` (bot id) + `setWebhook(url, secret)` → `connectChannel`; secret stored in KV
- [ ] Operator precondition documented: one Slack app + one Discord app with Events/Interactions URL set once (not per-client)
- [ ] Compose-or-construct verdict (oauth route new; UI extends existing page)
- [ ] Diff specs output

**Compose-or-construct verdict:**

| Proposed change | Closest primitive | Gap | Verdict |
|---|---|---|---|
| Messaging group | `settings/integrations.astro` groups | no messaging group | **extend** — add rows |
| connect rows UI | `IntegrationsList.tsx` | already does Connect/Disconnect | **compose** — reuse as-is |
| `oauth/[network].ts` | existing `/api/integrations/oauth/` handlers | no slack/discord channel callback | **extend** — add network branch → connectChannel |

### W3 — Edit
**W3a — independent:**
- [ ] `one.ie/web/src/pages/api/integrations/oauth/[network].ts` — start + callback for slack/discord + telegram token submit → `connectChannel`
- [ ] `tests/e2e/c8-connect.test.ts`

**W3b — dependent (after route exists):**
- [ ] `one.ie/web/src/pages/settings/integrations.astro` — Messaging group wired to the routes

### W4 — Verify
- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `bun vitest run tests/e2e/c8-connect.test.ts` exits 0
- [ ] OAuth callback (mock code) → `connectChannel` called → `channels` row + KV secret written
- [ ] Telegram token submit (mock `getMe`/`setWebhook`) → `connectChannel` called
- [ ] Reuse audit: reuses `IntegrationsList` pattern + `/api/integrations/oauth` convention; `ChannelCreateForm` untouched (`grep` confirms no import)
- [ ] Deliverable shipped · ux_after walkable (connect → channel live) · plan outcome re-check
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## See also

- `plans/channels.md` — architecture; § 2 (message = signal) is the load-bearing decision
- `schema/channels.tql` — the single `channel` entity
- `schema/one.tql` — `signal`, `actor`, `capability` reused throughout
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands
