# 01-brand — gap analysis

## Promise (from text/01-brand.md)

- 60-second brand flow at `yourslug.one.ie/settings/brand` — 11 interactions, ~55-65s editor time.
- 6 editable colour tokens, 5 invariants, 3 depth levels — system refuses unreadable combos.
- WCAG AA contrast (4.5:1) enforced at save; save button disabled until passing.
- Logo upload (SVG/PNG ≤2MB) with auto-derived favicon (32×32 top-left crop), overridable.
- Custom domain: 1 CNAME + 1 TXT, multi-edge verification (3-of-5 Cloudflare), 90-day re-verification.
- `resolveConfig()` maps host → workspaceSlug → TypeDB Group in <10ms with 60s KV cache.
- White-label cascade: owner → agency → client → end_user with `-locked` suffix per property; `merge()` enforces locks downward.
- Four embed modes: script tag served from agency domain (`acme.com/embed.js`), iframe with signed URL, MCP server with branded metadata, A2A endpoint.
- Branded surfaces map: chat UI, invoice, OAuth consent screen, transactional email (from address + footer), status page, 404/error, favicon.
- Voice contract running pre-send, 0.65 quality gate, human review queue.
- Custom CSS field accepting up to 1000 chars for typography overrides; system font stack default.
- Dark mode auto-flip of `on-*` labels (#fff → #000 at L≥60) so the system cannot produce inaccessible dark variants.

## Code reality

**Token editor — partial.** `web/src/components/settings/SettingsView.tsx:86-199` renders a 6-colour grid with live `document.documentElement.style.setProperty` preview and the on-primary/secondary/tertiary L-flip (`hexToL` at :79). Logo upload field exists (:138-160). Site name field exists (:117-135). No tagline, no font picker, no favicon upload, no custom CSS, no contrast meter, no save-disable on AA failure — `/api/branding` regex (`web/src/pages/api/branding.ts:7`) just accepts any `#…` or `hsl(…)` value.

**Settings route.** Lives at `/u/[slug]/settings#branding`, not `/settings/brand` as the doc promises. `web/src/pages/u/[slug]/settings.astro:1-46` → `SettingsView` with `viewer` from middleware. End-users get redirected to `/chat`.

**Branding API.** `web/src/pages/api/branding.ts` accepts: `slug`, `name`, `logo`, and the 6 colour keys. Writes to R2 `${slug}/site.md` frontmatter and `${slug}/logo`. No favicon, no font, no tagline, no `-locked` field, no contrast validation.

**Domain flow.** `web/src/components/settings/DomainSettings.tsx` + `web/src/pages/api/domain.ts`. Two-step register → verify against `_one-verify.<host>` TXT via single Cloudflare DoH query (`web/src/pages/api/domain.ts:56-67`) — not the promised 3-of-5 multi-edge check. No re-verification cron. CNAME target is `{parentSlug}.one.ie` or `one.ie`. Agency subdomain provisioner exists (DomainSettings.tsx:46-72 → `/api/domain?action=provision-subdomain`). Alternative verifier at `web/src/pages/api/domains/[domain]/verify.ts` uses Google DoH — duplicate of `/api/domain` logic.

**Host → workspace resolution.** `web/src/middleware.ts:157-178` does the D1 `SELECT slug, parent_slug FROM domains WHERE host = ? AND verified = 1` lookup and `ctx.rewrite('/u/<slug>...')`. No KV cache on this lookup — every request hits D1. Promise of "<10ms on 60s KV cache" not delivered for custom domains (only `mergeBilling` is KV-cached at :40-61).

**Cascade.** `web/src/lib/site.ts:88-106` implements `merge(parent, child)` honouring `-locked`. `web/src/lib/config.ts:52-88` implements `resolveConfig()` with the L1/L2/L3/L4 chain described in the doc. **Neither is called from anywhere in the codebase** — `grep resolveConfig` returns only the definition. Pages read raw `${slug}/site.md` directly (`web/src/pages/u/[slug]/settings.astro:18`, `web/src/pages/api/logo/[slug].ts:37`, `web/src/pages/api/onboarding.ts:60`, `.well-known/group-card.json.ts:12`). Parent locks have zero runtime effect.

**Attribution toggles.** `BrandingSettings.tsx` only ships the "Powered by ONE / Powered by {agency}" switches — paywalled at Pro. That is the entirety of the "Branding" panel today; the colour/logo editor is a separate `BrandingSection` rendered side-by-side at `SettingsView.tsx:280-291`.

**Logo / favicon serving.** `web/src/pages/api/logo/[slug].ts` serves the uploaded R2 logo OR auto-generates an SVG placeholder with initials over the workspace primary. No favicon endpoint — `Layout.astro:63` accepts a `favicon` prop only for studio pages, falling back to the platform `/favicon.svg`. Custom-domain visitors see one.ie's favicon.

**Embed.** `find -name embed.*` returns zero. `/embed.js` does not exist. The only embed surface is `?embed=widget` query param on `/studio/[agent]` (`web/src/pages/studio/[agent].astro:77-81`) which strips chrome. No iframe-signed-URL flow, no MCP server with branded metadata, no documented A2A endpoint.

**OAuth consent / email / status / 404.** No agency-branded OAuth consent screen — auth is passkey-only (`web/src/lib/passkey.ts`). No transactional email sender configuration. No `status.yourdomain.com` route. `web/src/pages/404.astro` and `500.astro` exist but inherit the token cascade only through `Layout.astro` — no per-workspace branding when hit outside a workspace context.

**Voice contract / quality gate.** Not implemented in the brand path. `web/src/pages/api/chat.ts` streams via AI SDK with no pre-send 0.65 rubric or human review queue cited in the doc.

**Dark mode `on-*` flip.** `Layout.astro` ships the dark defaults per `.claude/rules/astro.md`, and `SettingsView.tsx:95-100` flips `on-*` live in the editor. The platform path is wired; cascaded user values do flip correctly.

## Gaps

1. `resolveConfig()` + `merge()` exist but are never invoked → **the entire white-label cascade is dead code.** Parent agency locks (`primary-locked`, `logo-locked`, etc.) have no enforcement. Every workspace reads only its own `site.md`.
2. No WCAG AA gate at save time. Editor previews colours; API stores anything matching `#hex` or `hsl(`. The product's strongest accessibility claim is unenforced.
3. Domain verification is single-edge (1 DoH lookup) and missing the promised 90-day re-verification. No KV cache on host→slug lookup → every custom-domain request is a D1 read.
4. No `/embed.js`, no iframe signed-URL flow, no MCP per-workspace endpoint, no A2A endpoint. The "embed anywhere" surface is a doc-only feature.
5. No favicon upload, no per-workspace favicon served on custom domains, no tagline editor, no font selector (despite `FONT_ALLOWLIST` in `site.ts:1`), no custom CSS field.
6. No `-locked` UI — even when cascade gets wired, agencies can't set locks except by hand-editing `site.md` in R2.
7. Route mismatch — doc promises `/settings/brand`, code lives at `/u/[slug]/settings#branding`.
8. No agency-branded OAuth consent screen, no branded transactional email config, no `status.<domain>` route, no per-workspace 404 outside the rewrite.
9. Voice contract + 0.65 quality gate cited in the brand doc as part of the brand-safety story has no implementation in the brand or chat path.
10. Two parallel domain verifiers (`/api/domain` and `/api/domains/[domain]/verify`) — duplicated logic, drift risk.

## Recommended improvements

1. **Wire `resolveConfig()` into the request path.** `middleware.ts` should call it when a custom domain or subdomain resolves and attach `WorkspaceConfig` to `ctx.locals`. Replace the direct `parseSite(siteObj.text())` reads in `settings.astro`, `logo/[slug].ts`, `group-card.json.ts`, `robots.txt.ts` with that single resolved config. Cache the resolved result in KV keyed `site:<slug>` with 60s TTL.
2. **Cache host→slug in KV** (`domain:<host>` → `{slug, parent_slug}`, 60s TTL, invalidate on verify) — the promised <10ms middleware.
3. **Enforce WCAG AA at save.** Compute foreground/background contrast pairs (font over background, on-primary over primary, etc.) in `/api/branding`; reject `4xx` on failure. Mirror live in `SettingsView.tsx`'s editor — disable the submit button and show the failing ratio.
4. **Surface the locking grammar in UI.** Add a lock toggle next to each token + logo + favicon + name + tagline. Agency tier can set, client tier sees disabled inputs for locked properties.
5. **Add favicon upload + per-workspace favicon endpoint** (`/api/favicon/[slug]`) and wire `Layout.astro` to use it when `profileSlug` is set. Auto-derive from logo's top-left 32×32 if not explicitly set.
6. **Add tagline field, font selector (already allowlisted), custom CSS textarea (1000 char cap, sanitised).**
7. **Build the embed surface.** Ship `web/src/pages/embed.js.ts` that serves a tokenised widget loader, reads `data-workspace`, fetches resolved tokens, mounts a chat island. Add `/embed/iframe?slug=...&token=...` with HMAC-signed short-lived tokens.
8. **Multi-edge DNS verification** — fan out 3-5 DoH providers (Cloudflare, Google, Quad9, NextDNS) in `Promise.all`, accept on majority. Add a cron-scheduled Worker reading `domains WHERE verified=1 AND last_checked_at < now()-90d`, re-resolving the TXT, flagging silently on fail.
9. **Consolidate the two domain verifiers** — delete `web/src/pages/api/domains/[domain]/verify.ts` or fold its DoH provider variety into `/api/domain`.
10. **Move settings route** to `/settings/brand` (or alias) to match the doc's URL. Or update `text/01-brand.md` to cite `/u/[slug]/settings#branding`.
11. **Brand the auxiliary surfaces** — pass workspace tokens to 404/500 layouts when middleware has resolved a workspace; provide a workspace-aware OAuth consent screen if/when OAuth ships; document email sender config (SPF/DKIM rows to add).
12. **Either wire the voice contract + 0.65 gate** or remove the brand-safety claims from `text/01-brand.md`. Today the page asserts mechanics that don't run.

## Files to touch

- `/Users/toc/Server/one-ie/one/web/src/middleware.ts` — call `resolveConfig`, attach to `ctx.locals`, cache host→slug in KV.
- `/Users/toc/Server/one-ie/one/web/src/lib/config.ts` — already implemented, needs callers; add KV memoisation.
- `/Users/toc/Server/one-ie/one/web/src/lib/site.ts` — extend `parseSite`/`updateSiteTokens` to handle `favicon`, `tagline`, `font`, `custom-css`, `*-locked` writes.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/branding.ts` — add WCAG validation, favicon/tagline/font/custom-css/lock fields.
- `/Users/toc/Server/one-ie/one/web/src/components/settings/SettingsView.tsx` — disable submit on AA failure, add lock toggles + missing fields, show contrast ratio per pair.
- `/Users/toc/Server/one-ie/one/web/src/components/settings/BrandingSettings.tsx` — merge into the colour editor or rename to `AttributionSettings`.
- `/Users/toc/Server/one-ie/one/web/src/components/settings/DomainSettings.tsx` — surface re-verification status.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/domain.ts` — multi-edge DoH check; add re-verify endpoint or scheduled handler.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/domains/[domain]/verify.ts` — delete or merge into `/api/domain`.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/favicon/[slug].ts` — new endpoint, auto-derive from logo if absent.
- `/Users/toc/Server/one-ie/one/web/src/layouts/Layout.astro` — use per-workspace favicon when `profileSlug` set.
- `/Users/toc/Server/one-ie/one/web/src/pages/embed.js.ts` — new widget loader endpoint.
- `/Users/toc/Server/one-ie/one/web/src/pages/embed/iframe.astro` — new signed-URL iframe target.
- `/Users/toc/Server/one-ie/one/web/src/pages/404.astro` and `500.astro` — read workspace tokens from `ctx.locals.workspaceConfig`.
- `/Users/toc/Server/one-ie/one/web/src/workers/` — new scheduled handler for 90-day re-verification.
- `/Users/toc/Server/one-ie/one/text/01-brand.md` — drop or qualify the unimplemented claims (voice contract, 3-of-5 verification, multi-mode embeds, `/settings/brand` URL) OR keep them as the spec and treat the above gaps as the build queue.
