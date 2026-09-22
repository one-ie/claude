---
paths:
  - "one.ie/web/**/*.tsx"
  - "one.ie/web/**/*.astro"
  - "one.ie/web/**/*.css"
---

# Design System Rules

Apply to `one.ie/web/**/*.tsx`, `one.ie/web/**/*.astro`, `one.ie/web/**/*.css`

The design system is **6 tokens**. Spec: [`design.md`](../../design.md). Showcase: `/design`.
The build itself enforces this — `--color-*: initial` in `Layout.astro` strips Tailwind's
default palette so wrong colors emit no CSS. Don't fight the enforcement.

---

## The 6 editable tokens (the only colors a user can pick)

| Token | Use for |
| --- | --- |
| `background` | Page canvas — the primary working surface, behind cards and sidebar |
| `foreground` | Cards, sidebar, elevated panels — surfaces that float above the canvas |
| `font` | All body text |
| `primary` | Main CTAs, brand accents, focus rings |
| `secondary` | Supporting actions, secondary buttons |
| `tertiary` | Highlights, success checks, accents |

## Plus 5 invariants (never editable)

`white` · `black` · `transparent` · `destructive` (errors/deletes) · `success` (confirms).

## Plus derived helpers (auto-computed — don't set directly)

Color: `on-primary` · `on-secondary` · `on-tertiary` (auto-contrast labels for brand fills) · `border` (= font @ 10%) · `border-strong` (= font @ 20%) · `muted` (= font @ 60%) · `faint` (= font @ 40%) · `ring` (= primary) · `page` (= background mixed with 4% font — L0 page shell).

Polish constants (baked, not exposed): `--radius-sm` 6px · `--radius-md` 10px · `--radius-lg` 16px · `--shadow-card` · `--shadow-pop` · `--ease` 120ms.

## Three depth levels

| Level | Surface | Where |
| --- | --- | --- |
| L0 page | `--color-page` | `<body>`, full-bleed shell — derived: background + 4% font |
| L1 canvas | `--color-background` | Main content area — the page canvas |
| L2 chrome | `--color-foreground` | Sidebar, cards, panels — float above the canvas |

In dark mode: background (10%) is deeper than foreground (13%) — chrome panels rise above the canvas. In light mode: background (93% gray) is muted, foreground (100% white) is bright — panels shine above the canvas.

Inputs sink back to `background` (the canvas level) when inside a `foreground` panel — they feel recessed into the panel surface.

There is no L3. A card header/footer shares the card surface; never tint them separately.

> **Pending code rename:** the component code currently applies `bg-background` to cards and `bg-foreground` to card interiors — inverse of this model. A mechanical rename (`bg-background` ↔ `bg-foreground` on card/sidebar elements) is tracked separately. When doing that cycle, grep `bg-background` on article/aside/nav elements and `bg-foreground` on inner content divs.

---

## Allowed utilities

```
bg-{background|foreground|primary|secondary|tertiary|destructive|success|white|black|transparent}
text-{font|primary|secondary|tertiary|on-primary|on-secondary|on-tertiary|destructive|success|white|black}
border-{font|primary|secondary|tertiary}
ring-{primary|secondary|tertiary}
```

**Use the auto-contrast `on-*` labels on brand fills** — they stay readable when the user picks any color:

```tsx
<button className="bg-primary text-on-primary">Primary</button>
<button className="bg-tertiary text-on-tertiary">Tertiary</button>
```

For muted text, borders, and focus rings, use alpha modifiers or `var()` — these are CSS-only helpers, not Tailwind utilities:

```tsx
text-font/60                                        // muted body text
text-font/40                                        // disabled / placeholder
border-font/10                                      // subtle borders
bg-primary/20                                       // tinted brand backgrounds
style={{ borderColor: 'var(--color-border)' }}      // when alpha modifier won't fit
```

The `--color-{border,muted,ring}` CSS vars exist (defined in `Layout.astro`) but are not Tailwind tokens — Tailwind v4 chokes on `var()` references inside `@theme`. Use them via `var()` only when needed.

---

## Banned

- ❌ Any Tailwind palette class: `bg-zinc-*`, `text-indigo-*`, `border-slate-*`, `text-emerald-*`, etc.
- ❌ Hex literals in JSX/CSS: `#fff`, `#0a0a0f`, `style={{ color: '#abc' }}`
- ❌ Raw `hsl(...)` / `rgb(...)` outside `Layout.astro` (token source) and `design.astro` (showcase)
- ❌ Adding a 7th token. Derive with alpha modifiers or `color-mix()`.
- ❌ Mixing icon sets. Lucide only — via `<Icon>` / `<IconBadge>` (in `web/src/components/ui/`).
- ❌ Inline SVG icons in React components. Import from `lucide-react` and wrap.
- ❌ Unicode icon glyphs (☀ ☾ ▾ ✓ ✗). They render differently across OSes — use lucide.
- ❌ `text-foreground` as a text color. `foreground` is the L2 panel *surface* token, not a contrast label — using it for text renders text the same color as its own background (invisible, and it flips wrong between light/dark). Use `text-font` for body text, `text-on-{primary|secondary|tertiary}` for text on a brand fill. **Exception:** the `bg-font text-foreground` Inverse button — surface-colored text on a font-colored fill is correct. Fine as-is (not policed here): `text-muted-foreground`/`text-card-foreground`/`text-popover-foreground`/`text-accent-foreground` (Layout.astro aliases them to `font`-derived colors) and shadcn's `text-{primary,secondary,destructive,sidebar}-foreground` contrast labels on brand fills (Button/Badge/Checkbox — they resolve via globals.css).

---

## Patterns

### Card (header · body · footer)

One shape, three slots. Header and footer share the card surface; only the body switches to `foreground`.

```tsx
<article
  className="bg-background border rounded-2xl flex flex-col"
  style={{ borderColor: 'var(--color-border)', boxShadow: 'var(--shadow-card)' }}
>
  <header className="flex items-start justify-between gap-4 px-5 pt-5">
    <div>
      <h3 className="text-base font-bold">Title</h3>
      <p className="text-font/60 text-sm">Meta</p>
    </div>
    <span className="px-2.5 py-1 rounded-full text-xs bg-foreground text-font/60 border" style={{ borderColor: 'var(--color-border)' }}>badge</span>
  </header>

  <div className="mx-5 mt-4 p-4 bg-foreground rounded-xl border" style={{ borderColor: 'var(--color-border)' }}>
    {/* L2 — data, inputs, charts */}
  </div>

  <footer
    className="flex items-center justify-between gap-3 px-5 py-4 mt-4 border-t"
    style={{ borderColor: 'var(--color-border)' }}
  >
    <span className="text-font/60 text-sm">Updated 2m ago</span>
    <div className="flex gap-2">
      <button className="px-4 py-2 rounded-lg text-font">Cancel</button>
      <button className="px-4 py-2 rounded-lg bg-primary text-on-primary">Save</button>
    </div>
  </footer>
</article>
```

### Icons

One source: `lucide-react`. Two wrappers in `web/src/components/ui/`:

```tsx
import { Send, Zap } from 'lucide-react'
import { Icon } from '@/components/ui/Icon'
import { IconBadge } from '@/components/ui/IconBadge'

// Inline — inherits parent color via currentColor
<Icon icon={Send} size="md" />

// Colored badge — feature grids, list rows, profile blocks
<IconBadge icon={Zap} tone="primary" size="md" />
```

`Icon` sizes: `sm` 14 · `md` 16 · `lg` 20 · `xl` 24. Stroke is locked to 1.5.
`IconBadge` tones: `primary` · `secondary` · `tertiary` · `neutral`. Surface is `color-mix(tone 14%, foreground)` — brighter than the card outer, tinted toward the tone color.

In Astro pages where you can't easily import React, use inline SVG with `viewBox="0 0 24 24"`, `stroke="currentColor"`, `stroke-width="1.5"`, `stroke-linecap="round"`, `stroke-linejoin="round"`. Copy paths from `lucide.dev`. Never use unicode glyphs.

### Form fields

Inputs use `background` (canvas level) inside a `foreground` panel — they appear recessed/sunken against the card surface. This is the correct spatial read: you're looking through the panel (foreground) into the canvas (background).

```tsx
<div className="flex flex-col gap-1.5">
  <label htmlFor="name" className="text-sm font-medium">Name</label>
  <input
    id="name"
    type="text"
    className="px-3.5 py-2.5 rounded-lg bg-background text-font border focus:outline-none"
    style={{ borderColor: 'var(--color-border)' }}
    placeholder="Ada Lovelace"
  />
  <span className="text-xs text-font/60">Shown on your public profile</span>
</div>
```

Focus uses `--color-ring` border + 3px `ring/25` glow. Error uses `aria-invalid='true'` → border `destructive`. Placeholder uses `--color-muted`. Checkbox/radio also use `bg-background` so they pop against the body.

### Buttons (6 variants)

```tsx
<button className="bg-primary text-white rounded-lg px-4 py-2 hover:brightness-110">Primary</button>
<button className="bg-secondary text-white rounded-lg px-4 py-2 hover:brightness-110">Secondary</button>
<button className="bg-tertiary text-white rounded-lg px-4 py-2 hover:brightness-110">Tertiary</button>
<button className="border border-primary text-font rounded-lg px-4 py-2">Outline</button>
<button className="text-font rounded-lg px-4 py-2">Ghost</button>
<button className="bg-font text-foreground rounded-lg px-4 py-2 hover:brightness-95">Inverse</button>
```

### Muted text

```tsx
<p className="text-font/60">Secondary copy</p>
<p className="text-font/40">Disabled / hint</p>
```

---

## Enforcement

Three layers, all automatic:

1. **Build-time kill** — `Layout.astro` declares `--color-*: initial` in `@theme`,
   wiping Tailwind's default palette. `bg-zinc-950` produces no CSS.
2. **PostToolUse hook** — `.claude/hooks/design-check.sh` greps every Write/Edit
   to `one.ie/web/**/*.{tsx,astro,css}` for banned patterns. Exit 2 on violation feeds
   the diff back to Claude as a tool error; the model self-corrects next turn.
3. **This rule** — auto-loaded on the same files via the `paths:` frontmatter at
   the top of this file (not `settings.json`, which wires hooks only), so the
   constraints are in context before the first character is written.

The hook allowlists `Layout.astro` (token source) and `design.astro` (showcase).

**Layers 2 and 3 are edit-triggered, so pre-existing violations survive.** The
hook is PostToolUse: it only sees a file when that file is written. Nothing
sweeps the tree, and layer 1 structurally cannot catch a hex string inside a JS
object — it nulls Tailwind palette *classes*, not literals. So a file untouched
since this rule landed can carry banned patterns indefinitely.
`src/components/paths/PathGraph.tsx` did: it carried hex literals at lines 27,
28, 29 and 55 until they were swept to `var(--color-{success,secondary,destructive})`.
Treat "the hook is green" as "nobody has edited the offender", not as "the tree
is clean".

---

## Don't

- Don't introduce a 7th token. Derive instead.
- Don't use `text-zinc-*` etc. — they emit no CSS, but stop the next reader from trusting the codebase.
- Don't write `style={{ color: '...' }}` — break the token enforcement.
- Don't use shadcn's `accent` name; it's `tertiary` here.
- Don't flip brand colors with mode — only surfaces flip.
- Don't add a 4th depth level. Page → card → content. A card header is not a 4th surface.
- Don't pick off-scale radii or spacing. Snap to `radius-sm/md/lg` (6/10/16) and 4/8/12/16/20/24/32.
- Don't animate longer than 200ms. Use `var(--ease)` (120ms) for color/border/filter.
- Don't tint a card's header or footer with a different background — they share the card surface.

---

*6 tokens. 3 depths. 1 card. 1 input. 6 button variants. The build refuses to compile anything else.*
