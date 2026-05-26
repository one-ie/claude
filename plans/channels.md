# Channel Integration — Unified Inbox

**Purpose:** Connect Slack, Telegram, and Discord to the ONE substrate as thin ingress/egress shells. Messages flow through the existing `signal` dimension and render in the existing `/in` inbox. Agents bind to channels and participate.

**Status:** draft

---

## 1. Goal

A message sent in Slack, Telegram, or Discord becomes a `signal` in the substrate within 2 seconds, appears in `/in` next to existing conversations, and any agent bound to that channel can read and reply — replies go back out to the platform.

---

## 2. The insight — a message is a signal

The substrate already models messaging. We don't add a message type; we reuse what dimension 5 already is.

| Concept | Substrate primitive | New code |
|---|---|---|
| inbound message | `signal(sender: external-actor, receiver: agent)` | none |
| outbound message | `signal(sender: agent, receiver: external-actor)` | none |
| message author | `signal.sender` (an `actor`) | none |
| human vs agent | `sender.actor-type` | none |
| thread | emergent — group by `threadExternalId` | none (D1 grouping) |
| handoff agent→human | `signal(sender: agent, receiver: human)` | none |
| channel contact | `actor` (actor-type `human`) — same as a CRM lead | none |
| agent ↔ channel binding | `capability(provider: actor, offered: channel)` | none |
| **channel** | **new `channel` entity** (the one anchor) | `channels.tql` |

A Slack message's payload rides in `signal.payload` as `{ network, channelId, threadExternalId, messageExternalId, body }`. `signal.ts` is the timestamp. `signal.sender` is the contact. That's the whole message.

**Why this is correct, not just small:** the ONE rule is "the meta-layer obeys the rule the schema already obeys." The schema says events are signals. A message is an event. A second message entity would be a parallel events model — the exact anti-pattern.

**Bonus:** a channel contact *is* a CRM actor. Everyone who messages you on any channel lands in the people pipeline automatically — no separate contact store.

---

## 3. Schema — channels.tql

One entity. Two new attributes. Zero new relations.

```
channel   owns channel-id @key, name, channel-network, status
          plays capability:offered      ← agent binds via capability(actor, channel)
```

Reused from `one.tql`: `name`, `status`, `signal` (all messages), `actor` (all senders), `capability` (all bindings). Nothing else is added to TypeDB.

---

## 4. D1 tables — the hot path

TypeDB is truth. D1 serves the two latency-sensitive reads: workspace resolution on every inbound webhook, and the inbox feed.

```sql
-- workspace resolution: (network, external_account_id) → workspace + channel
channels (
  channel_id          text primary key,
  workspace           text not null,
  network             text not null,        -- slack | telegram | discord
  external_account_id text not null,        -- slack team_id | telegram bot id | discord app id
  status              text not null,        -- active | paused | error
  created_at          integer not null,
  unique (network, external_account_id)
)

-- inbox feed + dedup
channel_inbox (
  id                  text primary key,
  workspace           text not null,
  channel_id          text not null,
  network             text not null,
  thread_external_id  text not null,        -- groups messages into a conversation
  message_external_id text not null,        -- platform's own id
  sender_id           text not null,        -- actor aid (resolved contact)
  sender_name         text,
  body                text,
  direction           text not null,        -- inbound | outbound
  status              text not null default 'unread',  -- unread | read | archived
  created_at          integer not null,
  unique (channel_id, message_external_id)  -- dedup + echo-loop break
)
```

Credentials (bot tokens, signing secrets) live in KV under `channel:{channel_id}:secret` — never in D1 or TypeDB.

---

## 5. Architecture

```
                 ┌─────────────── ingress ───────────────┐
Slack/Tg/Discord │ verify sig → parse → resolve workspace │
  webhook  ─────▶│ → normalize → dedup → resolve actor    │──▶ signal (TypeDB)
                 │ → write D1 row → notify relay (dim:events)│──▶ channel_inbox (D1)
                 └────────────────────────────────────────┘         │
                                                              SSE (existing) ──▶ /in
  /in reply  ────────────────────────────────────────┐
  agent reply ───────────────────────────────────────┤
                 ┌─────────────── egress ─────────────▼──┐
                 │ outbound signal → send(channel, msg)   │──▶ platform API
                 └────────────────────────────────────────┘
```

### Transport classes — the only thing that varies

`ingest()` takes a normalized record; it never knows how the message arrived. So transport is a deployment concern, never schema. Three classes, one convergence point:

| Class | Mechanism | Runs as | Channels |
|---|---|---|---|
| A · webhook | platform POSTs a URL | stateless Worker route | Discord, Telegram, Slack, GitHub, Linear, Google Chat, Email, WhatsApp Cloud, Teams, Webex, WeChat |
| B · persistent | hold a socket / sync loop | `ChannelConnection` Durable Object | Matrix, Signal (cli) |
| C · local bridge | runs on the user's machine | local agent → POSTs ingress | iMessage, Emacs |

Slack, Telegram, and Discord are all Class A for us — we have a public URL, so Slack uses the **Events API webhook, not Socket Mode** (no held connection, no DO). Classes B and C are the same `ingest()` behind a different doorway; the DO and local-agent shells are extension points, unbuilt until Matrix/Signal/iMessage land.

### Ingress pipeline (`agents/src/channels/inbound.ts`)

One shared function `ingest(network, rawPayload, env)`:

1. **Verify** — platform signature (Slack HMAC / Telegram secret token / Discord Ed25519). Bad sig → 401.
2. **Resolve workspace** — look up `channels` D1 by `(network, external_account_id)` → workspace + channel_id. Unknown → 404.
3. **Normalize** — map the platform payload to canonical `{ threadExternalId, messageExternalId, body, senderExternalId, senderName, ts }`.
4. **Dedup** — `INSERT OR IGNORE` on `channel_inbox`; zero rows affected → stop (already seen / our own echo).
5. **Resolve actor** — find-or-create `actor(aid: "{network}:{senderExternalId}", actor-type: "human")`. This is the CRM contact.
6. **Write signal** — `signal(sender: contact, receiver: workspace-agent)` with channel payload + ts.
7. **Notify** — publish `{dim:'events'}` to the existing AnalyticsRelay topic `inbox:{workspace}`. The Inbox refetches conversations; the message appears.

### Egress (`send` adapter per network)

Each platform cycle exports `send(channel, message, env)`. A generic dispatcher routes an outbound `signal` to the right adapter by `channel.network`. Used by both human replies (from `/in`) and agent replies. The adapter posts to the platform API using the KV-stored token, then writes the outbound `channel_inbox` row (direction `outbound`) — whose `message_external_id` the dedup index uses to swallow the inevitable echo webhook.

### Provisioning — how a client connects (`connectChannel`)

`connectChannel(workspace, network, externalAccountId, secret, env)` writes the `channel` entity (TypeDB), the `channels` D1 row, and the KV secret. Without it, inbound 404s — provisioning is the precondition. Two connect patterns, both ending in `connectChannel`, both surfaced on the **existing** `settings/integrations` page (a new "Messaging" group reusing the `IntegrationsList` Connect/Disconnect row + the `/api/integrations/oauth/{id}` convention already wired there):

- **OAuth install (Slack, Discord)** — "Connect" → `/api/integrations/oauth/{network}` → platform consent → `…/callback` exchanges the code for `{ externalAccountId, token }` → `connectChannel`. The Events/Interactions URL is set **once** on your platform app (operator config); clients just install, and inbound resolves by `team_id`/`app_id`. Many installs, one URL.
- **Token paste (Telegram)** — "Connect" → paste the @BotFather token → `getMe()` for the bot id → `setWebhook(url, secret)` → `connectChannel`. No OAuth.

Note: the existing `ChannelCreateForm` / `lib/in/channels.ts` mean *CRM segment*, not a messaging integration — messaging channels live in the integrations surface, never that form.

---

## 6. pages/in — render with what already exists

The Inbox already renders `conversations` under `dimension: 'events'`, already has SSE via `/api/analytics/watch`, already has a reply handler. Channels reuse all of it.

- **`/api/export/all`** gains one branch: query `channel_inbox` grouped by `thread_external_id` and emit each thread in the **existing `conversations` shape** (`{ id, messages[], lastMessage, ts }`) plus `tags: ['channel', 'network:{n}']`.
- **`Inbox.tsx`** changes by **one line** — `convEntities` reads `c.tags ?? ['chat','conversation']` so channel threads carry their network tag through. Optional: append `RAIL_ORDER` filter rows per network (`hasTag('network:slack')`) for a channel sidebar.
- **SSE** — none added. Ingress notifies the existing relay; the existing `dim:'events'` refetch path picks it up.
- **Reply** — `handleReply` already posts channel-thread replies to `/api/threads/{id}`. That handler gains a branch: if the thread is a channel thread, create the outbound signal and call `send(channel, msg)`.

`/u/[slug]/in` is identical — same `<Inbox>`, same `/api/export/all?slug=` prefetch.

---

## 7. Collaboration

Humans and agents are both `actor`; both author messages as `signal.sender`. A thread with a human and an agent is just signals into the same `threadExternalId`. The `/in` view shows them together with an actor-type badge.

**Handoff** — an agent escalates with `signal(sender: agent, receiver: human, payload: { type:'handoff', threadExternalId, reason })`. The human opens the thread, full history present, replies. No new mechanism.

**Participants of a thread** = senders of its signals (or, on the hot path, distinct `sender_id` in `channel_inbox` for that `thread_external_id`). No membership relation until that query is proven hot.

---

## 8. Agent binding

`capability(provider: agent-actor, offered: channel)` is the binding (TypeDB = truth). On bind, write-through a KV cache `channel:{channel_id}:agents`. Dispatch reads KV (never TypeDB on the hot path): after `ingest` writes an inbound signal, `dispatch` checks the channel's bound agents and invokes each. An agent reply is an outbound signal sent via the egress adapter and rendered in the inbox thread with an agent badge.

---

## 9. Phases

### Phase 1 — Substrate
`channels.tql` (1 entity) + `0060_channels.sql` (both D1 tables) + `connectChannel` + KV secret convention.
Gate: migration runs; `channels.tql` loads against real TypeDB (skip if unavailable); `connectChannel` writes entity + D1 row + KV secret.

### Phase 2 — Ingress pipeline
`inbound.ts` — verify-agnostic `ingest()` covering normalize → dedup → resolve-actor → write signal → write D1 → notify relay.
Gate: `ingest('slack', fixture, env)` creates a `channel_inbox` row, a contact actor, and a signal; second call dedups; relay notified.

### Phase 3 — Per-network adapters (Slack, Telegram, Discord)
Each: webhook handler (verify + parse → `ingest`) + `send` adapter (egress).
Gate: per-network webhook fixture → D1 row; `send()` posts (mocked) and writes outbound row; signature failures 401.

### Phase 4 — Inbox + agents
Inbox: `/api/export/all` channel-thread branch + 1-line tag passthrough + reply→egress. Agents: `bind` (capability + KV) + `dispatch` (KV lookup → agent → egress).
Gate: `/api/export/all` returns channel threads as conversations; bound agent receives a dispatched message and its reply sends.

---

## 10. Key decisions

**A message is a signal.** No message entity. Dimension 5 already is messaging; a parallel model would violate the substrate's own rule. The existing inbox, SSE, and reply handler already speak signals — channels inherit all of it.

**Threads are emergent.** Grouped by `thread_external_id` in D1. Thread-level state (read/archived/snooze) is mutable D1, not TypeDB. Add a thread entity only if a graph query for threads is ever proven hot.

**Channel is the single TypeDB anchor.** It exists so `capability(agent, channel)` can bind. One entity, two attributes. Bindings cache to KV for the hot dispatch path.

**Channel contacts are CRM actors.** Find-or-create `actor("{network}:{id}")` unifies channels with the people pipeline — no separate contact store, and every channel sender is reachable by existing CRM tooling.

**D1 carries the hot path, KV carries secrets, TypeDB carries truth.** Workspace resolution and the inbox feed are D1. Tokens are KV. The permanent event record and bindings are TypeDB. Same split the rest of the platform already uses.

**Transport is a doorway, not truth.** Webhook, persistent-socket, and local-bridge channels all converge on the same `ingest()` and the same `signal`; the only per-channel variation is a thin adapter. Slack uses the Events API webhook (we have a public URL), so it stays a stateless Worker like Telegram and Discord. Class-B channels (Matrix, Signal) get a `ChannelConnection` DO holding the sync loop when added — the schema never changes for any of it.

**Three channels first.** Slack, Telegram, Discord — simple bot APIs, reliable webhooks. Cross-channel sync (mirroring Slack↔Telegram) is explicitly out of scope until ingress + egress are proven; the signal model already supports it (a forwarded outbound signal) when we get there.

**No spectrum-ts, no nanoclaw runtime dependency.** Direct handlers in `agents/`. The per-network code is a thin verify+parse on ingress and a thin post on egress — nothing a paid intermediary would shrink.
