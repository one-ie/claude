# 03-chatbots — gap analysis

## Promise

`text/03-chatbots.md` sells four things:

1. **One brain, N channels.** Web + Telegram + Discord + iMessage + API + MCP all run against one TypeDB Group per client. Memory compounds across channels for the same user.
2. **Six active surfaces today.** Web, Telegram, Discord, iMessage, `/message` API, MCP — each with capability-matrix entries.
3. **Generative UI as the web differentiator.** Payment cards with claim buttons (Sui), map pins, forms, code blocks, attachments, images. Streams progressively. First token <300 ms p50. Lighthouse 100/100/100/100 measured 2026-05-03.
4. **Groups = scoped tenancy.** White-label cascade (agency → client → end user). RBAC + ABAC + ReBAC over the same `(slug, agentId, visitor-cookie)` substrate.

Sub-promises that show up in the FAQ table and the matrix:
- Streaming on Web + API SSE; complete-response on Telegram/Discord/iMessage.
- Native rich messages on web; "metered" (text+link) on Telegram/Discord/iMessage.
- Voice **input shipped on web**, output roadmap.
- Multi-bot per Telegram worker via `TELEGRAM_TOKEN_<NAME>`.
- Tool approval gates surfaced as cards (`needsApproval` on substrate writes).
- Cross-channel dedup via signal `id`.
- Cross-channel memory merge once the user authenticates on both surfaces.

## Code reality

### Web

| Promise | Reality | Path |
| --- | --- | --- |
| `/chat` route, dedicated full-page surface | Shipped — `client:idle` island | `/Users/toc/Server/one-ie/one/web/src/pages/chat.astro` |
| Streaming + first token <300 ms | Shipped via Groq `llama-3.3-70b-versatile` + AI SDK `streamText` → `toUIMessageStreamResponse`. Rate-limit detection peeks first 4 KB, swaps to Gemini Flash on Groq error | `/Users/toc/Server/one-ie/one/web/src/pages/api/chat.ts` (lines 988-1047) |
| Generative UI (payment, map, forms, code, image, file, claim, embed = 8 types) | **Partially shipped.** Tools that emit cards: `emit_card` (12 sub-kinds), `emit_section` (sectionSchema with stat/grid/list/compare/cta/embed/code/timeline/hotel/form/testimonial/faq/gallery), `emit_field_service_card` (severity/dispatch/calendar/job-tracker/map/scoping/quote/product/cart), `emit_boq_card` (package/discovery/quote/onboarding). Card components live in `/Users/toc/Server/one-ie/one/web/src/components/chat/cards/` (13 components) and `/Users/toc/Server/one-ie/one/web/src/components/chat/` (PaymentCard, BoqCardRenderer, FieldServiceCardRenderer, PtcorpCardRenderer, MessageRenderer, ToolApprovalPart) | see lines 618-708 of chat.ts |
| Server-side address resolution (model never authors addresses) | **PaymentCard accepts free-text receipt** from the user — there is no `paymentTool` that pre-seeds `{address, amount}` from substrate. Address is a workspace owner attribute pulled out of band; payment is a copy-wallet-and-paste-receipt flow with KV-deduped receipt verification (`verifyReceipt`). No on-chain claim button | `web/src/components/chat/PaymentCard.tsx`; `chat.ts` lines 467-496 |
| Tool approval gate (Touch ID for substrate writes) | **Web has no approval gate.** `write` tool returns `{ kind: 'pending', challenge, token }` and the client renders a confirm UI via `ToolApprovalPart.tsx`, but it's a passkey signature against `SERVER_SECRET`, not a value-moving signing flow. claw's `aitools.ts` uses `needsApproval: true` on `remember`/`mark`/`warn` — but **web's `/api/chat` doesn't import these claw tools** | `web/src/components/chat/ToolApprovalPart.tsx`; `claw/src/aitools.ts:60,124,146` |
| Lighthouse 100/100/100/100 | Tracked in `mem feedback_dark_mode_contrast`, `project_chat_lighthouse`. Lazy-import discipline enforced via `.claude/rules/astro.md` | layout-level |
| Map pin (Leaflet) | Shipped — but only inside `field-service-card.kind=map`. Not a top-level emit | `web/src/components/chat/cards/MapCard.tsx` |
| Voice input | Shipped — `web/src/components/ai-elements/speech-input.tsx`, lazy-loaded behind `Suspense` per design rule | `web/src/components/chat/VoiceMenu.tsx` |
| Streaming protocol = AI SDK v6 `streamObject` + Zod `RichMessage` union | **Not built.** `chat.md` §Component streaming specifies `src/schema/rich-messages.ts` as the single shared `discriminatedUnion('kind', [PaymentCard, PayLinkCard, HandoffCard, AgentCard, ListingCard])`. The file does not exist. Cards are streamed via per-tool `inputSchema` discriminated unions (`emit_card`, `sectionSchema`, `fieldServiceCardSchema`, `boqCardSchema`) — four separate contracts | n/a |

### Messaging

| Promise | Reality | Path |
| --- | --- | --- |
| Telegram live, multi-bot via `TELEGRAM_TOKEN_<NAME>` | Shipped. Webhook `/webhook/telegram` and `/webhook/telegram-<name>`; group prefix `tg-<name>-<chat>`; `resolveTelegram` walks env. Webhook path runs OpenRouter/Groq raw `fetch` (not `streamText` / `ToolLoopAgent`) and `await send(...)` after `await fetch(...)` | `claw/src/channels.ts`; `claw/src/index.ts` lines 204-307 |
| Discord live, `Authorization: Bot` header, ping verification | Adapter shipped (`normalizeDiscord`, `sendDiscord`). **Discord Interactions endpoint not present.** No signature verification (`x-signature-ed25519`), no PING/PONG handler, no slash-command registration; only the `messageCreate`-shaped payload via `/webhook/discord`. Discord won't deliver messages without either gateway connection or Interactions endpoint with ed25519 verify | `claw/src/channels.ts:56-80` |
| iMessage (Apple Business Messages) | **Not built.** No `normalizeApple` in `channels.ts`. `normalize()` switch only handles `telegram`, `telegram-*`, `discord`, `web` | `claw/src/channels.ts:99-108` |
| WhatsApp | **Not built.** No WhatsApp Business adapter | n/a |
| Same `ToolLoopAgent` loop in every channel | **No.** Web `/api/chat` uses `streamText` directly (AI SDK + Groq). Claw `/message` uses `createAgentUIStreamResponse({ agent })` with `makeAgent` (`ToolLoopAgent` per persona). Claw `/webhook/:channel` uses raw `fetch` to OpenRouter (not `streamText`, no streaming, no `substrateMiddleware`). Three separate code paths, three separate tool sets | `web/src/pages/api/chat.ts:1000`; `claw/src/index.ts:192,264` |
| Rich messages on Telegram/Discord as "text + link" | Partially shipped. `sendTelegram` posts Markdown, `sendDiscord` posts content. Neither renders a payment/claim button; the agent must inline a URL in prose. No payment-link adapter that materialises a one.ie/buy or pay.one.ie URL from a substrate listing | `claw/src/channels.ts:46-80` |
| Dedup via signal `id` | Adapters set `id` (`tg-<msg_id>`, `dc-<msg_id>`, `web-<ts>`), and webhook insert uses `INSERT OR IGNORE` keyed on `id` for `messages`. So D1 dedup exists; cross-channel dedup not exercised (no two channels point at the same `id`) | `claw/src/index.ts:235` |
| Slash commands `/memory`, `/forget`, `/explore` | Shipped on webhook path only | `claw/src/index.ts:213-224`; `claw/src/memory.ts` |
| `/message` API streams AI SDK UIMessage protocol | Shipped — `createAgentUIStreamResponse({ agent, uiMessages, options })` | `claw/src/index.ts:192-196` |
| MCP — `chat`, `buy`, `sell`, `show_agent`, `tighten_scope`, `create_agent`, `pay_link` tools | `mcp/` package exists per top-level `CLAUDE.md`, but tool surface and "pre-sign surfaces in user's web session" is unverified. The chat.md spec §5 lists this as a planned wave, not shipped | `mcp/` |

### Groups

| Promise | Reality | Path |
| --- | --- | --- |
| Group = scoped container; one TypeDB Group per client | Substrate registration via `ensureRegistered(env, signal.group)` on every webhook; `groups` table in D1; `mark/warn` paths persisted via gateway. **TypeDB is optional** — falls back to D1-only when `GATEWAY_URL` unreachable (`claw/README.md:124-133`) | `claw/src/substrate.ts`; `claw/src/index.ts:227` |
| Per-channel group prefixes (`tg-`, `dc-`, `web-`) | Shipped at the adapter layer, not at the substrate layer — group ids are routing keys, not TypeDB entities with parent/child relations | `claw/src/channels.ts` |
| Cross-channel memory merge for authenticated users | **Not shipped.** FAQ admits "Per the current architecture, no. Each channel creates its own substrate group … When they do authenticate, the substrate merges the context" — there is no merge code path. claw has no auth. Web auth (`readCookieId` + `visitorHash`) keys threads on visitor cookie, never reconciled with `tg-<chat_id>` or `dc-<channel_id>` | `web/src/lib/threads.ts`; `web/src/lib/identity.ts` |
| White-label cascade (agency → client → end user) | Partial — `workspaceContext` on locals; `parentWorkspace` for revenue split; brand tokens per workspace. **Group tree is not recursive at substrate layer.** D1 `groups` table is flat in claw; web has separate `workspaces` table; no `parent_group_id` edges | `web/src/lib/revenue-split.ts`; D1 schema |
| Multi-actor rooms = groups with N members | Partial. Telegram/Discord group chats land in one `tg-<chat_id>` or `dc-<channel_id>` group; conversation history includes every sender. **Per-member access control / "private group invisible to non-members at API level"** not implemented in claw — `GET /messages/:group` and `GET /highways` gate on `API_KEY` bearer only, not on membership | `claw/src/index.ts:108-117,126-134` |
| Voice contract / quality score 0.65 gate before send | **Not built.** Promise: "Every outbound message passes through a voice contract check before it sends. The quality score gate is 0.65. Responses below it are held and escalated." No `verifyOutboundMessage`, no `qualityScore`, no held-message queue. claw sends straight to channel after LLM response. Web sends straight to UI via `streamText` | n/a |
| RBAC / ABAC / ReBAC three layers | **Not built as advertised.** No role enum on `groups`, no TypeQL ABAC policy queries fronting reads, no pheromone-trust-block-before-role-check. `isToxic(env, 'entry', groupUid)` is the only gate and it's only on `/message`, not on webhook | `claw/src/substrate.ts`; `claw/src/index.ts:149` |
| Session primitive — `(sid, participants, cursor)`, durable transport, attach/detach | **Not built.** `chat.md` §Session primitive is the foundation step #0 of the build plan. Web uses turn-based HTTP poll + `streamText` SSE per turn; claw uses webhook-per-message. Cross-device re-attach, fan-out, peer-agent participation all rely on this, none of which exists | n/a |

## Gaps

Ranked by how much they widen the gap between marketing copy and what a Brad prospect will hit in week 1.

1. **iMessage and WhatsApp are not adapters — they're vapour.** The capability matrix lists both as live (iMessage) or "metered" with claim-button. There is no `normalizeApple` or `normalizeWhatsapp` in `claw/src/channels.ts`. A prospect who reads page 3 and asks for iMessage will discover the adapter on day one. **Severity: high — table is explicit, code is empty.**
2. **Discord ingress is incomplete.** No Interactions endpoint with ed25519 signature verification, no PING handler, no slash-command registration. Setup instructions in `claw/README.md` point at a webhook URL that Discord will reject without ed25519. Either run a gateway relay (not present) or build the Interactions handler.
3. **One brain across channels is half-true.** Each channel is its own substrate group (`tg-<chat>`, `dc-<chat>`, `web-<visitor>`). The unified-corpus claim ("the dental patient switches Telegram → web and the agent knows") requires a group-merge path that does not exist. The FAQ already softens this, but the hero paragraph and the dental-practice scenario do not.
4. **Voice contract gate is not built.** Page 03 sells it as a mechanical pre-send check with a 0.65 quality threshold and a hold-and-escalate fallback. No code enforces this. The "847 enquiries handled, zero off-contract" claim in the Named Integration section is uncheckable.
5. **No session primitive.** chat.md §0 puts this as the foundation of the build plan because every other claim about cross-device, agent-restart-survival, peer-agent participation and multi-client fan-out depends on it. Today, drop wifi → lose the turn; close the tab → lose the stream; agent restart → orphan the in-flight tool loop.
6. **Three streaming contracts instead of one.** Web uses `streamText` + 4 separate card schemas (`emit_card`, `emit_section`, `emit_field_service_card`, `emit_boq_card`). Claw `/message` uses `createAgentUIStreamResponse({ agent })`. Claw webhooks use raw `fetch` to OpenRouter, no streaming, no `substrateMiddleware`. The promised `src/schema/rich-messages.ts` discriminated union does not exist, so any client that wants to render a card has to know which tool produced it.
7. **Web payment card is not a payment card.** Promise: claim button → Sui transaction executes → webhook confirms in thread, "5 seconds, all in." Reality: a `PaymentCard` component that asks the user to paste a transaction hash, plus `verifyReceipt` against KV. No on-chain claim, no Sui sign flow, no x402 receive integration on the chat surface.
8. **Tool approval gates exist in claw, not in web.** `claw/src/aitools.ts` marks `remember`/`mark`/`warn` with `needsApproval: true`. The web `/api/chat` does not import these tools — it has its own write/eval/skill/payment/import_skill/compile/patch_agent/patch_theme set, and only `write` returns a `pending` shape. So the "every substrate write pauses for approval" pitch only applies to the claw-backed surfaces.
9. **RBAC/ABAC/ReBAC layers are aspirational.** No role enum, no TypeQL policy queries, no pheromone-trust-blocks-role check. The page promises three layers and uses it as a security selling point.
10. **Cross-channel dedup is local only.** Each channel's adapter generates an `id`; D1 `INSERT OR IGNORE` dedups within a channel; nothing reconciles the same logical message arriving on two channels (e.g. a forwarded WhatsApp → Telegram bridge).

## Recommended improvements

Three tracks, ordered by gap-vs-effort.

**Track A — close the channel matrix (highest reputational risk).**
- Stop selling iMessage and WhatsApp as live. Move them to "Q3 roadmap" in the matrix and the hero. Or build the two normalizer/sender pairs in `claw/src/channels.ts` and the two webhook routes in `claw/src/index.ts`. The adapter shape is 30 lines per channel; the credential plumbing (Apple Business Messages registration, WhatsApp Business API token) is the actual cost.
- Build the Discord Interactions endpoint: PING/PONG, `x-signature-ed25519` verification via `discord-interactions` or hand-rolled `tweetnacl`, slash-command registration on deploy.
- Unify the three streaming paths into one: claw `/message` is already AI SDK v6; port webhook path to `streamText`/`createAgentUIStreamResponse` + `substrateMiddleware` so Telegram and Discord get the same tool surface as web; chunk-then-send for channels without native streaming (post the message after `result.text`).

**Track B — make the brain promise real.**
- Ship `src/schema/rich-messages.ts` per chat.md §Component streaming. Make `emit_card`, `emit_section`, `emit_field_service_card`, `emit_boq_card` all reduce to one `RichMessage` discriminated union with `.strict()`. Card components import the type once.
- Wire a `PaymentTool` in `web/src/pages/api/chat.ts` that pre-seeds `{address, amount, memo, deadline, chain}` from a server-side resolver (no model-authored addresses). Drop the paste-receipt UI; integrate the Sui claim flow already present at `pay.one.ie` (per workspace plan).
- Build the voice-contract gate. A `verifyOutbound(text, agentMd)` function that pulls `voice:` block from agent frontmatter (banned topics, required disclaimers, persona vocabulary) and scores via a cheap classifier or LLM-as-judge. Hold below 0.65, surface in `/u/<slug>/in` for owner review.
- Cross-channel merge: when a Telegram or Discord user authenticates on the web, write a `same-as` edge from `tg-<chat>:sender` → `slug:visitor`. `/api/export/conversations` picks it up and the agent's `recall` query unions.

**Track C — session primitive (chat.md #0).**
- Ship the durable-session primitive before any other chat work. `(sid, participants, cursor)` in TypeDB, attach/detach on a WsHub DO, every access mode (web, API, SDK, MCP, CLI) becomes a thin wrapper. This is what makes "agent restart doesn't notice", "drop wifi keeps the turn", and "peer-agent joins mid-conversation" buildable. Without it, the page-03 claims about resilience are theatre.

**Documentation honesty pass (do today):**
- Edit the matrix on page 03: iMessage and WhatsApp move to "Roadmap" until adapters land.
- Soften the dental-practice cross-channel paragraph until the merge edge exists.
- Replace "every outbound message passes through a voice contract check" with "voice contract checks are configurable per-agent and run on owner-flagged surfaces" — until the gate ships.
- Replace the payment-card walkthrough with the actual paste-receipt flow OR ship the Sui claim flow before next sales cycle.

## Files to touch

| Concern | File |
| --- | --- |
| Add iMessage adapter | `/Users/toc/Server/one-ie/one/claw/src/channels.ts` (`normalizeApple`, `sendApple`, extend `normalize()` + `send()`) |
| Add WhatsApp adapter | same |
| Discord Interactions endpoint | `/Users/toc/Server/one-ie/one/claw/src/index.ts` (new route `POST /interactions/discord` with ed25519 verify) |
| Unify streaming on webhook path | `/Users/toc/Server/one-ie/one/claw/src/index.ts` lines 204-307 (replace raw OpenRouter `fetch` with `streamText` + `substrateMiddleware`); `/Users/toc/Server/one-ie/one/claw/src/middleware.ts` |
| Single RichMessage schema | new: `/Users/toc/Server/one-ie/one/web/src/schema/rich-messages.ts`; consumers: `/Users/toc/Server/one-ie/one/web/src/pages/api/chat.ts` (lines 618-708), `/Users/toc/Server/one-ie/one/web/src/lib/sections.ts`, `/Users/toc/Server/one-ie/one/web/src/lib/field-service-cards.ts`, `/Users/toc/Server/one-ie/one/web/src/lib/boq-cards.ts`, `/Users/toc/Server/one-ie/one/web/src/components/chat/MessageRenderer.tsx` |
| Real PaymentCard with Sui claim | `/Users/toc/Server/one-ie/one/web/src/components/chat/PaymentCard.tsx`; new `paymentTool` in `/Users/toc/Server/one-ie/one/web/src/pages/api/chat.ts`; resolver in `/Users/toc/Server/one-ie/one/web/src/lib/chat-skills.ts` (new file per chat.md §2) |
| Voice contract gate | new: `/Users/toc/Server/one-ie/one/web/src/lib/voice-contract.ts`; hook into `onFinish` of `streamText` in `/Users/toc/Server/one-ie/one/web/src/pages/api/chat.ts` and into claw `/webhook/:channel` before `send()` |
| Cross-channel actor merge | `/Users/toc/Server/one-ie/one/web/src/lib/identity.ts`; new edge writer in claw `/Users/toc/Server/one-ie/one/claw/src/substrate.ts`; surface in `/Users/toc/Server/one-ie/one/web/src/pages/api/export/conversations*` |
| Session primitive | new TypeDB schema entries (root `one.ie/src/schema/one.tql`); new `web/src/lib/session.ts`; WsHub DO extension; SSE fallback `web/src/pages/api/chat/:sid/stream.ts` |
| Approval gates on web substrate writes | `/Users/toc/Server/one-ie/one/web/src/pages/api/chat.ts` (import shared claw aitools or replicate `needsApproval` shape); `/Users/toc/Server/one-ie/one/web/src/components/chat/ToolApprovalPart.tsx` |
| Marketing honesty pass | `/Users/toc/Server/one-ie/one/text/03-chatbots.md` (matrix row updates; dental scenario softening; payment-card walkthrough fix) |
