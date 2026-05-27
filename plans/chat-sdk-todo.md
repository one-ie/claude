---
title: chat-sdk — unified bot adapter for agents/
slug: chat-sdk
type: plan
tier: simple
mode: construction
tags: [agents, telegram, discord, chat-sdk, refactor]

goal: "The agents/ worker routes Telegram and Discord webhooks through chat-sdk's unified Chat class instead of custom normalize/send code in channels.ts."
outcome: "grep -q '@chat-adapter/telegram' one-ie/agents/src/bot.ts && grep -q 'bot.webhooks' one-ie/agents/src/index.ts && echo pass"
outcome_asserts: "bot.ts exists with a Chat instance using the telegram adapter, and index.ts delegates /webhook/telegram to bot.webhooks — the custom normalize/send plumbing is no longer the ingress path."

deliverables:
  - module: agents/src/bot.ts — Chat instance with telegram + discord adapters, onNewMessage wraps existing ingest/recall/LLM pipeline (C1, C2)
  - refactor: agents/src/index.ts — /webhook/telegram* and /webhook/discord delegate to bot.webhooks.* instead of calling normalize/send directly (C1, C2)
  - cleanup: agents/src/channels.ts — normalizeTelegram / sendTelegram / normalizeDiscord / sendDiscord deleted; file reduced to normalizeWeb only (C3)

ux_before: "Telegram/Discord messages are parsed with 80-line custom normalize/send functions in channels.ts — no streaming on Telegram, no card rendering, multi-bot support wired by hand."
ux_after: "Telegram gets native post+edit streaming; Discord and Telegram share one onNewMessage handler; cards render as inline keyboards on Telegram and embeds on Discord."
ux_delta: "Streaming replies on Telegram and a single handler replacing two custom platform code paths."

parallel_budget:
  haiku:   10
  sonnet:  6
  opus:    1

batches:
  - [C1]       # foundation — telegram + bot.ts
  - [C2]       # discord (extends bot.ts from C1)
  - [C3]       # cleanup — delete replaced code from channels.ts

shared_recon:
  - agents/src/index.ts
  - agents/src/channels.ts
  - agents/src/pipeline.ts
  - agents/src/agents/builder.ts
  - agents/package.json

source_of_truth:
  - agents/src/channels.ts
  - agents/src/index.ts
  - apps/chat-sdk/packages/adapter-telegram/src/index.ts

existing_primitives:
  - agents/src/pipeline.ts: ingest() + recall() + measureOutcome() — stay unchanged; C1's onNewMessage calls them
  - agents/src/agents/builder.ts: makeAgent() / ToolLoopAgent — stays unchanged; onNewMessage handler can delegate to it
  - apps/chat-sdk/packages/adapter-telegram/src/index.ts: TelegramAdapter — C1 installs and registers
  - apps/chat-sdk/packages/adapter-discord/src/index.ts: DiscordAdapter — C2 installs and registers
  - agents/src/channels.ts: normalizeWeb — survives C3; only telegram/discord code deleted

show: false
escape:
  condition: "C1 W4 fails because @chat-adapter/telegram uses Node crypto/buffer APIs not available on CF Workers"
  action: "halt; check adapter for node: polyfill deps in wrangler.toml; if unresolvable, scope back to types-only integration and file separate plan"
context_triggers:
  - pattern: "wrangler|cloudflare|compatibility_flags"
    inject: "agents/wrangler.toml"
---

# chat-sdk — unified bot adapter for agents/

## Goal, outcome, deliverables, UX

### Goal

The agents/ worker routes Telegram and Discord webhooks through chat-sdk's unified `Chat` class instead of the custom normalize/send functions in `channels.ts`.

### Outcome (the kill-switch)

```bash
grep -q '@chat-adapter/telegram' one-ie/agents/src/bot.ts && grep -q 'bot.webhooks' one-ie/agents/src/index.ts && echo pass
```

**What passing proves:** `bot.ts` exists with a live `Chat` instance using the telegram adapter, and `index.ts` delegates `/webhook/telegram` to `bot.webhooks` — the custom normalize/send plumbing is no longer the ingress path.

### Deliverables

| Kind | Path | What the user / operator gets |
|---|---|---|
| module | `agents/src/bot.ts` | Chat instance with telegram + discord adapters; `onNewMessage` wraps ingest/recall/LLM pipeline (C1, C2) |
| refactor | `agents/src/index.ts` | `/webhook/telegram*` and `/webhook/discord` delegate to `bot.webhooks.*` (C1, C2) |
| cleanup | `agents/src/channels.ts` | `normalizeTelegram`, `sendTelegram`, `normalizeDiscord`, `sendDiscord` deleted; file reduced to `normalizeWeb` only (C3) |

### UX: before → after

| | Today | After |
|---|---|---|
| **Telegram reply** | Single `sendMessage` call, no streaming | `thread.post(textStream)` — post+edit as tokens arrive |
| **Card rendering** | Plain text only | `Card()` → inline keyboard on Telegram, embed on Discord |
| **Multi-bot Telegram** | Manual token routing via `TELEGRAM_TOKEN_<NAME>` + custom regex | Named adapter instances, each with their own token |
| **Discord reply** | `sendDiscord()` raw fetch | `thread.post()` via DiscordAdapter |
| **Platform code paths** | Two separate normalize/send branches | Single `onNewMessage` handler for both |

**The delta:** Streaming replies on Telegram and one handler where there were two.

---

## Reuse contract

| Proposed new file | Closest existing | Gap | Verdict |
|---|---|---|---|
| `agents/src/bot.ts` | `agents/src/channels.ts` | channels.ts is a flat dispatch util, not a `Chat` instance with lifecycle | **new** — Chat class initialization can't be slotted into channels.ts |

All other changes are edits to existing files. New file count: 1. Justified.

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline
  - [ ] W1 shared recon

Batch 1
  - [ ] C1 — telegram adapter + bot.ts          state: ready

Batch 2  (fires when C1 closes)
  - [ ] C2 — discord adapter                    state: blocked-on-C1

Batch 3  (fires when C2 closes)
  - [ ] C3 — cleanup channels.ts                state: blocked-on-C2

Plan close
  - [ ] Plan outcome command exits 0
  - [ ] Every deliverables row shipped
  - [ ] Final compress sweep
  - [ ] Final docs append
  - [ ] Plan rubric ≥ 0.65
```

---

## C1 — telegram adapter + bot.ts  [tier: simple · batch: 1]

**Goal delta:** After this cycle, `/webhook/telegram` is handled by chat-sdk's `TelegramAdapter` instead of `normalizeTelegram` + raw fetch; the existing `ingest`/`recall`/LLM pipeline runs inside `bot.onNewMessage`.

**Deliverable:** `agents/src/bot.ts` + `agents/src/index.ts` refactor — `/webhook/telegram*` delegates to `bot.webhooks.telegram`.

**UX delta:** Telegram replies stream via post+edit; slash commands (`/memory`, `/forget`, `/explore`) route through the same handler.

**Cycle outcome:** `grep -q '@chat-adapter/telegram' agents/src/bot.ts && grep -q 'bot.webhooks.telegram' agents/src/index.ts`

**Demo gate:**
```yaml
demo:
  command: "cd agents && bun run typecheck"
  asserts: "bot.ts and updated index.ts type-check cleanly — no new tsc errors"
  budget:  "<10s wall · 0 LOC test (tsc is the gate)"
```

### W1 — Recon  [Haiku · parallel]

Cycle-specific files (shared_recon files already cached at plan start):

1. **Existing-code recon**
   - [ ] `agents/src/index.ts` lines 357–460 — exact webhook handler shape: how `normalize`, `ingest`, `recall`, `send`, tool loop are wired; which parts stay, which are replaced
   - [ ] `agents/src/channels.ts` — full normalize/send surface; confirm what C1 must replace vs what survives
   - [ ] `agents/wrangler.toml` — compatibility_flags and node_compat setting (CF Workers requires `nodejs_compat` for `crypto` module used by telegram adapter signature verification)

2. **Primitive-inventory recon**
   - [ ] `apps/chat-sdk/packages/adapter-telegram/src/index.ts` — exported names, `TelegramAdapter` config shape, `getUser` equivalent, webhook method name on `Chat` instance
   - [ ] `apps/chat-sdk/packages/chat/src/index.ts` — `Chat` constructor signature, `onNewMessage` callback signature, `state` requirement, `webhooks` property shape
   - [ ] `apps/chat-sdk/packages/state-memory/src/index.ts` (if exists) — `createMemoryState` import for dev wiring

### W2 — Decide  [Sonnet]

- [ ] **Goal-delta verified** — C1 diff moves plan outcome closer (bot.ts created, index.ts wired)
- [ ] **Compose-or-construct verdict** — bot.ts is justified new file (see reuse contract above)
- [ ] **Multi-bot Telegram resolution** — current code supports `/webhook/telegram-<name>` → `TELEGRAM_TOKEN_<NAME>`. W2 must decide: (a) register one TelegramAdapter per named bot, each with its own token, each mapped to a specific Hono route; OR (b) single adapter with a `getToken` callback. Name the exact solution before W3.
- [ ] **State adapter for CF Workers** — `state-memory` is dev-only; for production, decide whether to stub with memory for now (note in bot.ts comment) or wire KV-backed state immediately. Default: memory now, KV in a follow-up.
- [ ] **`thread.post()` vs raw fetch** — the current LLM call is a raw `fetch` to OpenRouter (not AI SDK). W2 decides: keep raw fetch inside `onNewMessage` (simplest, no behavior change) OR migrate to `streamText` + `thread.post(textStream)` for real streaming. Recommendation: keep raw fetch in C1, migrate to streamText in a separate plan.
- [ ] **Diff specs output** for W3a targets
- [ ] **Architectural questions answered:**
  - Does `TelegramAdapter` constructor need `TELEGRAM_TOKEN` from `env`? (CF Workers env is only available at request time, not module init — solution: lazy init or pass token via factory)
  - Does `chat-sdk`'s `Chat` class work without a module-level `await`? (CF Workers has no top-level await in non-ESM mode)

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `agents/src/bot.ts` — **create new file**: `new Chat({ userName: 'claw', adapters: { telegram: createTelegramAdapter(...) }, state: createMemoryState() })` + `bot.onNewMessage` handler containing the existing ingest/recall/LLM pipeline logic extracted from index.ts; export `bot`
- [ ] `agents/package.json` — add `chat`, `@chat-adapter/telegram`, `@chat-adapter/state-memory` to dependencies

**W3b — dependent (after W3a, bot.ts must exist):**
- [ ] `agents/src/index.ts` — replace `POST /webhook/:channel` telegram branch: `app.post('/webhook/telegram', c => bot.webhooks.telegram(c.req.raw))`; keep discord branch calling existing `normalizeDiscord`/`sendDiscord` until C2; keep all other routes untouched

### W4 — Verify  [inline composite]

- [ ] `bun run typecheck` green in `agents/` (zero new tsc errors)
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `grep -q '@chat-adapter/telegram' agents/src/bot.ts` exits 0
- [ ] `grep -q 'bot.webhooks.telegram' agents/src/index.ts` exits 0
- [ ] `wc -l agents/src/bot.ts` ≤ 80 LOC (logic is moved, not duplicated)
- [ ] **Reuse audit:**
  - [ ] `ingest`, `recall`, `measureOutcome` from `pipeline.ts` are imported in `bot.ts` (not reimplemented)
  - [ ] `channels.ts` `normalizeTelegram`/`sendTelegram` still present (not deleted yet — C3's job)
  - [ ] No new LLM call implementation — raw fetch loop moved verbatim from index.ts into bot.ts handler
- [ ] **Plan outcome re-check** — `grep -q '@chat-adapter/telegram' agents/src/bot.ts && grep -q 'bot.webhooks' agents/src/index.ts` recorded
- [ ] Goal-fit ≥ 0.50 (hard) · composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  new_files=1  primitives_composed=3`

---

## C2 — discord adapter  [tier: simple · batch: 2]

**Goal delta:** `/webhook/discord` routes through `DiscordAdapter` inside the same `bot` instance; `normalizeDiscord`/`sendDiscord` are no longer called from index.ts.

**Deliverable:** `agents/src/bot.ts` extended with discord adapter + `agents/src/index.ts` `/webhook/discord` route updated.

**UX delta:** Discord replies via `thread.post()` with card support; Discord and Telegram share one `onNewMessage` handler.

**Cycle outcome:** `grep -q '@chat-adapter/discord' agents/src/bot.ts && grep -q 'bot.webhooks.discord' agents/src/index.ts`

**Demo gate:**
```yaml
demo:
  command: "cd agents && bun run typecheck"
  asserts: "bot.ts with discord adapter type-checks cleanly"
  budget:  "<10s wall"
```

### W1 — Recon  [Haiku]

- [ ] `apps/chat-sdk/packages/adapter-discord/src/index.ts` — exported names, config shape, `getUser` equivalent, `webhooks.discord` method on Chat instance; compare to TelegramAdapter shape from C1
- [ ] `agents/src/bot.ts` (post-C1) — current Chat constructor shape; where discord adapter slot goes
- [ ] `agents/src/index.ts` (post-C1) — current `/webhook/discord` branch to be replaced

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict** — bot.ts extended (no new files)
- [ ] **Discord interaction verification** — Discord sends `X-Signature-Ed25519` / `X-Signature-Timestamp` headers. Confirm `DiscordAdapter` handles signature verification natively (no custom code needed).
- [ ] **Single onNewMessage handler** — C1's handler is platform-agnostic (calls `ingest(channel, sender, ...)` where `channel` is derived from the message source). W2 confirms the discord message gives the same fields; if not, adjust the ingest call inside the handler.
- [ ] **Diff specs output** for W3a targets

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `agents/src/bot.ts` — add `@chat-adapter/discord` import; add `discord: createDiscordAdapter({ ... })` to `Chat` adapters; same `onNewMessage` handler covers both platforms
- [ ] `agents/package.json` — add `@chat-adapter/discord` dependency

**W3b — dependent:**
- [ ] `agents/src/index.ts` — replace `/webhook/discord` branch: `app.post('/webhook/discord', c => bot.webhooks.discord(c.req.raw))`

### W4 — Verify  [inline composite]

- [ ] `bun run typecheck` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `grep -q '@chat-adapter/discord' agents/src/bot.ts` exits 0
- [ ] `grep -q 'bot.webhooks.discord' agents/src/index.ts` exits 0
- [ ] `normalizeDiscord`/`sendDiscord` still in channels.ts (C3 deletes them)
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

Report: `delta_tsc=±N  delta_loc=±N  new_files=0  primitives_composed=4`

---

## C3 — cleanup channels.ts  [tier: trivial · batch: 3]

**Goal delta:** Dead code eliminated; `channels.ts` contains only `normalizeWeb` (still used by `/webhook/web`).

**Deliverable:** `agents/src/channels.ts` with `normalizeTelegram`, `sendTelegram`, `normalizeDiscord`, `sendDiscord`, `normalize`, `send` deleted.

**UX delta:** Internal-only. No user-visible change. Justified: removes 80 LOC of replaced code; channels.ts is no longer the telegram/discord ingress path.

**Cycle outcome:** `grep -q 'normalizeTelegram\|sendTelegram\|normalizeDiscord\|sendDiscord' agents/src/channels.ts && echo FAIL || echo pass`

**Demo gate:**
```yaml
demo:
  command: "cd agents && bun run typecheck && grep -q 'normalizeTelegram' agents/src/channels.ts && echo FAIL || echo pass"
  asserts: "normalizeTelegram is gone and tsc still passes"
  budget:  "<10s wall"
```

### W1 — Recon  [inline]

- [ ] `agents/src/channels.ts` — list every export; confirm which are still imported anywhere after C1+C2
- [ ] `grep -r 'normalizeTelegram\|sendTelegram\|normalizeDiscord\|sendDiscord\|normalize\|^send' agents/src/` — confirm zero callers remain after C1+C2 changes

### W2 — Decide  [inline]

- [ ] Confirm `normalizeWeb` is still called from index.ts `/webhook/web` route — keep it
- [ ] Confirm `normalize` and `send` (the dispatch functions) have no callers post-C1+C2 — delete
- [ ] Diff spec: delete lines for each dead export from channels.ts

### W3 — Edit  [Sonnet · single file]

**W3a:**
- [ ] `agents/src/channels.ts` — delete `normalizeTelegram`, `sendTelegram`, `normalizeDiscord`, `sendDiscord`, `resolveTelegram`, `normalize`, `send`; keep `normalizeWeb`

**W3b:** *(empty)*

### W4 — Verify  [inline]

- [ ] `bun run typecheck` green
- [ ] `grep -q 'normalizeTelegram' agents/src/channels.ts && echo FAIL || echo pass` exits with `pass`
- [ ] `grep -rq 'from.*channels' agents/src/index.ts` still imports `normalizeWeb` (confirm not over-deleted)
- [ ] **Plan outcome command exits 0** — `grep -q '@chat-adapter/telegram' agents/src/bot.ts && grep -q 'bot.webhooks' agents/src/index.ts && echo pass`
- [ ] `delta_loc_net < 0` (this cycle is net deletion — required)
- [ ] Goal-fit ≥ 0.50 · composite ≥ 0.65

Report: `delta_tsc=0  delta_loc=-N  new_files=0  deleted_functions=6`

---

## See also

- `agents/CLAUDE.md` — file map + route surface (don't add routes)
- `apps/chat-sdk/` — cloned vercel/chat repo — reference for adapter APIs
- `apps/zern-chat-sdk-adapter/` — Zernio multi-platform adapter (IG/FB/WhatsApp/X/Bluesky/Reddit) — follow-on plan candidate after this one ships
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands
