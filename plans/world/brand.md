# brand.md — ONE brand assets

**Owner:** `one-ie/one/web/` · **Classifier:** mode: mixed · lifecycle: construction

> Source of truth for brand assets is `one.ie/public/`. Mirror into `one-ie/one/web/public/` for the opensource web app.

---

## Current state

| Asset | Path | Status |
|-------|------|--------|
| Icon mark (SVG) | `web/public/favicon.svg` | ✅ copied from `one.ie` |
| Icon mark (SVG) | `web/public/icon.svg` | ✅ copied from `one.ie` (identical to favicon) |
| Icon white | `web/public/icon-white.svg` | ✅ created |
| Icon dark | `web/public/icon-dark.svg` | ✅ created |
| Icon color | `web/public/icon-color.svg` | ✅ created (`currentColor`) |
| Wordmark white | `web/public/logo.svg` | ✅ created |
| Wordmark dark | `web/public/logo-dark.svg` | ✅ created |
| PWA icon 192 | `web/public/icon-192.png` | ✅ copied from `one.ie` |
| PWA icon 512 | `web/public/icon-512.png` | ✅ copied from `one.ie` |
| PWA icon maskable | `web/public/icon-maskable.png` | ✅ copied from `one.ie` |
| Apple touch icon | `web/public/apple-touch-icon.png` | ✅ copied from `one.ie` |
| OG image | `web/public/og-image.jpg` | ✅ copied from `one.ie` — 1200×630, 729KB |
| Logo PNG (structured data) | `web/public/logo.png` | ❌ missing — needs PNG render |
| Per-route OG images | — | ❌ missing — single static image for all routes |

---

## The mark

The ONE mark is a stylised **O** with internal pheromone-trail texture — concentric path lines that read as signal density at small sizes and organism at large sizes. White fill, transparent background. Source lives in `one.ie/public/favicon.svg`.

The path is complex (intentional — the texture is the brand). Do not simplify it.

---

## Asset spec

### 1. Icon mark variants

Three colour treatments, one shape:

| Variant | Fill | Background | Use |
|---------|------|------------|-----|
| `icon-white.svg` | `white` | transparent | Dark surfaces (current default) |
| `icon-dark.svg` | `#0a0a0f` | transparent | Light surfaces |
| `icon-color.svg` | `var(--color-primary)` | transparent | Brand accent contexts |

Source: copy path from `favicon.svg`, swap fill only. No other changes.

### 2. Wordmark

`logo.svg` — icon mark + "ONE" logotype, horizontal layout.

Spec:
- Canvas: `200×45` viewBox
- Mark: current 45×45 path at `x=0`
- Text: "ONE" · tracking +0.08em · weight 600 · fill same as mark
- Spacing: 12px gap between mark and text
- Variants: white (dark bg), dark (light bg) — same two-file pattern as icon

Usage: Sidebar top (`one.ie/src/components/Sidebar.tsx`), nav headers, email footers.

### 3. Logo PNG (structured data)

`one.ie/public/logo.png` — 512×512, white mark on `#0a0a0f` background.

Fixes: `one.ie/src/layouts/Layout.astro:124` currently points to `https://one-substrate.pages.dev/logo.png` (CDN). Replace with `/logo.png` local asset.

### 4. OG images

#### Static default
`one.ie/public/og-image.jpg` — 1200×630.

Current file exists but was generated without review. Needs a deliberate composition:
- Background: `#0a0a0f`
- Left: wordmark at ~80px, white
- Right or centre: one-line tagline — "A world where agents work for you"
- Bottom right: `one.ie` in muted text

#### Per-route variants
Generate at build time via `satori` + `resvg-js` (CF Workers compatible, no puppeteer):

| Route | Differentiator |
|-------|----------------|
| `/` | Default — tagline |
| `/u/[handle]` | Agent name + avatar placeholder |
| `/chat` | "Talk to agents. Pay with crypto." |
| `/buy` | "Buy anything in 3s." |
| `/sell` | "Accept crypto in 60s." |
| `/wallet` | "Your keys. Your wallet." |

Implementation target: `one.ie/src/pages/api/og/[...route].ts` — returns `image/png`.
Layout: Astro `<meta og:image>` passes route-aware URL.

### 5. PWA icon source

All PNG icons (`icon-192`, `icon-512`, `icon-maskable`, `apple-touch-icon`) should be regenerated from the SVG source when the mark changes. Use `sharp` or `resvg-js` in a build script.

Maskable safe zone: mark centred in 60% of canvas (72px padding on 192px, 192px padding on 512px).

---

## File destinations

```
one.ie/public/
├── favicon.svg          ← exists (icon mark, white)
├── icon.svg             ← alias of favicon.svg — consolidate or remove
├── icon-white.svg       ← new
├── icon-dark.svg        ← new
├── icon-color.svg       ← new
├── logo.svg             ← new (wordmark, white)
├── logo-dark.svg        ← new (wordmark, dark)
├── logo.png             ← new (512×512, for JSON-LD)
├── og-image.jpg         ← replace
├── icon-192.png         ← regenerate from SVG
├── icon-512.png         ← regenerate from SVG
├── icon-maskable.png    ← regenerate from SVG
└── apple-touch-icon.png ← regenerate from SVG
```

---

## Wiring changes

| File | Change |
|------|--------|
| `one.ie/src/layouts/Layout.astro:124` | `"logo"` → `"/logo.png"` (local) |
| `one.ie/src/layouts/Layout.astro` | Add per-route `og:image` logic using `/api/og/` |
| `one.ie/src/components/Sidebar.tsx` | Import and render `logo.svg` (or inline) |
| `one.ie/public/manifest.json` | No change needed — already references correct PNG paths |

---

## Design tokens used

Logo and OG images are hardcoded to the product's base palette — they are not themeable by brand tokens:

| Slot | Value |
|------|-------|
| Page background | `#0a0a0f` |
| Text / mark (light) | `white` |
| Text / mark (dark) | `#0a0a0f` |
| Accent | `var(--color-primary)` default `#6366f1` |

OG images bake these values at generation time.

---

## Build plan

### lean cycle A — static assets (no new tooling)

**Goal:** wordmark SVG + icon variants + logo.png + Layout.astro wiring fix.
**Speed:** 1 wave, 4 tasks.
**Tasks:**
1. Create `icon-white.svg`, `icon-dark.svg`, `icon-color.svg` from existing path
2. Create `logo.svg` + `logo-dark.svg` (wordmark, SVG text node)
3. Export `logo.png` 512×512 (can be done with `resvg-js` or Inkscape CLI)
4. Patch `Layout.astro:124` — `logo` URL → `/logo.png`

**Verify:** `logo.png` exists + ≥400×400 · Layout.astro no longer references CDN · SVGs open cleanly.
**Close:** pheromone `mode:lean lifecycle:construction`.

### lean cycle B — OG images (satori)

**Goal:** replace static `og-image.jpg` + add per-route `/api/og/` endpoint.
**Speed:** 1 wave, 3 tasks.
**Tasks:**
1. Add `satori` + `resvg-js` to `one.ie/` deps
2. Create `one.ie/src/pages/api/og/[...route].ts` — renders branded card, returns PNG
3. Update `Layout.astro` to pass route-aware `og:image` URL

**Verify:** `/api/og/` returns 200 image/png · `og:image` tag contains correct URL per route.
**Close:** pheromone `mode:lean lifecycle:construction`.

### lean cycle C — PWA icons (optional, low priority)

**Goal:** regenerate all PNG icons from SVG source for pixel-perfect output.
**Speed:** 1 wave, 1 task.
**Tasks:**
1. Write `scripts/gen-icons.ts` using `resvg-js` — outputs all 4 PNGs at correct sizes/safe-zones

**Verify:** PNG dimensions match manifest declarations · maskable icon passes safe-zone check.

---

## Threat model

| What | Defended by |
|------|-------------|
| Brand spoofing (fake one.ie pages) | Wordmark + mark are simple — not DRM. Accept it. |
| Broken OG previews on link share | Per-route OG endpoint + fallback to static JPEG |
| CDN dependency for structured data logo | Cycle A task 4 removes it |
| Icon quality regression | Source SVG preserved; PNGs are derived artifacts |

---

*Mark exists. Wordmark is the gap. OG and icons follow.*
