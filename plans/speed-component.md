# speed-component.md — SpeedShowcase home section

## Purpose

Replace the plain `speed-receipt` layout in the home page `#speed` section with
a beautiful, animated showcase that makes ONE's performance numbers visceral.
The section already exists in `home-sections.ts`; this doc specifies the new
visual treatment.

## The claim, in one visual

ONE /chat fires the first token in **97ms**. ChatGPT takes ~1,400ms. Claude.ai
~1,200ms. asi1.ai ~1,100ms. The visual must make that gap feel real — not a
table cell, but a race.

## Numbers used (source)

| Surface | Value | Source | Verified |
|---------|-------|---------|---------|
| ONE TTFB p50 (browser) | 97ms | `plans/speed.md` | 2026-05-03 |
| ONE Lighthouse P/A/B/S | 100/91/100/100 | `plans/speed.md` | 2026-05-15 |
| ONE JS payload | 248 KB | home-sections.ts comparison | existing |
| Claude.ai TTFT p50 | ~1,200ms | home-sections.ts comparison | existing |
| Claude.ai Lighthouse Perf | 66 | home-sections.ts comparison | existing |
| Claude.ai JS payload | 4,900 KB | home-sections.ts comparison | existing |
| ChatGPT TTFT p50 | ~1,400ms | home-sections.ts comparison | existing |
| ChatGPT Lighthouse Perf | 51 | home-sections.ts comparison | existing |
| ChatGPT JS payload | 4,400 KB | home-sections.ts comparison | existing |
| asi1.ai TTFT p50 | ~1,100ms | **estimated** — needs measurement | — |
| asi1.ai Lighthouse Perf | ~62 | **estimated** — needs measurement | — |
| asi1.ai JS payload | ~3,100 KB | **estimated** — needs measurement | — |
| ONE deploy pipeline | 107s | `text/speed.md` | 2026-04-14 |

All "~" values are estimates. Do not remove the "~" prefix until measured in
production.

## Component: SpeedShowcase

**File:** `web/src/components/SpeedShowcase.tsx`

**Props:**
```tsx
interface Props {
  lighthouseDate: string
  lighthouseScores?: [number, number, number, number]  // perf, a11y, best, seo
  chatSeed?: string
  chatLabel?: string
}
```

Competitors are baked in — no prop needed. The numbers are sourced from this
doc and from the existing comparison table in `home-sections.ts`.

## Four visual panels

### Panel 1 — Lighthouse rings (top-left)

Four SVG animated circular progress rings, one per Lighthouse category.
Animate `stroke-dashoffset` from 0% filled → final score on first viewport
intersection. Each ring counts up from 0 using `requestAnimationFrame`.

```
  ⬤100  ⬤91  ⬤100  ⬤100
  Perf  A11y  Best   SEO
```

Ring colours (using design tokens):
- ≥90: `var(--color-tertiary)` (green feel)
- ≥70: `var(--color-secondary)`
- <70: `var(--color-primary)`

Ring track: `color-mix(in srgb, var(--color-font) 8%, transparent)`

### Panel 2 — TTFT race bars (top-right)

Horizontal bars, all animate from 0 to final width on intersection.
Bar width = `ms / maxMs * 100%` where maxMs = 1,400 (ChatGPT).

```
ONE /chat  █ 97ms   ⚡ 14× faster
asi1.ai    ████████████████████ ~1,100ms
Claude.ai  ██████████████████████ ~1,200ms
ChatGPT    ████████████████████████ ~1,400ms
```

- ONE bar: `background: var(--color-primary)` with a subtle glow via
  `box-shadow: 0 0 12px color-mix(in srgb, var(--color-primary) 40%, transparent)`
- Competitor bars: `color-mix(in srgb, var(--color-font) 18%, transparent)`
- ONE gets a `⚡ 14× faster` badge inline

Count-up: ONE's label counts from 0 to 97. Others count to their ~N value.

### Panel 3 — Live receipt (bottom-left)

Measures the actual current page load using `PerformanceNavigationTiming`
(falling back to `performance.timing`). Displays:

```
This page
  loaded in     1.03s
  chat TTFB     97ms  (static target, from spec)
  console errors  0
```

The "loaded in" number is real — measured in the visitor's browser.

### Panel 4 — Payload comparison (bottom-right)

```
Page weight
ONE /chat   █ 248 KB        18× lighter than ChatGPT
asi1.ai     ████████ ~3.1 MB
ChatGPT     ████████████████ 4.4 MB
Claude.ai   █████████████████ 4.9 MB
```

Bars animated same way as TTFT race.

## Animation contract

1. `useIntersectionObserver` — triggers on first viewport crossing, one-shot
   (disconnects after trigger)
2. Threshold: `0.25` — trigger when 25% visible
3. Ring `stroke-dashoffset` transition: `1.2s cubic-bezier(0.16, 1, 0.3, 1)`
   with per-ring delay: `i × 120ms`
4. Bar width transition: `1.3s cubic-bezier(0.16, 1, 0.3, 1)` with per-row
   delay: `i × 100ms`
5. Count-up via `requestAnimationFrame`, ease-out cubic, duration 1,000ms
6. `prefers-reduced-motion`: set all animated values to final state immediately,
   no transitions

## SectionBlock integration

In `SectionBlock.tsx`, replace the `speed-receipt` layout handler body:

```tsx
// Before: renders SpeedReceipt (plain receipt)
// After: renders SpeedShowcase (full animated showcase)
if (data.layout === 'speed-receipt' && data.speedReceipt) {
  return (
    <section className={baseCls}>
      <div className="max-w-6xl mx-auto">
        <SpeedShowcase
          lighthouseDate={data.speedReceipt.lighthouseDate}
          lighthouseScores={data.speedReceipt.lighthouseScores}
          chatSeed={data.chatSeed}
          chatLabel={data.chatLabel}
        />
      </div>
    </section>
  )
}
```

`Heading` and `CtaRow` are absorbed into `SpeedShowcase` for this layout —
the component owns its heading.

## home-sections.ts update

Add asi1.ai to the comparison table in the `speed` section:

```ts
comparison: {
  headers: ['Platform', 'TTFT p50', 'Lighthouse', 'JS payload'],
  rows: [
    ['ONE /chat',  '97ms',      '100', '248 KB'],
    ['asi1.ai',    '~1,100ms',  '~62', '~3.1 MB'],
    ['Claude.ai',  '~1,200ms',  '66',  '4.9 MB'],
    ['ChatGPT',    '~1,400ms',  '51',  '4.4 MB'],
  ],
},
```

## Design rules (invariants from `.claude/rules/design.md`)

- No hex colors — only the 6 tokens + CSS vars
- Borders via `var(--color-border)` or `style={{ borderColor: 'var(--color-border)' }}`
- Shadows via `var(--shadow-card)`
- `emitClick('ui:speed:…')` on all interactive elements
- Lucide icons only — `Zap` for speed badge, `Package` for payload
- Animations ≤1.4s; respect `prefers-reduced-motion`

## Files changed

| File | Change |
|------|--------|
| `web/src/components/SpeedShowcase.tsx` | **new** — animated showcase |
| `web/src/components/SectionBlock.tsx` | use `SpeedShowcase` in `speed-receipt` case |
| `web/src/lib/home-sections.ts` | add asi1.ai row to speed comparison |

`SpeedReceipt.tsx` stays unchanged — used by `/chat` page directly.

## Verify

```bash
cd one.ie/web && bun run build  # no type errors
```

Visual check: scroll to the speed section — all four panels animate in
correctly; rings fill; bars race; live receipt shows real page load time.

## See also

- `plans/speed.md` — authoritative speed numbers and methodology
- `text/speed.md` — marketing copy
- `web/src/components/SpeedReceipt.tsx` — existing simple receipt
- `web/src/components/SectionBlock.tsx` — section renderer
- `web/src/lib/home-sections.ts` — home section data
