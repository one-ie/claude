---
title: Open Source Astro Template
slug: astro-template
type: plan
tier: simple
mode: construction
tags: [open-source, astro, template, stripe, better-auth, cloudflare]

parallel_budget:
  haiku:   4
  sonnet:  6
  opus:    0

batches:
  - [C1]
  - [C2]
  - [C3]

shared_recon:
  - one.ie/web/src/lib/auth.ts
  - one.ie/web/src/layouts/Layout.astro

source_of_truth:
  - one.ie/web/package.json
  - one.ie/web/src/styles/globals.css

existing_primitives:
  - one.ie/web/src/components/ui/: 29 shadcn components, grep-verified 0 ONE imports
  - one.ie/web/src/lib/billing.ts: D1-only, grep-verified 0 ONE imports
  - one.ie/web/src/pages/404.astro + 500.astro + design.astro + motion.astro: grep-verified 0 ONE imports
  - one.ie/web/src/pages/api/pay/: 2 files — create-intent.ts + webhook.ts

show: false
escape:
  condition: "C1 W4 STRIP LIST grep > 0 after extract.sh runs"
  action: "halt; grep -rn on ../one-template/src/ to find the hit; fix extract.sh before retrying"
---

# Open Source Astro Template

**Goal:** Ship `../one-template/` — Astro 6 + Tailwind 4 + shadcn + Stripe + better-auth + CF Workers — built from one.ie files, ONE-specific code stripped.

**Exit:** `cd ../one-template && bun install && bun run build && bun run typecheck` all exit 0; STRIP LIST grep returns 0 hits.

---

## Modes — standalone vs ONE BaaS

The template ships with an adapter in `src/lib/one.ts`. One env var gates which backend runs:

| `ONE_API_KEY` set? | Auth backend | Session read |
|---|---|---|
| No | Local better-auth + D1 | `localAuth.api.getSession(headers)` |
| Yes | ONE BaaS at `ONE_BASE_URL` | `fetch(ONE_BASE_URL/api/auth/me, { cookie })` |

Same UI components, same API route shape — the adapter swaps the backend. No code changes required by the developer.

Future BaaS surface additions (payments, signals, agents) follow the same pattern: check `one` adapter exists → delegate; else → local implementation.

---

## STRIP LIST — single invariant, runs at every W4 and plan close

`@oneie/sdk` imports are **intentional** — the BaaS adapter uses the SDK. Only strip internal substrate references:

```bash
grep -rn \
  "SubstrateClient\|substrate\|TypeDB\|suiWallet\|workspaceContext\|ChatHost\|ChatDock\|GATEWAY_API_KEY" \
  ../one-template/src/
```

Zero hits = clean. Any hit = cycle does not close.

---

## What copies vs what gets written fresh

**Copy verbatim** (grep-verified 0 ONE imports — bash cp, not agent):
- `src/components/ui/` — all 29 shadcn components
- `src/styles/globals.css`
- `src/pages/404.astro` + `500.astro` + `design.astro` + `motion.astro`
- `src/lib/billing.ts` (D1-only; update `./types` import → `./billing-types`)
- `src/components/motion/Reveal.astro` + `Stagger.astro`
- `src/pages/api/pay/create-intent.ts` + `webhook.ts` (1 ONE hit — sed strip)
- `src/pages/api/auth/[...all].ts` + `me.ts` + `sign-out.ts`
- `src/lib/d1-kysely-dialect.ts`
- `src/lib/passkey.ts` (verify grep first)

**Write fresh** (too entangled to strip safely):
- `src/layouts/Layout.astro` — workspace context woven in; rewrite as clean 3-slot layout
- `src/lib/auth.ts` — suiWallet deeply integrated; faster to rewrite than strip
- `src/pages/index.astro` — never ship ONE's homepage; write a clean hero shell
- `src/pages/signin.astro` + `signup.astro` — strip substrate session wiring
- `src/components/auth/SignInForm.tsx` + `PasskeyButton.tsx`
- Config files: `package.json`, `astro.config.ts`, `tsconfig.json`, `wrangler.toml`

**Exclude entirely** (ONE-specific, no public value):
- All chat components (`ChatDock`, `MessageList`, etc.)
- Signal / mark / warn / fade API routes
- CRM, funnel, journey, agents, analytics, dashboard
- Durable Objects, billing crons, PII vault, wallet auth

---

## Status

```
Batch 1
  - [ ] C1 — Scaffold + copy                       state: ready

Batch 2  (fires when C1 closes)
  - [ ] C2 — Fresh writes (layout, pages, auth)    state: blocked-on-C1

Batch 3  (fires when C2 closes)
  - [ ] C3 — README + plan close                   state: blocked-on-C2

Plan close
  - [ ] STRIP LIST → 0 hits
  - [ ] bun install && bun run build exits 0
  - [ ] bun run typecheck exits 0
```

---

## C1 — Scaffold + copy  [tier: simple · batch: 1]

**Exit:** `cd ../one-template && bun install` exits 0; `bash scripts/extract.sh` exits 0; STRIP LIST → 0.

**Demo gate:**
```bash
cd ../one-template && bun install && bash scripts/extract.sh && \
  grep -rn "SubstrateClient\|oneie\|TypeDB\|suiWallet\|workspaceContext" src/ | wc -l
# must print 0
```

### W3 — Edit  [Sonnet · parallel]

All config files are written fresh (no ONE config leaks into the template):

**W3a — config (independent):**
- [ ] `../one-template/package.json` — Astro 6, React 19, Tailwind 4, shadcn, better-auth, stripe, **@oneie/sdk**, zod, motion, lucide-react, clsx, tailwind-merge, nanoid, marked, Geist font, ai + @ai-sdk/react + @ai-sdk/openai-compatible; dev: wrangler, typescript, vite, vitest, @astrojs/check
- [ ] `../one-template/astro.config.ts` — CF adapter + react integration + tailwind vite plugin; output: server
- [ ] `../one-template/tsconfig.json` — strict; `@/` → `./src/`
- [ ] `../one-template/wrangler.toml` — bindings: `KV: CACHE`, `D1: DB`; no DO/R2/rate-limit/custom domain
- [ ] `../one-template/.env.example` — BETTER_AUTH_SECRET, STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, RESEND_FROM_EMAIL, OPENROUTER_API_KEY (optional); ONE_API_KEY (optional — set to enable ONE BaaS), ONE_BASE_URL (optional — defaults to https://one.ie)
- [ ] `../one-template/src/env.d.ts` — CF runtime types: KV CACHE, D1 DB, AI (optional)
- [ ] `../one-template/.gitignore` — standard astro + node + wrangler

**W3b — extract script (after config lands):**
- [ ] `../one-template/scripts/extract.sh` — executable; copies all verbatim-safe files from `../../one-ie/one.ie/web/src/` using the manifest below; runs `sed -i` for T2 strips; runs STRIP LIST grep at end; exits 1 on any hit

**Extract script manifest (exact source → dest):**
```bash
SRC=../../one-ie/one.ie/web/src
DEST=src

# ui components (29 files — T1)
cp -r $SRC/components/ui $DEST/components/

# styles (T1)
cp $SRC/styles/globals.css $DEST/styles/globals.css

# error pages (T1)
cp $SRC/pages/404.astro $DEST/pages/404.astro
cp $SRC/pages/500.astro $DEST/pages/500.astro

# showcase pages (T1 — 0 ONE imports, copy verbatim)
cp $SRC/pages/design.astro $DEST/pages/design.astro
cp $SRC/pages/motion.astro $DEST/pages/motion.astro

# motion generics (T1)
cp $SRC/components/motion/Reveal.astro $DEST/components/motion/Reveal.astro
cp $SRC/components/motion/Stagger.astro $DEST/components/motion/Stagger.astro

# billing (T1 — update import path after copy)
cp $SRC/lib/billing.ts $DEST/lib/billing.ts
sed -i '' "s|from './types'|from './billing-types'|g" $DEST/lib/billing.ts

# D1 dialect (T1 — verify grep first)
cp $SRC/lib/d1-kysely-dialect.ts $DEST/lib/d1-kysely-dialect.ts

# pay routes (T2 — 1 ONE hit; sed strips it)
mkdir -p $DEST/pages/api/pay
cp $SRC/pages/api/pay/create-intent.ts $DEST/pages/api/pay/create-intent.ts
cp $SRC/pages/api/pay/webhook.ts $DEST/pages/api/pay/webhook.ts
sed -i '' '/oneie\|substrate\|SubstrateClient\|TypeDB/d' $DEST/pages/api/pay/create-intent.ts
sed -i '' '/oneie\|substrate\|SubstrateClient\|TypeDB/d' $DEST/pages/api/pay/webhook.ts

# auth routes (T1 — catch-all + session endpoints)
mkdir -p $DEST/pages/api/auth
cp "$SRC/pages/api/auth/[...all].ts" "$DEST/pages/api/auth/[...all].ts"
cp $SRC/pages/api/auth/me.ts $DEST/pages/api/auth/me.ts
cp $SRC/pages/api/auth/sign-out.ts $DEST/pages/api/auth/sign-out.ts

# utils
mkdir -p $DEST/lib
cat > $DEST/lib/utils.ts << 'EOF'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)) }
EOF

# billing types (extracted from one.ie types — Grant, Burn, BillingConfig only)
# W3 agent writes this file

# STRIP LIST
grep -rn \
  "SubstrateClient\|@oneie/sdk\|oneie\|substrate\|TypeDB\|suiWallet\|workspaceContext\|ChatHost\|ChatDock\|GATEWAY_API_KEY" \
  $DEST/ && exit 1 || echo "STRIP LIST clean"
```

### W4 — Verify  [inline]

- [ ] `bun install` exits 0
- [ ] `bash scripts/extract.sh` exits 0 (STRIP LIST clean)
- [ ] `ls src/components/ui/ | wc -l` = 29
- [ ] `ls src/pages/ | grep -E 'design|motion'` = 2 files present
- [ ] STRIP LIST grep on `src/` → 0

---

## C2 — Fresh writes  [tier: simple · batch: 2]

**Exit:** `bun run build` exits 0; `bun run typecheck` exits 0; STRIP LIST → 0.

**Demo gate:**
```bash
cd ../one-template && bun run build && bun run typecheck && \
  grep -c "createOneAdapter" src/lib/one.ts && \
  grep -c "getSession" src/lib/auth.ts && \
  grep -rn "SubstrateClient\|TypeDB\|suiWallet\|workspaceContext\|ChatHost" src/ | wc -l
# build exits 0; one.ts exports adapter; auth.ts exports getSession; STRIP LIST prints 0
```

### W3 — Edit  [Sonnet · parallel]

These files are written fresh — the agent writes from the spec below, not from one.ie source.

**W3a — independent:**

- [ ] `../one-template/src/layouts/Layout.astro`
  - Props: `title: string`, `description?: string`
  - Slots: default, `nav` (optional), `footer` (optional)
  - Includes: Geist font, globals.css, basic meta + OG tags, theme-color
  - Excludes: Sidebar, ChatHost, workspaceContext, analytics pixel
  - Target: ≤60 LOC

- [ ] `../one-template/src/pages/index.astro`
  - Sections: hero (H1 + subtitle + two Buttons), 3-up feature grid (Icon + title + description), CTA strip, footer
  - Placeholder copy — no ONE branding
  - Uses: Layout, Button, Icon from ui/
  - Target: ≤80 LOC

- [ ] `../one-template/src/pages/pricing.astro`
  - Sections: hero headline, 3 plan cards (free/pro/enterprise, placeholder prices), FAQ accordion
  - Uses: Layout, Card, Button, Badge from ui/
  - Target: ≤60 LOC

- [ ] `../one-template/src/pages/signin.astro` + `../one-template/src/pages/signup.astro`
  - Email input + submit + PasskeyButton
  - Calls `/api/auth/*` — no substrate session write
  - Target: ≤50 LOC each

- [ ] `../one-template/src/lib/one.ts`
  - Reads `ONE_API_KEY` + `ONE_BASE_URL` from env
  - Exports: `createOneAdapter(env)` → `{ auth: SdkAuthClient } | null` (null = standalone mode)
  - `auth` is `createSdkAuthClient({ baseURL: ONE_BASE_URL ?? 'https://one.ie' })` from `@oneie/sdk`
  - Target: ≤20 LOC

- [ ] `../one-template/src/lib/auth.ts`
  - **Standalone path** (no ONE_API_KEY): better-auth with `emailAndPassword()` + `passkey()`, `kyselyAdapter` + `LazyD1Dialect`, Resend email callback
  - **BaaS path** (ONE_API_KEY set): `getSession` proxies to `{ONE_BASE_URL}/api/auth/me` with request cookies; returns session or null; local better-auth instance not created
  - Exports: `createAuth(env)` (standalone only), `authHandler` (standalone only), `getSession(request, env): Promise<Session | null>` (both modes — adapter picks path)
  - No suiWallet, no substrate, no TypeDB
  - Target: ≤90 LOC

- [ ] `../one-template/src/lib/billing-types.ts`
  - Types: `Grant`, `Burn`, `BillingConfig` — extracted from one.ie types, no substrate deps

- [ ] `../one-template/src/lib/stripe.ts`
  - Exports: `createPaymentIntent(amount, currency, metadata)`, `verifyWebhook(payload, sig, secret)`
  - Thin wrappers over the Stripe SDK
  - Target: ≤40 LOC

- [ ] `../one-template/src/components/auth/SignInForm.tsx` + `PasskeyButton.tsx`
  - SignInForm: email + password fields + passkey option; calls better-auth client
  - PasskeyButton: single button that triggers WebAuthn flow
  - Target: ≤60 LOC each

- [ ] `../one-template/src/middleware.ts`
  - Read session cookie via `getSession(request, env)` → attach to `Astro.locals.session`
  - No workspace resolution
  - Target: ≤20 LOC

- [ ] `../one-template/migrations/0001_auth.sql`
  - Standard better-auth D1 tables: users, sessions, accounts, verifications

**W3b — dependent (none):**

### W4 — Verify  [inline]

- [ ] `bun run build` exits 0
- [ ] `bun run typecheck` exits 0, delta_tsc = 0
- [ ] STRIP LIST grep → 0 hits
- [ ] `wc -l src/layouts/Layout.astro` ≤ 70
- [ ] `grep -c "passkey\|emailAndPassword" src/lib/auth.ts` ≥ 2
- [ ] Rubric composite ≥ 0.65

---

## C3 — README + plan close  [tier: trivial · batch: 3]

**Exit:** README ≤ 500 words; LICENSE MIT; `bun run build` exits 0 one final time.

**Demo gate:**
```bash
cd ../one-template && bun run build && cat LICENSE | grep -i MIT && wc -w README.md
```

### W3 — Edit  [Sonnet]

- [ ] `../one-template/README.md`
  - One-liner, what's included table, 5-step quick start (`bunx degit one-ie/one-template my-app`)
  - **Two-mode section** (standalone vs ONE BaaS):
    - Standalone: fill BETTER_AUTH_SECRET + DB binding → `bun dev`
    - ONE BaaS: set ONE_API_KEY + ONE_BASE_URL → auth delegates to ONE; D1 not required for auth
  - Deploy section (`bun run build && wrangler deploy`)
  - Link to one.ie/developers for API key
  - MIT license line
  - ≤500 words

- [ ] `../one-template/LICENSE` — MIT

### W4 — Verify  [inline]

- [ ] `bun run build` exits 0
- [ ] `bun run typecheck` exits 0
- [ ] STRIP LIST grep across ALL `src/` → 0 hits (final gate)
- [ ] `wc -w README.md` ≤ 500
- [ ] LICENSE contains MIT

---

## Plan close

- [ ] STRIP LIST → 0 hits across `../one-template/src/`
- [ ] `cd ../one-template && bun install && bun run build && bun run typecheck` all exit 0
- [ ] README ≤ 500 words; LICENSE MIT
- [ ] Rubric ≥ 0.65 across all cycles
