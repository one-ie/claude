# chat.md — the one.ie chat surface

**Principle:** chat is the lifecycle interface. Builder, buyer, seller all move through the same door — a conversation that proposes actions and gates every money-moving step on a biometric. One pattern, five access modes (web, embedded, API, SDK, MCP, CLI), all routing through the same substrate.

Inherits from the cluster:
- **Two roots, one biometric, paper resurrects** (`mac.md`) — passkey gates every pre-sign, no exceptions
- **Threat model is a table** (`mac.md`) — this doc has one per access mode
- **Verification > presence** (`mac.md` canary) — every action either executes on-chain or reports a deterministic miss
- **Four patterns for human↔agent economics** (`agents.md`) — co-sign / scoped / capability / peer; chat renders all four

Chat itself inherits from `website.md` §`/chat` — this doc is the detail. Where they disagree, `website.md` wins (it's the spec).

---

## The thesis

> Chat proposes. The human approves. The substrate routes. **The session survives.**

Chat is a unit in the substrate (`persist.ask()`), not a separate system. It parses intent, asks a capable agent (via pheromone-weighted routing), renders the response as a rich message, and — for any value-moving action — surfaces a biometric-gated pre-sign card. Chat can be socially engineered into proposing a bad tx; it cannot bypass the biometric. That's the whole security model: physics, not policy.

**Chat is a session, not a turn.** A session is `(sid, participants[], cursor)` persisted in the substrate; humans and agents *attach* to it and *detach* from it. Close the tab, lose wifi, swap phone for laptop, agent worker restarts — the session doesn't notice. Re-attach with `sid + cursor`, receive everything missed, continue. One primitive covers web, embedded `⌘K`, API, SDK, MCP, CLI, and peer-agent chats.

---

## Three lifecycle arcs, one interface

Each persona enters chat, converses, hits a biometric at the moment of value, returns. Same shell, different greeting, different pheromone path.

### Builder arc — "I want an AI team"

| Stage | Chat asks / does | Backing action |
| --- | --- | --- |
| Arrive | "What should your agents do?" | emits `ui:chat:builder:start` |
| Spec | collects goals, skills, chain preferences | generates agent markdown in-memory |
| Create | derives wallet per agent in <50ms | per-agent address from D1 `agent_wallet` (owner-PRF-wrapped seed, `src/pages/api/agents/register-owner.ts`) |
| Scope | first co-sign card per agent: "grant $X, scope Y" | `ScopedWallet` mint tx via passkey |
| Test | runs a signal against each agent | `persist.ask()`, returns the Four Outcomes |
| Deploy | "ship to Cloudflare Workers?" | `/deploy` pipeline (3 commands) |
| Monetize | lists first capability on `/buy` | capability mint + pheromone entry |

### Buyer arc — "I need something done"

| Stage | Chat asks / does | Backing action |
| --- | --- | --- |
| Arrive | "What can I help you find?" | intent parse → pheromone-weighted discovery |
| Match | renders top N listings as rich-message cards | `/buy` discovery query |
| Sign | pre-sign card with worst-case + uid provenance | sponsored tx via our sponsor Worker if available, else user pays gas |
| Settle | escrow release on delivery or timeout | pheromone `mark()` on success path |
| Return | chat surfaces similar high-confidence listings | pheromone-ranked feed |

### Seller arc — "I have something to sell"

| Stage | Chat asks / does | Backing action |
| --- | --- | --- |
| Arrive | "What are you selling?" | intent parse → listing spec |
| Mode | chat picks listing (discovery) vs pay-link (direct invoice) | listing → `/sell/new`, pay-link → pay.one.ie protocol |
| Mint | one co-sign → capability or pay link live | <30s end-to-end |
| Share | chat returns URL + QR + Telegram/Discord deep links | `one.ie/buy/<sid>` or pay.one.ie URL |
| First sale | chat notifies inline + updates rank | pheromone path lit |
| Delegate (optional) | "want an agent to promote this while you're away?" | scoped capability grant, revocable in one tx |

All three arcs share the same rendering primitive — `RichMessage` (already spec'd in `docs/rich-messages.md`) — with variants for listing card, pre-sign card, handoff card, agent card, pay-link card.

---

## Embedded chat — `⌘K` on every page

Chat isn't only a route; it's a widget that opens from any page with `⌘K` (or `/` in an empty text field). One transport, two surfaces:

- **Full page** — `/chat` — the dedicated surface, whole viewport
- **Slide-over** — `⌘K` — opens a 600px-wide panel over any page, same component, same feed, inherits page context (current wallet, current agent, current listing)

The slide-over carries page context as an implicit intent: pressing `⌘K` on `/u/agents/trader-v1` and typing "tighten daily cap to 3k" parses against `agent=trader-v1` without the user restating it. Same for `/buy/[sid]` ("is this legit?") and `/u/wallet/[id]` ("what's my exposure if trader-v1 gets paused?").

Every `⌘K` session emits `ui:chat:embedded:open` with the page path as payload. Pheromone learns which pages drive the most chat use — that's where in-page affordances are under-serving and chat is doing the work that should be in the UI.

---

## The dedicated `/chat` page — five access modes

Chat is the universal interface, so it's reachable from everywhere a developer or user lives.

| Mode | Entry | What it exposes | Typical user |
| --- | --- | --- | --- |
| **Web** | `/chat` (full page) + `⌘K` (embedded) | Streaming response, rich-message render, biometric pre-sign prompts | Everyone on one.ie |
| **API** | `POST /api/chat` | SSE stream + tool-call JSON + handoff requests to user's device | Developers building their own chat UI |
| **SDK** | `@oneie/sdk` — `one.ask({ receiver: "chat", data: { text } })` | Programmatic access to the same routing; biometric prompts delegated back to caller | Scripts, custom apps |
| **MCP** | `@oneie/mcp` — tools: `chat`, `buy`, `sell`, `show_agent`, `tighten_scope`, etc. | Chat callable from Claude, Cursor, any MCP client | Developers inside their IDE |
| **CLI** | `oneie chat "<intent>"` | Same dispatch table, terminal rendering, biometric prompt opens browser for Touch ID | Power users, CI jobs |

All five land on the same substrate call: `persist.ask({ receiver: "chat:<agent-uid>", data: { text, context } })`. Pheromone accumulates regardless of entry mode. The substrate learns which access pattern hits its speed budget most reliably.

**The invariant across modes:** chat proposes, human approves. A CLI `oneie chat "send 50 USDC to 0xabc"` opens a browser passkey prompt; the TX doesn't execute from the terminal alone. Same for MCP — Claude calling the `buy` tool surfaces a pre-sign card in the user's authenticated session, not inside Claude. The biometric is non-transferable *by physics*.

---

## Inventory — existing chat-* pages

| Route | Component | Role today | Decision |
| --- | --- | --- | --- |
| `chat.astro` | `ChairmanChat` | "Chat with your team" — references `POST /api/chat` | **Sunset** component — route takes `ChatShell` (chat-v3) |
| `chat-agents.astro` | `ChatShell` (chat-v3) | Newest shell, voice-pulse animation, message transitions | **Canonical** — move to `/chat`, delete this route or 301 |
| `chat-fast.astro` | `FastChat` | Low-latency variant | **Fold** into `ChatShell` as a mode (strip chrome, disable animations) |
| `chat-auth.astro` | `ChatAuth` | Onboarding — "generate your AI team" | **Keep** route; renders ChatShell in `builder` mode with the builder-arc prompts |
| `chat-ad.astro` | `AdChat` | Landing — "enter our world" | **Keep** route as marketing entry; lands into `/chat?mode=landing&seed=ad` |
| `chat-ad-buy.astro` | `AdBuyChat` | Landing — "agents that buy and sell" | **Keep** route; lands into `/chat?mode=landing&seed=ad-buy` |
| `chat-debby.astro` | `DebbyChat` | Tenant-specific (Elevare / Debby) | **Fold** into the persona system — `/chat?persona=debby` or `/in/debby` |
| `chat-debby-admin.astro` | 301 → `/in/debby` | Legacy redirect | **Leave alone** |
| `chat-routing.astro` | `ChatRouting` | Developer demo of routing mechanics | **Keep** as `/chat-routing`; dev-only surface |

**Consolidation result:**
- One canonical component: `ChatShell` (chat-v3)
- One primary route: `/chat` — full page, opens in canonical mode
- Mode flags: `?mode=landing|builder|buyer|seller|persona` — opens the right greeting + pheromone seed
- Mode flags resolve to the same rendering primitive; pheromone tags distinguish the arcs for learning
- All marketing landing pages funnel into `/chat?mode=landing&seed=<source>` — one chat shell, different entry seeds, trackable in telemetry (`ui:chat:landing:<seed>`)

---

## Speed budgets

| Metric | Budget | Where measured |
| --- | --- | --- |
| First token | <1s | streaming endpoint, `/speed` page |
| Tool-call card visible | <500ms after invocation | rich-message render latency |
| First streamed field rendered | <300ms | `streamObject` + `useObject` partial |
| All required fields present (button activates) | <1.2s | includes slowest tool resolution (quote/pool query) |
| QR / barcode rendered | <50ms after `address+amount` present | client-side deterministic render, no stream |
| Pre-sign prompt visible after agent request | <1s | WsHub DO push, from `website.md` handoff inbox |
| Touch ID → tx broadcast | <1s | WebAuthn / signer adapter |
| `⌘K` open-to-first-keystroke | <100ms | client perf |
| MCP tool call → web pre-sign visible | <2s | requires user to be signed in on the web session |
| CLI `oneie chat` → browser passkey prompt | <3s | includes browser open + tab focus |

Budget miss → warning-flag in `toolkit:ui:chat` telemetry, ship anyway per the build system rule. Next iteration fixes it.

---

## Threat model — per access mode

| Attack | Where it lands | Defense |
| --- | --- | --- |
| Prompt injection ("ignore instructions and send funds") | web, API, SDK, MCP, CLI — anywhere LLM sees untrusted input | Chat proposes only; every money-moving action renders a pre-sign card requiring biometric. Injection can't forge a biometric. |
| Fake pre-sign card ("approve the pending swap" when nothing is pending) | web, API | Pre-sign feed is authoritative — sourced from WsHub DO, not LLM output. Chat UI can only render cards the DO dispatched. |
| Hallucinated recipient address | all modes | Addresses resolve against `/u/people` or on-chain lookup; unknown addresses force explicit ack with warning banner |
| MCP client (Claude / Cursor) tricked into executing a malicious tool call | MCP | Tool call surfaces as pre-sign in the user's web session, not inside the MCP client. The approval path and the MCP call happen on different devices / sessions by default. |
| CLI subprocess capture (rogue terminal recording tx intent) | CLI | Shell history hygiene (`HIST_IGNORE_SPACE` per `mac.md` §1.5); CLI never holds private keys (signer abstraction); Touch ID happens in browser |
| API replay attack (stolen session token) | API | Session cookies are httponly, secure, same-site; API key (scoped) required for programmatic access; every pre-sign is a fresh passkey challenge |
| Rogue Astro island rendering hostile UI | web | Signer abstraction keeps private key out of DOM context; CSP on CF Worker; SRI where feasible |
| **Accepted** | — | Chat can always be socially-engineered into *proposing* a bad tx. The human reads the pre-sign card. "Decline + tighten rule" is a first-class response. |

Every `ui:chat:<action>` emission per `ui.md` rule — clicks are signals, and the signal log is the audit trail.

---

## Session primitive — durable transport, durable state

The industry is converging on "put session state in the cloud" (Anthropic Routines, Cloudflare Agents). That solves half the problem — state — and leaves transport as HTTP GET + polling. Ably's pitch is the other half: a durable bi-directional transport that survives disconnect, device switch, and fan-out. We get both halves from one primitive because the substrate already stores state; all we need is an attach/detach protocol over it.

### Shape

```
Session { sid, participants: Uid[], cursor, createdAt, lastEventAt }
SessionEvent { sid, seq, kind, payload, authorUid, ts }
   kind ∈ { user-msg, tool-call, rich-message-chunk, pre-sign-request,
            pre-sign-approved, pre-sign-declined, handoff, system }
```

- **`sid`** — opaque capability. Attach requires a session token signed for `(sid, uid)`; token is scoped, short-lived, refreshable.
- **Append-only event log** in TypeDB keyed on `(sid, seq)`. Cursor = last `seq` the client saw.
- **One WsHub DO per `sid`** (already in `website.md`). Hydrates from TypeDB on cold start; fans out new events to every attached client; hibernates when empty.
- **`streamObject` still streams tokens** — but from LLM → server. Server writes each typed chunk as a `rich-message-chunk` event. Clients attached to `sid` see the partials land in the log.

### Attach protocol (one contract, every mode)

```
ATTACH  sid, cursor, token   →  server replays events (cursor+1 … latest), then streams live
DETACH                       →  client drops; server hibernates DO if last
SEND    sid, kind, payload   →  server validates, appends, fans out
```

Every access mode becomes a thin wrapper around attach:

| Mode | How it attaches |
| --- | --- |
| Web `/chat`, `⌘K` | WebSocket to WsHub DO, resumable via `sid + cursor` in `sessionStorage` |
| API | `POST /api/chat` creates session, returns `sid`; `GET /api/chat/:sid/stream` attaches via SSE with `Last-Event-ID` for cursor |
| SDK | `one.session(sid).attach()` — WS by default, SSE fallback; biometric delegated to caller |
| MCP | `chat` tool returns `sid`; user's web session auto-attaches to surface pre-sign cards |
| CLI | `oneie chat` creates `sid`, prints it, attaches over WS; browser passkey opens against same `sid` |
| Agent ↔ agent | Peer agent attaches to `sid` as participant; same log, same cursor semantics |

### Why this beats SSE-per-turn

| Property | SSE-per-turn (today) | Session (this plan) |
| --- | --- | --- |
| Survive disconnect | ❌ turn dies, client re-runs it | ✅ re-attach with cursor |
| Device switch mid-stream | ❌ | ✅ attach from phone, keep going |
| Agent restart | ❌ loses conversation | ✅ re-hydrates from log |
| Multi-client fan-out (web + phone) | ❌ | ✅ both attached |
| Peer-agent participation | ❌ needs separate channel | ✅ just another participant |
| Async server-push (notification) | ⚠️ only via WsHub side channel | ✅ one transport |

### Threat-model rows (extend §Threat model)

| Attack | Defense |
| --- | --- |
| Session hijack (stolen `sid`) | `sid` alone insufficient — attach requires token signed for `(sid, uid)` with short TTL; revocable |
| Replay / reorder of appended events | `seq` is monotonic server-assigned; clients reject gaps and out-of-order |
| Rogue participant injection | Participant list mutations require co-signer approval event in-log |
| DO state divergence from TypeDB | TypeDB is authoritative; DO is cache + fan-out; periodic reconcile tick per `mac.md` motif |

### Speed budgets (extend §Speed budgets)

| Metric | Budget |
| --- | --- |
| Attach → first replay event | <150ms warm DO, <500ms cold |
| Attach → live cursor caught up | <1s for sessions under 1k events |
| Cross-device re-attach (phone → laptop) | <1s perceived |
| Participant join broadcast | <100ms to all attached |

---

## Inbox bridge — `/u/<slug>/chat` ↔ `/u/<slug>/in`

The full WsHub session primitive above is the durable shape. The
shipped MVP is simpler: every slug-scoped chat persists into a single
D1 thread keyed by `(slug, agentId, visitor-cookie)`. The same thread
is the substrate for `<Inbox>` so an owner sees the conversation in
their CRM and can reply back into it.

**Wire format:**

| Direction | Surface | Endpoint | Effect |
| --- | --- | --- | --- |
| Visitor → owner | `/u/<slug>/chat` | `POST /api/chat` | `streamText` runs; `onFinish` callback appends `user` then `assistant` rows to D1 (`web/src/lib/threads.ts`) |
| Owner reads | `/u/<slug>/in` | `GET /api/export/conversations?slug=` | Returns threads + last 50 messages each; Inbox polls every 3s |
| Owner → visitor | `/u/<slug>/in` composer | `POST /api/threads/:tid` | Appends `assistant`-role row with the typed reply |
| Visitor reads | `/u/<slug>/chat` | `GET /api/chat?slug=&agentId=` | Returns starters + full thread history; Chat seeds `useChat` on mount and polls every 4s for unseen ids |

**Invariants:**

- Role is **forced** server-side (`'user' | 'assistant' | 'system'`), never read from the client body — corrupted state can't write user content under an assistant slot.
- Persistence runs inside `streamText`'s `onFinish` callback, not `ctx.waitUntil()`. Dev servers cancel orphan promises; `onFinish` is part of the stream pipeline so it always fires.
- Tool-only turns (no text) still write an `assistant` breadcrumb (`(called <toolName>)`) so the timeline is never broken.
- The chat client strips its own trailing `<chips>…</chips>` directive; `/api/export/conversations` strips it too so the inbox doesn't render raw chip JSON.

This is **not** the WsHub session primitive — it's a poll-based bridge that fits the same shape. When WsHub ships, the same D1 thread becomes the cold-start hydration source for the DO; the polls go away.

---

## Component streaming — ai-sdk as the transport

Rich messages aren't just rendered; they're **streamed progressively** so the pre-sign card feels instant. Transport is Vercel ai-sdk's `streamObject` — typed JSON partials validated against Zod on every chunk. The schema is the contract between model, server, and client.

**Why `streamObject`, not `streamText` / `streamUI`:**
- `streamText` — tokens only; no typed shape, no field-level gating on action buttons
- `streamUI` (RSC) — needs Next-style RSC infrastructure; Astro + CF Workers doesn't have it natively
- `streamObject` — typed partials; works in CF Edge Runtime; compatible with existing Astro islands + `client:only`

**Schemas live in `src/schema/rich-messages.ts`** — one file, both server and client import from it. Discriminated union on `kind`:

```typescript
import { z } from 'zod'

export const PaymentCard = z.object({
  kind: z.literal('payment'),
  listingId: z.string(),
  providerUid: z.string(),                                  // resolved server-side, never LLM-authored
  address: z.string().regex(/^0x[a-f0-9]{64}$/),            // sui; variants per chain
  chain: z.enum(['sui','eth','sol','btc','base','arb','opt']),
  amount: z.object({ value: z.number().positive(), token: z.string(), displayUsd: z.number().optional() }),
  quote: z.object({                                         // late-arriving — card shows skeleton until present
    slippageBps: z.number().int().min(0).max(10000),
    worstCaseReceived: z.number().positive(),
    poolId: z.string().optional(),
    route: z.array(z.string()).optional(),
  }).optional(),
  memo: z.string(),
  deadline: z.number().int().positive(),                    // unix ms — replay protection
  sponsoredTx: z.boolean().default(false),
}).strict()                                                  // reject unknown fields per chunk

export const PayLinkCard = z.object({ kind: z.literal('pay-link'), /* … */ }).strict()
export const HandoffCard = z.object({ kind: z.literal('handoff'), /* … */ }).strict()
export const AgentCard   = z.object({ kind: z.literal('agent'),   /* … */ }).strict()
export const ListingCard = z.object({ kind: z.literal('listing'), /* … */ }).strict()

export const RichMessage = z.discriminatedUnion('kind',
  [PaymentCard, PayLinkCard, HandoffCard, AgentCard, ListingCard])
```

**Server pattern — seed-then-stream.** Tool resolves authoritative data server-side; model fills prose/reasoning fields only. The model *never* authors an address.

```typescript
// POST /api/chat — tool-dispatched path
import { streamObject } from 'ai'
import { PaymentCard } from '@/schema/rich-messages'
import { resolveBuy } from '@/lib/chat-skills'

if (tool.name === 'buy') {
  const seed = await resolveBuy(tool.args, context.buyerUid)
  //   → { listingId, providerUid, address, amount, memo, deadline } pulled from substrate + pool
  return streamObject({
    model: openrouter('anthropic/claude-haiku-4-5'),
    schema: PaymentCard,
    seed,                                                   // pre-populated; model adds reasoning only
    prompt: buildBuyPrompt(tool.args, context),
  }).toTextStreamResponse()
}
```

**Client pattern — `useObject` renders skeleton → partial → full; action button gates on required fields:**

```tsx
import { experimental_useObject as useObject } from '@ai-sdk/react'
import { PaymentCard } from '@/schema/rich-messages'
import { QrCode } from '@/components/ui/QrCode'

export function PaymentCardIsland({ streamUrl }: { streamUrl: string }) {
  const { object } = useObject({ api: streamUrl, schema: PaymentCard })
  return (
    <Card>
      <Row label="To">{object?.address ? <Address value={object.address}/> : <Skeleton/>}</Row>
      <Row label="Amount">{object?.amount ? <Amount {...object.amount}/> : <Skeleton/>}</Row>
      <Row label="Worst case">
        {object?.quote?.worstCaseReceived
          ? <Amount value={object.quote.worstCaseReceived}/>
          : <Spinner note="fetching quote…"/>}
      </Row>
      {object?.address && object?.amount && object?.memo &&
        <QrCode data={buildSuiUri(object)} />                {/* client-side render */}}
      {object?.sponsoredTx && <Badge>gas sponsored</Badge>}
      <TouchIdButton
        disabled={!object?.address || !object?.quote}
        onApprove={() => signPayment(object as z.infer<typeof PaymentCard>)}
      />
    </Card>
  )
}
```

**Rules that make it safe:**

- **Addresses resolve server-side** via `resolveBuy()` / substrate lookups. Model seeds from real data; can't hallucinate a recipient.
- **`.strict()` on every schema.** Zod drops unknown fields per chunk; injection attempts to smuggle extras fail.
- **Button gates on required fields.** Touch ID disabled until `address` and `quote` present; no race to sign a half-rendered card.
- **`deadline` on every value-moving card.** Client rejects if `Date.now() > deadline`; substrate rejects replay on signed tx.
- **QR / barcodes always client-side.** Deterministic render from `{address, amount, memo, chain}`; never streamed (saves bytes, prevents QR-swap attacks, no separate audit surface).

**Streaming threat-model rows** (extend §Threat model above):

| Attack | Streaming-specific defense |
| --- | --- |
| Prompt injection forges attacker address | `resolveBuy()` runs server-side; model seeds from substrate |
| Schema drift (model emits weird fields) | `streamObject` + Zod `.strict()` drop unknown fields per chunk |
| Race: user taps approve before quote arrives | Button disabled until required fields present |
| Replayed stale card | `deadline` checked on client *and* substrate |
| QR-swap (barcode tampered mid-flight) | QR never streamed — rendered client-side from already-validated fields |

**One schema, many consumers.** This transport applies to every rich-message-rendering surface — chat, handoff inbox, agent cards on `/u`, listing cards on `/buy`, pay-link cards on `/sell`. See `website.md` §Rich-message schemas for the cross-surface contract.

---

## Build plan — `mode: lean` · `lifecycle: construction`

Per `one/template-plan.md` §0 classifier, all four priors hold:

```yaml
mode: lean
lifecycle: construction
classifier:
  spec_locked: yes — chat.md (this doc) + website.md `/chat` section
  variance_known: yes — ChatShell is canonical; modes are parameterizations not new components
  exit_scalar: yes — speed budgets + bun run verify + threat-model rows still hold
  files_known: yes — chat-*.astro inventory above + src/components/ai/* + RichMessage schema
```

### 0 · `chat-session` — the durable-session primitive

- **goal:** `(sid, participants, cursor)` session primitive in TypeDB + attach/detach protocol on WsHub DO; every downstream step consumes it
- **speed:** attach → first replay <150ms warm / <500ms cold · re-attach after disconnect <1s
- **tasks:**
  - [ ] TypeDB schema: `session` and `session-event` relations in `src/schema/one.tql` (append-only, `(sid, seq)` primary key) — exit: `persist.appendEvent(sid, event)` is monotonic, rejects gaps
  - [ ] `src/lib/session.ts` — `createSession`, `attach(sid, cursor, token)`, `append`, `participants` helpers — exit: unit tests cover replay-from-cursor, reject-stale-token, reject-non-participant-send
  - [ ] Session token: signed `(sid, uid, exp)` via existing auth; short TTL, refreshable on attach — exit: hijack test (attach with valid `sid` but wrong `uid`) rejected
  - [ ] WsHub DO extended: one DO per `sid`, hydrates from TypeDB on cold start, fans out events to attached clients, hibernates when empty — exit: cold-attach + warm-attach both hit budget on `/speed`
  - [ ] SSE fallback on `GET /api/chat/:sid/stream` with `Last-Event-ID` as cursor — exit: same replay semantics as WS path; curl test
  - [ ] Reconcile tick: DO periodically verifies its cache matches TypeDB tail (per `mac.md` verification>presence motif) — exit: divergence test detects + corrects
- **verify gate:** `bun run verify` · all four session threat-model rows hold · attach budgets met · no existing `/chat` regression (it just doesn't use sessions yet)
- **close:** `/close --surface chat-session` with attach + re-attach + cross-device numbers

### 1 · `chat-canonicalize` — one shell, one route

- **goal:** `/chat` serves `ChatShell` (chat-v3); `ChairmanChat`, `FastChat`, `DebbyChat`, `AdChat`, `AdBuyChat` fold or sunset
- **speed:** first token <1s on `/chat`, no hydration regression vs `/chat-agents` today
- **tasks:**
  - [ ] Replace `ChairmanChat` import with `ChatShell` in `chat.astro` — exit: page renders, existing `POST /api/chat` contract unchanged
  - [ ] `/chat-agents` → 301 to `/chat` — exit: no 404s, telemetry shows migration
  - [ ] `FastChat` behavior as a `mode` flag on `ChatShell` (strip chrome, no animations) — exit: fast-chat path matches old latency on `/speed`
  - [ ] `AdChat` + `AdBuyChat` → render `ChatShell` with `mode=landing&seed=<source>` — exit: marketing pages still funnel into chat, telemetry tagged
  - [ ] `DebbyChat` folded into persona system — exit: `/chat?persona=debby` returns identical experience
- **verify gate:** `bun run verify` · first-token budget · no regressions on `/chat-routing` demo · `emitClick('ui:chat:<action>')` compliance · threat-model row "Fake pre-sign card" holds (feed is WsHub-sourced)
- **close:** `/close --surface chat-canonicalize` with first-token + hydration numbers

### 2 · `chat-streaming` — ai-sdk transport + Zod rich-message schemas

- **goal:** Zod-typed `RichMessage` union in `src/schema/rich-messages.ts`; `POST /api/chat` streams via ai-sdk `streamObject` with server-side seed; client islands use `useObject` for progressive render
- **speed:** first streamed field <300ms · all required fields <1.2s · QR <50ms after deps
- **tasks:**
  - [ ] `src/schema/rich-messages.ts` — Zod `.strict()` schemas for `PaymentCard`, `PayLinkCard`, `HandoffCard`, `AgentCard`, `ListingCard`; discriminated union on `kind`; shared between server + client — exit: `z.infer<typeof RichMessage>` covers every existing card variant in `docs/rich-messages.md`
  - [ ] `src/lib/chat-skills.ts` — `resolveBuy`, `resolveSell`, `resolveCreateAgent`, `resolveTightenScope`, etc. as server-side seed resolvers (address / price / memo from substrate, not model) — exit: unit tests confirm every resolver returns typed seed in <200ms median
  - [ ] `POST /api/chat` refactor to dispatch tool → seed → `streamObject` with schema + seed — exit: buyer arc returns a valid PaymentCard stream; schema validates on every chunk
  - [ ] Client islands: `PaymentCardIsland`, `PayLinkCardIsland`, `HandoffCardIsland`, `AgentCardIsland`, `ListingCardIsland` — each uses `experimental_useObject` from `@ai-sdk/react`; skeleton → partial → full; action buttons gate on required fields — exit: visual test per card + "button disabled until required fields" integration test
  - [ ] `src/components/ui/QrCode.tsx` — client-side QR render from `{address, amount, memo, chain}`; never receives streamed barcode — exit: renders identical output for identical inputs; no network calls
  - [ ] `deadline` check on every value-moving card — client rejects expired; substrate verifies on signed tx — exit: stale-card rejection test passes
- **verify gate:** `bun run verify` · stream budgets measured on `/speed` · every card schema has `.strict()` (grep check) · all five streaming threat-model rows hold (injection resolver test, schema drift test, race test, replay test, QR-swap test) · no model-authored address in any test fixture
- **close:** `/close --surface chat-streaming` with first-field + all-required + QR-render numbers

### 3 · `chat-modes` — lifecycle arcs as mode params

- **goal:** `mode=builder|buyer|seller|landing|persona` produces the right greeting, skill palette, and pheromone seed
- **speed:** mode resolution <50ms client-side (no extra roundtrip)
- **tasks:**
  - [ ] `src/lib/chat-modes.ts` — mode → greeting + starter prompts + skill palette mapping — exit: each mode has a fixture; switching modes re-renders
  - [ ] Skill palette per mode (builder sees `create-agent`, `deploy`; buyer sees `show-listings`, `buy`; seller sees `create-listing`, `share`) — exit: palette visible in UI, calls route via `persist.ask()`
  - [ ] Pheromone seed per mode — initial signal to `chat:<mode>` receiver tags the conversation — exit: `/tasks?tag=chat:builder` shows builder conversations
- **verify gate:** `bun run verify` · mode switch latency · three arcs end-to-end (smoke test: builder creates agent, buyer buys, seller lists) · threat-model row "Prompt injection" still holds
- **close:** `/close --surface chat-modes` with mode-switch + end-to-end arc timings

### 4 · `chat-embedded` — `⌘K` slide-over on every page

- **goal:** global keyboard shortcut opens a 600px-wide panel carrying current page context
- **speed:** `⌘K` → first-keystroke <100ms; context parse <50ms
- **tasks:**
  - [ ] `src/components/ai/ChatCmdK.tsx` — slide-over wrapper around `ChatShell` — exit: opens from any page, closes on Esc
  - [ ] Global keyboard handler in `src/layouts/Layout.astro` — exit: `⌘K` captured, no conflicts with existing shortcuts
  - [ ] Page-context injector — reads `window.location.pathname` + any page-level data attribute, injects as implicit intent — exit: `⌘K` on `/u/agents/trader-v1` + "tighten cap" parses against `agent=trader-v1` without restating
  - [ ] Telemetry: `ui:chat:embedded:open` with `page:<path>` tag — exit: pheromone accumulates per page, `/tasks?tag=chat:embedded` ranks them
- **verify gate:** `bun run verify` · open-latency budget · no hydration conflict on pages with existing keyboard handlers · threat-model rows for all 3 arcs hold inside the embedded widget
- **close:** `/close --surface chat-embedded` with open-latency + page-distribution

### 5 · `chat-api-surfaces` — API, SDK, MCP, CLI parity

- **goal:** `POST /api/chat`, `@oneie/sdk` `one.ask()`, `@oneie/mcp` tools, `oneie chat` CLI — all four route through `persist.ask()` with the same dispatch table
- **speed:** API first-byte <500ms; MCP roundtrip <2s; CLI roundtrip including browser-opening <3s
- **tasks:**
  - [ ] `POST /api/chat` reviewed + locked contract — exit: SSE stream, tool-call JSON shape matches SDK docs
  - [ ] SDK `one.ask({ receiver: "chat", data })` with biometric delegation callback — exit: SDK test suite covers sign-required path
  - [ ] MCP tools: `chat`, `buy`, `sell`, `show_agent`, `tighten_scope`, `create_agent`, `pay_link` — exit: all callable from Claude, pre-sign surfaces in user's web session
  - [ ] CLI `oneie chat <intent>` — exit: command parses, prints streaming response, opens browser for biometric when needed
  - [ ] Cross-mode telemetry — `toolkit:<mode>:chat` tags on every call — exit: dashboard §1b shows mode distribution for chat access
- **verify gate:** `bun run verify` · all four access modes pass smoke tests for buyer arc (simplest loop) · threat-model table above still holds per mode
- **close:** `/close --surface chat-api-surfaces` with per-mode latencies

### Dep chain

```
0 chat-session ──► 1 chat-canonicalize ──► 2 chat-streaming ──┬─► 3 chat-modes ──► 4 chat-embedded
                                                              └─► 5 chat-api-surfaces  (parallel after #2)
```

**#0 is the real foundation.** The session primitive (durable transport + durable state, per §Session primitive) is what every other step assumes. Canonicalization (#1) puts `ChatShell` on top of it; streaming (#2) writes `rich-message-chunk` events into it; modes (#3) tag sessions; embedded `⌘K` (#4) attaches to page-scoped sessions; API/SDK/MCP/CLI (#5) are all thin attach wrappers.

**Why session is #0, not #2:** without it, we ship `streamObject` straight into a dying HTTP response and re-pay the "turn as request" debt the industry is stuck on. Installing it first makes every later step simpler — #5 in particular collapses from four separate streaming contracts to one attach protocol.

**Cross-doc deps (from `website.md` build plan):**
- chat.md #1 partially overlaps with `website.md` #2 `chat-consolidation` — reconcile: chat.md #1 covers component canonicalization; `website.md` #2 keeps the skill-dispatch table, which now depends on chat.md #2 shipping schemas first
- chat.md #2 ships the Zod schemas that `website.md` #1 `handoff-inbox` imports for its rich-message variant — i.e., `HandoffCard` lands in `src/schema/rich-messages.ts` as part of chat.md #2
- chat.md #4 `chat-embedded` can piggyback on `website.md` #1's WsHub DO feed for live handoff cards inside `⌘K`

**Resolution:** the Zod schema file `src/schema/rich-messages.ts` is the single shared artifact. chat.md #2 creates it; every other card-rendering plan imports from it. One schema, five consumers (chat, handoff inbox, /u agent cards, /buy listing cards, /sell pay-link cards). See `website.md` §Rich-message schemas.

---

## What this doc does not cover

- **The persona system** — multi-tenant personas (Debby, donal, etc.) are defined in `nanoclaw/src/personas.ts`. chat.md surfaces them as a mode flag but doesn't spec the persona authoring workflow.
- **Chat-as-channel delivery** — Telegram, Discord, web webhook — covered by `nanoclaw/` + `one/nanoclaw.md`. chat.md is the browser surface; nanoclaw is the edge delivery.
- **Voice / audio** — `ChatShell` has voice-pulse UI primitives but the full voice loop (STT → substrate → TTS) is orthogonal and lives in a future voice.md.
- **Pricing / metering** — chat is free; capabilities cost. Cost flows handled by `buy-and-sell.md` + `revenue.md` in the one.ie repo.
- **RAG / memory** — long-term agent memory lives in TypeDB per `agents-memory.md`; chat.md just reads from it.

---

*Chat proposes. Human approves. Substrate routes. Five access modes, one biometric, zero bypass.*
