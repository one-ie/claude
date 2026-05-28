# chat.ts — gate, proxy, meter

> The web chat endpoint stops being a runtime and becomes a **doorman**: it proves who's
> knocking, charges the cover, then sends every turn to the one runtime in `channels`.
> Web owns the *request*; channels owns the *turn*. Nothing else.

This is the design for **C9** of `plans/clean-todo.md` (C6-C8 shipped: the proxy contract,
the tool layers, the persona loader all live in `channels` now). C9 was the one cycle left,
and a straight "gut" looked entangled. It isn't — once you see that the entanglement is only
*three threads*, and each one has a one-line home.

---

## The seam (why this looked hard)

`chat.ts` is 1,226 lines = **request-gates** + **the agent turn** + **~15 tools**. The tools
already moved to `channels` (C7); the turn already runs there (C6/C8). What *looked* fused to
the turn is three web-only concerns:

| Thread | Today (in the turn) | Why it's actually request-level |
|---|---|---|
| **prompt suffixes** | CRO variant, i18n locale, actor snapshot (ANALYTICS_HUB DO), link context, booking, skills-studio — appended to `system` | All are *context about this request*. Web already computes them; they're just **text**. |
| **billing debit** | `debitPool(computeBurn(result.usage))` post-stream | The *gate* (balance check) is request-level. The *debit* just needs a token count — which rides home on the stream. |
| **thread persistence** | `onFinish → appendMessage` to web's `threads` table | Web owns its inbox table. The assistant text rides home on the same stream. |

None of these belong *in the turn*. They belong to the **doorman** and the **wire**.

---

## The elegant move: one string, one tee

**1. Collapse every prompt suffix into ONE opaque field.**
Web already renders CRO/locale/snapshot/link/booking into strings. Concatenate them into a
single `systemSuffix` and put it in the body. `channels` appends it to the persona prompt
*exactly like it already appends `soul`* — it never learns what CRO or a DO snapshot is.

> Contract grows by **one field**. Channels stays dumb. Web keeps owning CRO/i18n/DO because
> it owns the *request* — it just stops owning the *prompt*.

**2. Bill + persist from ONE tee.**
The proxied response is an AI-SDK UIMessage SSE stream. Web `tee()`s it: one branch streams to
the browser untouched; the other is read to completion to pull the **finish event** (usage →
`debitPool`, assistant text → `appendMessage`). No usage trailer protocol, no channels billing
port — the number web needs is already in the stream it's forwarding.

```
browser ◀── tee[0] ── chat.ts ──fetch──▶ channels /message ──▶ turn
                        │
              tee[1] ──▶ read finish event ──▶ debitPool(usage) + appendMessage(text)
```

That's it. Two mechanisms — a string and a tee — absorb all three threads.

---

## The contract (C6 body + one field + a signed identity)

```ts
POST {CHANNELS_URL}/message
{
  slug, group, messages,        // who/where/what  (C5/C6)
  channel: 'web',               // picks the web tool layer  (C7)
  agentId, surface,             // location → persona/surface  (C6/C8)
  identity: string,             // SIGNED envelope (see below) → attested actorId → viewer  (C6 hardening)
  systemSuffix?: string         // NEW — web's rendered request-context, appended like soul
}
```

`channels` change is three lines: read `systemSuffix` from the body, append it after `soul`
in the persona prompt. No new concepts.

### Identity attestation (closes the C6 spoof hole)

**The hole:** C6 read `actorId` straight from the body and derived `owner` from `(actorId, slug)`.
Slugs are public (`one.ie/u/<slug>`), so an attacker could POST `{actorId: ownerSlug, slug: ownerSlug}`
and `resolveViewer` would hand back `owner=true` → workspace tools (patch_agent/theme, bookings,
delegate). **Capability derived from an unauthenticated field is no capability check at all.**

**The fix — web *proves* identity, channels *verifies* it (not just trusts it):**

```
web (ran the auth ceremony)                channels (has no session)
  actorId from verified session              verifyIdentity(token, slug, IDENTITY_SECRET)
  token = HMAC(IDENTITY_SECRET,                → valid sig + slug match + not expired
              `${actorId}.${slug}.${exp}`)       ? trust actorId → resolveViewer
  body.identity = `${actorId}.${exp}.${sig}`     : actorId untrusted → viewer=undefined (owner=false)
```

- **Shared secret** `IDENTITY_SECRET` (env on both workers; provisioned at C9 deploy).
- **Short-lived** `exp` (e.g. 60s) so a captured token can't be replayed for long.
- **Fail closed:** missing/invalid/expired token → `viewer=undefined` → `owner=false`. The owner
  tool layer (C7) is inert until a turn carries a valid attestation. Nothing else trusts `actorId`.
- `resolveViewer(env, actorId, slug)` stays pure — it only ever receives the **already-verified**
  actorId. The new seam is `verifyIdentity()` + the `/message` call site that runs it first.

This is the only thing that makes "identity in, capability derived" sound: the identity is *attested*,
not asserted. Web is the one layer that can mint it (it holds the session); channels is the one layer
that enforces it (it holds the secret + the ONE_DB membership truth).

---

## chat.ts after C9 (what stays / what leaves)

**STAYS — the doorman (request-level, ~90-120 lines):**
- auth / viewer resolution (`readCookieId`, `findAgent`)
- billing **gate** (`currentBalance` pre-check, anon rate-limit, `public_chat` gate)
- x402 receipt verify
- CRO variant pick + cookie header, locale detect, snapshot fetch, link context — **rendered into `systemSuffix`**
- the **tee**: `debitPool(usage)` + `appendMessage(text)` post-stream

**LEAVES — the turn (already in channels):**
- `buildSystem` / persona selection / `buildPersonaSystem`
- soul (`buildCompanyContextSuffix` — delete from web once no importer)
- every `tool(...)`, `streamText`, provider routing + Groq→Gemini fallback
- `makeAgent`, `convertToModelMessages`

**Outcome (unchanged kill-switch):**
```bash
! grep -qE 'streamText|tool\(|makeAgent|ToolLoopAgent' one.ie/web/src/pages/api/chat.ts \
  && grep -q CHANNELS_URL one.ie/web/src/pages/api/chat.ts
```
Passes *honestly* — no billing/persistence/CRO regression, because each thread has a home.

---

## Cycle plan (replaces clean-todo C9)

| Wave | Work |
|---|---|
| **W1** | Confirm the AI-SDK UIMessage SSE **finish-event shape** (where `usage` + final text sit) — the tee depends on it. Map the exact suffix-render call sites (970-1008) + billing (1059-1196) + persistence (1026-1050). Locate web's verified-session source for `actorId` (the value to sign). |
| **W2** | Decide: `systemSuffix` concatenation order (match current `baseSystem`); tee read strategy (`response.body.tee()` + a finish-event parser); confirm `buildCompanyContextSuffix` has no other web importer before delete. Pin the **identity envelope format** (`actorId.exp.HMAC`, 60s TTL, `IDENTITY_SECRET`). |
| **W3** | `channels`: append `systemSuffix` in `/message` (3 lines) + `verifyIdentity()` in `context.ts`; `/message` verifies the token → attested actorId → `resolveViewer` (raw body `actorId` removed). `chat.ts`: gate → mint signed `identity` → render suffix → build body → fetch → tee. `wrangler.toml`: add `CHANNELS_URL` (web) + `IDENTITY_SECRET` (both). Delete `buildCompanyContextSuffix`. Tests: `chat-proxy.test.ts` + `identity.test.ts` (valid→actorId, tampered/expired→null). |
| **W4** | `bun run verify` (web) green · outcome grep exits 0 · tee billing+persist asserted · **identity gate asserted** (spoofed actorId → owner=false) · **[DEFERRED — user]** deploy (set `IDENTITY_SECRET` on both) + live parity curl. |

**Security gate (hard):** C9 does not close until a `/message` request with an unsigned/forged
`actorId` resolves to `owner=false`. The spoof that the security review caught must be provably dead.

**Risk pinned:** the *only* real unknown is the finish-event shape (W1). Everything else is the
doorman keeping what it already does and forwarding the rest. If the SSE finish event doesn't
carry usage, fall back to a single `X-Usage-Tokens` response header set by `channels` — still
no billing logic in channels, just a number on the wire.

---

## Why this is the elegant version

- **One field, not five** — `systemSuffix` is opaque; channels never learns CRO/i18n/DO.
- **One tee, not a protocol** — the billing number is already in the stream web forwards.
- **Channels stays dumb** — three-line change; the turn doesn't grow a web-shaped appendage.
- **No feature drop** — CRO A/B, i18n, personalization, billing accuracy, inbox history all survive.
- **The doorman reads honestly** — gate, charge, forward, meter. Nothing pretends to be a runtime.

---

## See also

- `plans/clean-todo.md` — C6-C8 shipped; this doc is C9's design
- `plans/clean.md` — the one-runtime architecture
- `channels/src/index.ts` — `/message` (append `systemSuffix` after soul)
- `one.ie/web/src/pages/api/chat.ts` — the doorman (gut to gate+proxy+tee)
