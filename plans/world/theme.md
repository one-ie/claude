# theme.md — one theme, every component, every page

**Principle:** six tokens. Two modes. One formula for cards. One formula for buttons. Everything else is derived. Hardcoded colors are bugs.

```
mode: lean
lifecycle: construction
priors:
  spec-locked: y     # 6 tokens already live in one.ie/src/styles/derive.ts
  variance-known: y  # one shape: HSL triple → CSS var → Tailwind class
  exit-scalar: y     # `bun run verify` + grep returns 0 hardcoded colors in components
  files-known: y     # global.css, derive.ts, components/ui/*, tailwind.config (none — @theme inline)
owner: tony
```

---

## The 6 tokens (locked)

Source of truth: [`one.ie/src/styles/derive.ts:14`](one.ie/src/styles/derive.ts) (`defaultBrand`).
Mirror: [`one.ie/src/styles/global.css:179`](one.ie/src/styles/global.css) (`@theme` block) and [`:343`](one.ie/src/styles/global.css) (`.dark` block).

| Token | Light | Dark | Owns |
| --- | --- | --- | --- |
| `--color-background` | `0 0% 93%`* | `0 0% 10%` | Page · sidebar · card surface |
| `--color-foreground` | `0 0% 100%` | `0 0% 13%` | Inner content area inside card |
| `--color-font` | `0 0% 13%` | `0 0% 100%` | Text — inverts for legibility |
| `--color-primary` | `216 55% 25%` | `216 55% 25%` | Main CTA · ring |
| `--color-secondary` | `219 14% 28%` | `219 14% 32%` | Supporting actions |
| `--color-tertiary` | `105 22% 25%` | `105 22% 35%` | Accent · success-tinted actions |

*Current `global.css` ships `--color-background: 0 0% 100%` in light. Spec says `0 0% 93%` so card and page differ. **Reconcile in W3** — `derive.ts:15` already says `0 0% 100%`, so update both to match the user's chosen `0 0% 93%` light / `0 0% 10%` dark, and let card pull `--color-foreground` (`100%`) for the inner content area.

**Everything else is derived** by `deriveShadcn(brand, mode)` in [`derive.ts:27`](one.ie/src/styles/derive.ts) — `card`, `popover`, `muted`, `accent`, `ring`, `chart-*`, `sidebar-*`, `border`, `input`. Do not author these by hand.

---

## Brand families as 3-step ladders (the `security.astro` pattern)

The 6 base tokens describe page chrome. They fail when you need three brand families to **cycle through semantic categories** on a dark surface — legal/governance/compliance, autonomous/approval/hard-stop, primary CTA / supporting / accent. The canonical `--color-primary: 216 55% 25%` is too dark to render as a stroke or accent on a `0 0% 10%` background.

[`one.ie/src/pages/security.astro:11-28`](one.ie/src/pages/security.astro) solves this elegantly with a 3-step luminance ladder per family — `bright` (stroke, accent text, CTA bg) / `mid` (border, secondary stroke, ~38% α) / `dim` (tint fill, ~11% α). The page then tags every datum with `family: "p" | "s" | "t"` and renders mechanically.

**Lock this as a sanctioned extension of the 6-token base.** Add nine derived CSS vars per mode:

| Token | Light derivation | Dark derivation |
| --- | --- | --- |
| `--color-primary-bright` | `216 55% 35%` (stronger on white) | `216 60% 68%` (lighter on dark — the `#7AA3E1` family) |
| `--color-primary-mid` | `216 55% 25% / 0.38` | `216 60% 68% / 0.38` |
| `--color-primary-dim` | `216 55% 25% / 0.11` | `216 60% 68% / 0.11` |
| `--color-secondary-bright` | `219 14% 38%` | `219 18% 65%` |
| `--color-secondary-mid` | `… / 0.38` | `… / 0.38` |
| `--color-secondary-dim` | `… / 0.11` | `… / 0.11` |
| `--color-tertiary-bright` | `105 28% 38%` | `105 35% 55%` |
| `--color-tertiary-mid` | `… / 0.38` | `… / 0.38` |
| `--color-tertiary-dim` | `… / 0.11` | `… / 0.11` |

Source: `deriveLadder(brand, mode)` — extend `derive.ts` with this pure function. The ladder stays a function of the 6 base tokens, so a brand swap still propagates everywhere.

**Composite tint utilities** — three classes that match the `tint.p/s/t` recipes already used on `security.astro:23-28`:

```css
.tint-primary    { background: hsl(var(--color-primary-dim));    border-color: hsl(var(--color-primary-mid)); }
.tint-secondary  { background: hsl(var(--color-secondary-dim));  border-color: hsl(var(--color-secondary-mid)); }
.tint-tertiary   { background: hsl(var(--color-tertiary-dim));   border-color: hsl(var(--color-tertiary-mid)); }
```

Apply with `<div class="border tint-primary rounded-xl">` — no inline style, no hex, no rgba.

**Family-tagged data is a typed pattern.** When a page or component cycles 3 brands across N items:

```ts
type BrandFamily = 'primary' | 'secondary' | 'tertiary'

const tintClass: Record<BrandFamily, string> = {
  primary: 'tint-primary',
  secondary: 'tint-secondary',
  tertiary: 'tint-tertiary',
}
const accentVar: Record<BrandFamily, string> = {
  primary: 'var(--color-primary-bright)',
  secondary: 'var(--color-secondary-bright)',
  tertiary: 'var(--color-tertiary-bright)',
}

orgRows.map(({ family, ... }) => (
  <details class={`border rounded-2xl ${tintClass[family]}`}>
    <p style={{ color: `hsl(${accentVar[family]})` }}>{lead}</p>
  </details>
))
```

This is the only sanctioned pattern for "cycle through 3 brand colors by category."

**Inline SVG icons inherit via `currentColor`.** `security.astro:30-124` hardcodes `${C.pb}` into stroke/fill attributes. Convert to `currentColor` + a parent `style={{ color: 'hsl(var(--color-primary-bright))' }}` (or class) — same elegance, token-driven. The icon library becomes brand-agnostic.

---

## The bidirectional contract: `security.astro` ↔ `theme.md`

The two enhance each other:

**`security.astro` teaches `theme.md`:**
- The 6-token base isn't enough; brand families need 3-step ladders for dark-surface dense pages.
- Family-tagged data is a re-usable pattern — let pages cycle 3 brands by category instead of inventing per-section colors.
- Composite tints (`bg + border` per family) deserve utility classes, not inline objects.

**`theme.md` teaches `security.astro`:**
- Replace the `C` object (hex literals at `:11-21`) with CSS var references — `hsl(var(--color-primary-bright))`, `hsl(var(--color-primary-mid))`, `hsl(var(--color-primary-dim))`.
- Replace `tint.p/s/t` (`:23-28`) with `.tint-primary` / `.tint-secondary` / `.tint-tertiary` classes.
- Convert inline SVG fills/strokes to `currentColor` + parent token-driven `style`.
- Type-narrow `family: "p" | "s" | "t"` to `family: BrandFamily` ("primary" | "secondary" | "tertiary") — names match tokens.
- Light-mode rendering becomes free: today the page is dark-only because `#7AA3E1` is hand-tuned for dark; with the ladder, light mode auto-derives.
- Card surface (`bg-white/2`, `bg-white/3`, `#0a0a0f`) → `bg-card` or `tint-primary` — no opaque `#0a0a0f` background means the page now respects the user's mode.

**Net result:** `security.astro` becomes the **canonical reference page** — the visual proof that the 6 tokens + 3-step ladder + family pattern can produce a beautiful, dense, multi-brand page with zero raw colors. Other surfaces (`/buy` heroes, `/world` zones, `/u` agent cards) crib from it.

---

## The two formulas (locked)

**Card** = `bg-background text-font` (outer surface) + `bg-foreground` (inner content area) + `shadow-sm rounded-md` (or `shadow-md/lg` + `rounded-lg` for featured) + `transition-all duration-300 ease-in-out`.

**Button** = `bg-{primary|secondary|tertiary} text-{*}-foreground` + `shadow-lg rounded-md` + `hover:shadow-xl hover:scale-[1.02] hover:brightness-95` + `active:shadow-md active:scale-[0.98] active:brightness-93` + `focus-visible:ring-2 ring-primary ring-offset-2` + `disabled:opacity-55 disabled:cursor-not-allowed` + `transition-all duration-150 ease-in-out`.

Outline / ghost variants are *neutral* — `border border-border` or `hover:bg-muted` only. They never use brand color.

These formulas live in [`one.ie/src/components/ui/button.tsx`](one.ie/src/components/ui/button.tsx) and [`card.tsx`](one.ie/src/components/ui/card.tsx). Every other surface composes these — no parallel button or card primitives.

---

## Design tokens (locked, beyond color)

Already in `global.css:219-238`:

| Family | Tokens | Default |
| --- | --- | --- |
| Radius | `--radius-xs/sm/md/lg/xl/full` | `md = 8px` |
| Motion | `--ease-elegant` + duration `instant 0 / fast 150 / normal 300 / slow 500` (ms) | `normal` |
| Elevation | Tailwind `shadow-none/sm/md/lg/xl` | card `sm`, button `lg` |
| Spacing | Tailwind `space-2/3/4/6/8/12` | inside `2-6`, between sections `8-12` |
| Type | Display/Headline/Title/Subtitle/Body/Caption (see Typography below) | Body 16px / `leading-7` |

Typography scale lives in `tailwind.config` defaults — but we ship it via utility classes only. No bespoke `font-size` in components.

| Tier | Class | Use |
| --- | --- | --- |
| Display | `text-5xl md:text-6xl leading-tight` | Hero |
| Headline | `text-4xl leading-tight` | Section titles |
| Title | `text-2xl leading-snug` | Card titles |
| Subtitle | `text-xl leading-relaxed` | Supporting copy |
| Body | `text-base leading-7` | Paragraphs |
| Caption | `text-sm leading-6` | Metadata · labels |

---

## Thing-level override (the escape hatch)

A `Thing` (product, course, token) can ship its own 6 tokens via inline style on a wrapping element:

```tsx
<article style={{
  '--color-background': thing.colors.background,
  '--color-foreground': thing.colors.foreground,
  '--color-font': thing.colors.font,
  '--color-primary': thing.colors.primary,
  '--color-secondary': thing.colors.secondary,
  '--color-tertiary': thing.colors.tertiary,
} as React.CSSProperties}>
  <Card>…</Card>
</article>
```

Same Card/Button formulas, different brand. **This is the only sanctioned override path.** No `style={{ background: '#abc' }}`, ever.

---

## The enforcement (W3 — what makes the plan teeth-bearing)

Three gates. Each is an exit scalar.

### Gate 1 — no raw colors in components

**Forbidden tokens** (regex, run in CI):

```
#[0-9a-fA-F]{3,8}\b           # hex literals
\b(rgb|rgba|hsl|hsla)\(        # color functions
\btext-(red|blue|green|…)-\d   # tailwind palette colors
\bbg-(red|blue|green|…)-\d
```

**Allowed:** `bg-background`, `bg-foreground`, `bg-primary`, `bg-secondary`, `bg-tertiary`, `bg-muted`, `bg-card`, `bg-popover`, `bg-destructive`, `bg-gold`, `text-font`, `text-{token}-foreground`, `border-border`, `ring-ring`, plus the `--color-urgency-*` tokens for `/buy` countdowns.

**Where to run:** `bun run verify` extends with `scripts/verify-theme.ts` — globs `src/**/*.{tsx,astro,ts}` excluding `src/styles/**` and `src/components/ui/**` (primitives), greps for forbidden patterns, exits non-zero on hits. Exit scalar: **0 hits**.

### Gate 2 — `global.css` cleanup

`global.css` itself ships hardcoded colors that need to move into the token system:

| Block | Hardcoded | Replace with |
| --- | --- | --- |
| `.prose pre` (`:438`) | `hsl(0 0% 10%)` | `hsl(var(--color-card))` |
| Task list checkbox (`:933-980`) | `#d1d5db`, `#22c55e`, `#16a34a`, `#1f2937`, `#6b7280` | `hsl(var(--color-border))`, `hsl(var(--color-tertiary))`, `hsl(var(--color-muted))`, `hsl(var(--color-muted-foreground))` |
| ReactFlow dark theme (`:1178-1244`) | `#060608`, `#0f0f14`, `#252538`, `#94a3b8`, `#1e293b`, `#fff`, `#3b82f6` | `hsl(var(--color-background))`, `hsl(var(--color-card))`, `hsl(var(--color-border))`, `hsl(var(--color-muted-foreground))`, `hsl(var(--color-muted))`, `hsl(var(--color-font))`, `hsl(var(--color-primary))` |

After cleanup, `global.css` contains exactly two color sources: the `@theme` block and the `.dark` override. Everything else references via `var(--color-*)`.

### Gate 3 — single source for shadcn map

Today `global.css:179-216` and `derive.ts:14-21` both declare the brand. **Reconcile:** make `global.css` the runtime source, add a vitest that asserts `deriveShadcn(defaultBrand, 'light')` matches the parsed `@theme` block, so a drift breaks the build. Test file: `one.ie/src/styles/derive.test.ts` (already exists — extend it).

---

## Cards, beautifully (the simplification)

Stop inventing cards. The Card primitive is the *only* card. Three variants, no more:

```tsx
<Card variant="default" />   // shadow-sm + rounded-md — the default for 90% of surfaces
<Card variant="elevated" />  // shadow-md + rounded-md — dropdowns, active states
<Card variant="featured" /> // shadow-lg + rounded-lg — hero, key product cards
```

Variant lives as a single `cva()` recipe in [`card.tsx`](one.ie/src/components/ui/card.tsx). Anything richer (hero with gradient overlay, product card with badges) **composes** Card — it doesn't fork it.

Card anatomy is fixed:
1. Outer surface = `bg-background` (the gray frame)
2. Optional `<CardHeader>` (24px padding, Title typography)
3. Inner content area = `bg-foreground` (the white inside) — only when product/thing semantics demand it; default Card is single-surface
4. `<CardFooter>` = action row, right-aligned buttons

Density is controlled by spacing tokens, not by hand-tuned padding numbers.

---

## Buttons, beautifully (the simplification)

Stop inventing buttons. The Button primitive is the *only* button. Five variants, three sizes, no more:

| Variant | When |
| --- | --- |
| `primary` | The single most important action on screen |
| `secondary` | Supporting action paired with primary |
| `tertiary` | Confirming/positive accent (Sign in with Google, success-tinted) |
| `outline` | Neutral, low-emphasis (Cancel, Edit) |
| `ghost` | Inline / toolbar actions |

Sizes: `sm` / `md` (default) / `lg`. Icon button = `size-icon` square. **No bespoke buttons.** If a screen needs a custom action shape, the answer is "compose ghost with an icon", not "fork the primitive."

Per `.claude/rules/ui.md`, every Button click also calls `emitClick('ui:<surface>:<action>')` — telemetry is part of the formula.

---

## Threat model

| Risk | What we defend | What we accept |
| --- | --- | --- |
| Drift between `global.css` and `derive.ts` | Vitest asserts equality; CI fails on diff | Manual `@theme` edits without updating `derive.ts` will be caught at CI, not at edit time |
| New component ships hardcoded `#hex` | `verify-theme.ts` greps `src/**` excluding `ui/**`, exits non-zero | Inline `style={{ '--color-*': '…' }}` Thing overrides bypass the grep — we permit them by spec |
| Dark mode color forgotten | Both modes derived from one `BrandTokens` shape — adding a token forces both columns | Mid-roll change to muted/chart palette still requires manual review |
| Third-party widgets (ReactFlow, Streamdown) ship their own theme | Override in `global.css` mapped to our tokens (Gate 2) | New library may need a one-time block in `global.css`; review before merging |

---

## Tasks (W3 — apply this plan)

1. **Reconcile `defaultBrand` and `@theme`** to the user's chosen values: light bg `0 0% 93%`, dark bg `0 0% 10%`, light fg `0 0% 100%`, dark fg `0 0% 13%`. Edit `derive.ts:14-21` and `global.css:179-216` + `:343-391`. Re-run `derive.test.ts`.
2. **Replace hardcoded colors in `global.css`** per Gate 2 table — three blocks: `.prose pre`, `.task-list-item`, `.colony-graph` + `.react-flow__*`.
3. **Extend `derive.ts` with `deriveLadder()`** — pure function that returns the 9 brand-family ladder vars per mode. Inject into `@theme` and `.dark` blocks. Add `tint-primary` / `tint-secondary` / `tint-tertiary` utility classes in `global.css`.
4. **Add `scripts/verify-theme.ts`** — globs forbidden regexes, prints first 20 hits, exits non-zero. Wire into `bun run verify`. Allow `tint-{primary|secondary|tertiary}` and `var(--color-*)` references.
5. **Convert `security.astro` to tokens** — replace `C` object + `tint.*` with CSS vars and utility classes; convert inline SVG fills/strokes to `currentColor`; rename `family: "p"|"s"|"t"` to `BrandFamily`; remove `#0a0a0f` opaque card bg. The page must render in light mode without color edits. This becomes the reference page; cite it from `website.md` and `one.ie/CLAUDE.md`.
6. **Audit other components** — run the script, fix every hit. Most remaining violations live in landing-page heroes and `/buy` pages. Each fix = swap to a token or to a `tint-*` class.
7. **Lock `Card` and `Button` variants** — collapse any one-off card/button JSX into `<Card variant=…>` and `<Button variant=…>`. Delete the parallel primitives.
8. **Extend `derive.test.ts`** to parse `global.css` `@theme` and assert byte-for-byte match with `deriveShadcn(defaultBrand, 'light')` + `deriveLadder(defaultBrand, 'light')`. Same for `.dark` block + `'dark'` mode.

## Verify (W4 — exit scalars)

- `bun run verify` green.
- `scripts/verify-theme.ts` returns 0 hits across `src/**/*.{tsx,astro,ts}` excluding `src/styles/**` and `src/components/ui/**`.
- `derive.test.ts` asserts CSS ↔ TS parity for both modes.
- Visual smoke: `/`, `/u`, `/chat`, `/buy`, `/sell`, `/wallet` render in light + dark with no eyeball regressions. Shoot one screenshot per route per mode and diff against pre-change baseline.

## Close

Mark on green: `mark('theme:locked', depth)`. Update `MEMORY.md` with a feedback memory: *"Six tokens, two formulas, three gates — never author shadcn variables by hand."*

---

## See also

- [`one.ie/src/styles/global.css`](one.ie/src/styles/global.css) — runtime CSS variables
- [`one.ie/src/styles/derive.ts`](one.ie/src/styles/derive.ts) — pure derivation
- [`one.ie/src/components/ui/button.tsx`](one.ie/src/components/ui/button.tsx) · [`card.tsx`](one.ie/src/components/ui/card.tsx) — the only primitives
- [`one.ie/.claude/rules/ui.md`](one.ie/.claude/rules/ui.md) — `emitClick` is part of every interactive component
- [`website.md`](website.md) — the 5 routes that consume this theme
- [`one.ie/CLAUDE.md`](one.ie/CLAUDE.md) §Tech Stack — Tailwind 4 + shadcn/ui + React 19

*Six tokens. Two formulas. Three gates. Zero raw colors in `src/`.*
