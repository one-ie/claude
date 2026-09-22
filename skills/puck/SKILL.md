---
name: puck
description: Build with Puck — the drag-drop visual editor for ONE. Covers the @puckeditor/core API, Config/Data types, the block registry in lib/puck/, PuckEditor (client:only) + PuckRenderer (SSR), brand-token injection into the editor iframe, data-bound blocks via RecordPickerField, and the page/funnel storage columns. Use when adding or editing a Puck block, wiring a custom inspector field, debugging a block that renders in the editor but not on /p/, or changing how page data is stored.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Puck — ONE's universal content editor

Puck is the drag-drop visual editor powering ONE's page system. Every landing page (`/p/`), funnel step (`/f/`), and eventually newsletter, product page, and course lesson is authored in one editor, stored as one typed JSON shape (Puck `Data`), and rendered by a small set of per-target renderers.

**Architecture doc:** `text/funnels-pages-plan.md`  
**Source mirror:** `/Users/toc/Server/apps/puckeditor/` (cloned from https://github.com/puckeditor/puck) — read-only reference for upstream types  
**Package:** `@puckeditor/core` — declared `^0.21.3`, installed **0.21.3**. Puck moved from `@measured/puck`@0.20.x to the `@puckeditor` org; the doc set is synced to this name.  
**ONE block registry:** `one.ie/web/src/lib/puck/config.tsx` + its sibling `*-blocks.tsx` files

## Works With

| Skill | Load when |
|---|---|
| `/astro` | The editor is a `client:only` island; the renderer runs SSR in `.astro` files |
| `/react19` | Block `render` fns are React 19 components |
| `/shadcn` | Every block wraps a real component — brand tokens reach the canvas via the iframe injection |
| `/reactflow` | `OrgChartView` and `WorkflowFlow` are lazy-loaded as blocks in `config.tsx` |

This skill is invoked explicitly, not by file glob. What *does* auto-load when you
edit a block file is `rules/react.md` (`**/*.tsx`) and `rules/design.md`
(`one.ie/web/**/*.{tsx,astro,css}`) — the 6-token ban list applies to every block.

---

## Package imports

```ts
// @puckeditor/core ships Puck (editor), Render (SSR renderer), and all types
import { Puck, Render } from "@puckeditor/core";
import type { Config, Data, ComponentConfig, Field, Fields } from "@puckeditor/core";

// Puck CSS — scope to the editor ONLY; never import in the renderer
import "@puckeditor/core/puck.css"; // in the PuckEditor component only
```

> **CSS isolation rule:** `@puckeditor/core/puck.css` must only be imported inside the `PuckEditor` component (the `client:only` island). Never import it in `PuckRenderer` or any server-rendered path — it will bleed Puck's chrome styles into visitor pages.

---

## The `Config` shape

A Puck config is the block registry: a map of component names to their field schema and render function.

In `config.tsx` the registry is not one literal — it is 12 block groups merged, then
wrapped, with categories derived from each block's `metadata.category`:

```ts
// one.ie/web/src/lib/puck/config.tsx — the tail of the file
export const puckConfig: Config = {
  components: withChrome({
    ...blocks, ...dataBlocks, ...teamFlowBlocks, ...studioBlocks, ...appBlocks,
    ...walletBlocks, ...socialBlocks, ...socialFormatBlocks, ...authBlocks,
    ...aiBlocks, ...ecommerceNewBlocks, ...generalNewBlocks,
  }),
  categories: buildCategories(blocks, dataBlocks, teamFlowBlocks, studioBlocks,
    appBlocks, walletBlocks, socialBlocks, socialFormatBlocks, authBlocks,
    aiBlocks, ecommerceNewBlocks, generalNewBlocks),
};
```

`withChrome` and `buildCategories` are module-private helpers at the tail of
`config.tsx` (lines ~6732 and ~6776) — `withChrome` wraps every block's render
with the shared section chrome; `buildCategories` derives the palette groups from
each block's `metadata.category`.

Adding a block means adding a key to one of those groups — never a new
top-level spread. A single block looks like this:

```tsx
Heading: {
  metadata: { surface: 'section', semantics: {}, ...web, category: 'content',
              icon: 'Type', description: 'Section heading' },
  fields: {
    text:  { type: 'text' as const },
    level: { type: 'select' as const, options: [
      { label: 'H1', value: 'h1' }, { label: 'H2', value: 'h2' },
    ] },
  },
  defaultProps: { text: 'Heading', level: 'h1' },
  render: ({ text, level }: { text: string; level: string }) => {
    const Tag = level as 'h1' | 'h2';
    return <Tag className="font-bold tracking-tight text-font">{text}</Tag>;
  },
},
```

Note `as const` on every field `type` — without it TypeScript widens the literal
to `string` and the `Fields` type rejects the object.

### ComponentConfig anatomy

```ts
type ComponentConfig<Props> = {
  label?: string;           // palette display name (defaults to component key)
  fields: Fields<Props>;    // inspector form schema
  defaultProps?: Props;     // initial values on drag-in
  render: (props: WithId<Props>) => JSX.Element;             // the block renderer
  metadata?: Record<string, any>;                            // ONE's extension point — see below
  resolveData?: (data, params) => Promise<{ props?: Partial<Props> }>;
  resolveFields?: (data, params) => Promise<Fields<Props>>;  // dynamic inspector fields
  permissions?: { drag?; duplicate?; delete?; insert?; move? };
  inline?: boolean;         // renders inline (no wrapper div)
};
```

The 0.21 type is **strict about sibling keys** — anything ONE-specific must go
under `metadata`, never beside `fields`. `metadata` in this repo carries
`category`, `icon`, `description`, `preview`, `surface`, `semantics`, and
`targets`; `buildBlockIndex` (`lib/puck/block-index.ts`) reads exactly those, with
fallbacks `category → 'content'`, `icon → 'Square'`, `description → ''`.

---

## Field types

The inspector is driven by `fields` in each block's config. Counts below are live
occurrences in `config.tsx` — they tell you which shapes are load-bearing here:

| Type | Uses | Usage |
|---|---|---|
| `{ type: "text" }` | 421 | Single-line text input; `contentEditable?: true` for inline editing on canvas |
| `{ type: "radio", options: [{label, value}] }` | 111 | Radio group — the repo's boolean toggle |
| `{ type: "textarea" }` | 74 | Multi-line text |
| `{ type: "array", arrayFields: {…}, getItemSummary?, min?, max? }` | 50 | Repeating sub-items (feature rows, CTA lists) |
| `{ type: "number", min?, max?, step? }` | 27 | Numeric |
| `{ type: "select", options: [{label, value}] }` | 24 | Dropdown |
| `{ type: "custom", render: ({value, onChange}) => JSX }` | 9 | Custom inspector widget — **how ONE does every picker** |
| `{ type: "slot" }` | 7 | A droppable zone inside a block |
| `{ type: "object", objectFields: {…} }` | 3 | Nested group |
| `{ type: "external", fetchList, mapProp?, showSearch? }` | 2 | Puck's built-in remote picker — rarely used here |
| `{ type: "richtext" }` | 1 | Rich text with Tiptap |

### Custom field — how ONE builds a picker

ONE does **not** use Puck's `external` field for workspace data. Pickers are
`type: 'custom'` wrapping a lazy-loaded React field, so the field's browser deps
stay out of the SSR worker bundle. `config.tsx` lazy-imports four of them:
`RecordPickerField`, `TypeBindingField`, `ViewQueryField`, `BrandColorField`.

```tsx
const RecordPickerField = lazy(() =>
  import('@/components/puck/RecordPickerField').then((m) => ({ default: m.RecordPickerField }))
);

// inside a block's fields:
productId: {
  type: 'custom' as const,
  render: ({ value, onChange }: { value: string; onChange: (v: string) => void }) => (
    <Suspense
      fallback={
        <input
          type="text"
          value={value ?? ''}
          onChange={(e) => onChange(e.target.value)}
          style={{ width: '100%', padding: '4px' }}
        />
      }
    >
      <RecordPickerField value={value ?? ''} onChange={onChange} />
    </Suspense>
  ),
},
```

The `Suspense` fallback must be a working plain input — the editor is usable
while the field chunk loads.

Server-side, `lib/puck/pickable-records.ts` turns a bound resolver's list result
into flat `{ id, label }[]` for the picker. It resolves the receiver from the
binding (`boundReceiver(rt, 'list')`), calls it with a **public** caller context,
and reads the plural key by convention — `'product'` → `result.products`.

---

## `Data` shape (the stored IR)

Everything authored in Puck is stored as `Data`:

```ts
type Data = {
  root: { props?: { title?: string; [key: string]: any } };
  content: Array<{ type: string; props: { id: string; [key: string]: any } }>;
  zones?: Record<string, Array<{ type: string; props: { id: string } }>>;
};

// An empty page
const emptyData: Data = { root: {}, content: [] };
```

`root` is `{}` in every value this repo constructs (`migrate.ts`, `normalize.ts`,
`templates.ts`) — not `{ props: {} }`. Both satisfy the type; match the repo.

**Where ONE stores it:**
- Landing pages: `pages.data` column (D1) — row written by `pages:create` / `pages:edit`
- Funnel steps: `funnel_definitions.steps[N].config.puck` (JSON column)

### normalizePuckData — always run it on load

Puck merges `defaultProps` at **render** time only; it never writes them back into
the data. A block loaded from storage with sparse props renders its defaults on
the canvas but shows *empty* inspector fields. `lib/puck/normalize.ts` closes that
gap — stored props always win over defaults:

```ts
import { normalizePuckData } from '@/lib/puck/normalize';

const data = normalizePuckData(JSON.parse(row.data));
```

---

## `PuckEditor` — the client:only island

The editor must be `client:only` because Puck requires browser APIs. Use the `Puck` component from `@puckeditor/core`:

```tsx
// one.ie/web/src/components/puck/PuckEditor.tsx — the real imports
// @ts-ignore — puck.css has no type declarations but the import is valid at runtime
import '@puckeditor/core/puck.css'
import './puck-theme.css'
import { Puck, usePuck, type Data } from '@puckeditor/core'
import { puckConfig } from '@/lib/puck/config'
import { normalizePuckData } from '@/lib/puck/normalize'
import { computeStyleBlock, type SiteToken } from '@/lib/site'
```

The real component takes ~24 props, not two — `data`, `siteTokens`,
`siteDarkTokens`, `onChange`, `onPublish`, `workspace`, `pageSlug`, `title`,
`pageStatus`, `saved`, `error`, `publishing`, `customDomain`, `target = 'web'`,
and the toolbar/drawer callbacks. Read the `interface Props` before adding one.

Mounted in Astro as `client:only="react"` — Puck needs browser APIs and cannot
SSR:

```astro
<PuckEditor client:only="react" data={data} siteTokens={tokens} pageSlug={slug} />
```

### Brand injection into the iframe

The editor canvas runs in a sandboxed `<iframe>` — Tailwind 4 globals and the
workspace's 6 brand tokens do **not** cascade in. Puck's `overrides.iframe`
receives the live `contentDocument`, which is the first-class injection point.
This is shipped in `PuckEditor.tsx`:

```tsx
<Puck
  config={puckConfig}
  data={normalizePuckData(data)}
  overrides={{
    iframe: ({ children, document: iframeDoc }: {
      children: React.ReactNode;
      document?: Document;
    }) => {
      // Inject the workspace's 6-token brand CSS into the editor iframe so the
      // canvas paints in the tenant's colors, not the platform default.
      useEffect(() => {
        if (!iframeDoc || !siteTokens) return;
        const style = iframeDoc.createElement('style');
        style.textContent = computeStyleBlock(siteTokens);
        iframeDoc.head.appendChild(style);
        return () => style.remove();
      }, [iframeDoc]);
      return <>{children}</>;
    },
  }}
/>
```

Rename the destructured `document` — shadowing the global inside a React
component breaks any sibling code that expects the real one.

`computeStyleBlock` (`lib/site.ts:59`) has the signature:

```ts
computeStyleBlock(
  tokens: Partial<Record<SiteToken, string>>,
  darkTokens: Partial<Record<SiteToken, string>> = {},
  font?: string,
): string
```

It emits `:root:not(.dark) { … }` and `:root.dark { … }` rules — both at
specificity (0,2,0), so they beat `Layout.astro`'s `:root` / `html.dark` defaults
regardless of where the bundler places them, and stored light values can never
leak into dark mode. It also derives `--color-on-{primary,secondary,tertiary}`
contrast labels for each brand fill. `PuckEditor` calls it with one argument.

**Tailwind 4 guard:** `Layout.astro` declares `--color-*: initial`, wiping the
default palette. Puck's own CSS is scoped by importing it *only* in
`PuckEditor.tsx` (a `client:only` island) alongside the local `puck-theme.css`
overrides. The renderer imports **no** Puck CSS.

---

## `PageStudio` — the editor surface (chat-left, build-right)

`PageStudio.tsx` is the live editor surface mounted at `/u/[slug]/pages/[pageSlug]/edit`. It composes the workspace **`Chat`** on the LEFT with the editable **`PuckEditor`** on the RIGHT — one surface, not two. The operator edits by talking to the agent *and* by direct canvas manipulation.

- **Chat (left):** `<Chat slug mode="rail-45" context={{ surface: 'builder', entityId: pageSlug, entityLabel: title }} onTurnSettled={reReadPage} />`. The `entityId` is the deterministic page target. `chat.ts` adds a `builderSuffix` for `surface:'builder'` that pins `edit_page slug=entityId` (channels does **not** auto-default the page slug from `entityId` the way it does for newsletter — the model needs the instruction).
- **Canvas refresh:** on each settled turn, `reReadPage` GETs `/api/pages/[slug]`, runs `componentsToPuck(components)` → `normalizePuckData`, and bumps the `PuckEditor` key — guarded on `updated_at` so a no-op turn never remounts/flickers.
- **Templates → chat:** picking a template applies its skeleton instantly, then dispatches `one:chat-seed` with the template's tuned `prompt` so the same Chat streams a complete page. (This retired the old right-side `PuckAiPanel`.)
- **Shell:** the host `edit.astro` uses `Layout sidebar="none" chat="none"` so `Layout`'s `ChatHost` doesn't render a second chat — `PageStudio` owns its left rail. Same guard as `build.astro`.

Note the column split: the channels `edit_page`/`create_page` tools write the `pages.components` column (CRO sections); `PageStudio.save()` (manual Puck edits) writes `pages.data` (Puck JSON). The canvas re-read uses `components` (the chat's write).

---

## `PuckRenderer` — SSR render

No editor chrome, no editor JS shipped to visitors. Pure server-side render via `<Render>`:

```tsx
// one.ie/web/src/components/puck/PuckRenderer.tsx — the whole file
// SSR-safe. NO puck.css import (pulls editor chrome into SSR bundle).
// NO import of PuckEditor (client:only). Renders published Puck data server-side.
import { Render, type Data } from '@puckeditor/core'
import { puckConfig } from '@/lib/puck/config'

interface Props {
  data: Data
}

export function PuckRenderer({ data }: Props) {
  if (!data || !data.content || data.content.length === 0) return null
  return <Render config={puckConfig} data={data} />
}
```

The empty-content guard matters: `<Render>` on an empty `content` array emits a
bare wrapper div that breaks page layout. Return `null` and let the caller decide.

Used in Astro routes:
```astro
---
// pages/p/[slug].astro — always prerender:false (avoids astro#16529, two React copies)
export const prerender = false;
import { PuckRenderer } from "@/components/puck/PuckRenderer";
const data = JSON.parse(page.data); // from D1
---
<Layout>
  <PuckRenderer data={data} />
</Layout>
```

> **Never set `prerender:true` on a Puck route** — Astro's static rendering triggers the two-React-copies bug (astro#16529) when `@puckeditor/core` ships its own React copy. All `/p/` and `/f/` routes are SSR (`prerender:false`).

---

## ONE's block registry (`lib/puck/config.tsx`)

All blocks reach the editor through one export: `puckConfig`. The groups it merges:

> **No counts here on purpose.** Every number this section ever carried went stale
> within days — the registry grows constantly. To count, read `puckConfig.components`;
> `buildBlockIndex` gives you the list without loading `config.tsx`.

| Group | Declared in |
|---|---|
| `blocks` | `config.tsx` — structural, CRO, funnel, media, layout |
| `generalNewBlocks` | `general-{a,b,c}-blocks.tsx` |
| `ecommerceNewBlocks` | `ecommerce-{discover,evaluate-a,evaluate-b,persuade-a,persuade-b,convert,support}-blocks.tsx` |
| `socialFormatBlocks` | `social-format-blocks.tsx` |
| `socialBlocks` | `config.tsx` |
| `authBlocks` | `config.tsx` |
| `dataBlocks` | `config.tsx` |
| `appBlocks` | `config.tsx` |
| `studioBlocks` | `config.tsx` |
| `aiBlocks` | `ai-blocks.tsx` |
| `walletBlocks` | `config.tsx` |
| `teamFlowBlocks` | `config.tsx` |

Two subsets are pinned by `tests/unit/puck/config.test.ts` and must never
regress — the **7 structural** blocks (`Heading`, `Text`, `Image`, `Button`,
`Form`, `Columns`, `Spacer`) and the **9 CRO** blocks (`LandingHero`, `ProofBar`,
`HowItWorks`, `LandingFeatures`, `Testimonials`, `ComparisonTable`,
`PricingSection`, `FAQSection`, `SecondaryCTA`). The test asserts each is defined,
has a `render` function, and carries `metadata.targets` containing `'web'`.

For a live count or a palette search, use `buildBlockIndex(puckConfig)` from
`lib/puck/block-index.ts` — a pure function with no DOM or Puck-runtime import,
so it is trivially testable.

Each CRO block wraps the existing component from `one.ie/web/src/components/cro/`:

```tsx
import { LandingHero as LandingHeroComponent } from "@/components/cro/LandingHero";
import { bgTokenField, bgPatternField } from "@/lib/puck/bg-fields";

// In one of the 12 block groups:
LandingHero: {
  metadata: { surface: 'section', semantics: {}, ...web, category: 'cro',
              icon: 'Rocket', description: 'Hero with headline and dual CTA' },
  fields: {
    bgToken:      bgTokenField,
    bgPattern:    bgPatternField,
    headline:     { type: 'text' as const },
    highlight:    { type: 'text' as const },
    subhead:      { type: 'text' as const },
    eyebrow:      { type: 'text' as const },
    frictionText: { type: 'text' as const },
    primaryCta:   {
      type: 'object' as const,
      objectFields: {
        label: { type: 'text' as const },
        href:  { type: 'text' as const },
      },
    },
    secondaryCta: {
      type: 'object' as const,
      objectFields: {
        label: { type: 'text' as const },
        href:  { type: 'text' as const },
      },
    },
  },
  defaultProps: {
    headline: 'Your headline here',
    subhead: 'Your sub-headline here',
    primaryCta: { label: 'Get started', href: '#' },
  },
  render: (props) => <LandingHeroComponent {...props} />,
},
```

`bgTokenField` and `bgPatternField` (`lib/puck/bg-fields.tsx`) are the shared
background-token and pattern fields every themeable block reuses — import them,
never redeclare a background field inline.

**Reuse contract:** CRO components are **never reimplemented** inside the block —
they are always imported and wrapped. Blocks are thin wrappers; the component
lives in `components/cro/`, `components/booking/`, `components/auth/`, etc.

### Per-block target — `metadata.targets`

Each block declares which render targets it supports, which is what filters the
palette when the editor runs in a non-web `target` mode. This is shipped, and
`config.test.ts` asserts every structural and CRO block carries `'web'`.

```ts
// Puck's ComponentConfig REJECTS unknown sibling keys (the 0.21 type is strict —
// render/label/defaultProps/fields/permissions/inline/resolveFields/resolveData/metadata).
// `targets` is NOT a bare sibling — it lives under the supported `metadata` key.
// config.tsx spreads a shared `web` const rather than repeating the literal:
const web = { targets: ['web'] };

Heading: {
  // `surface` and `semantics` are not optional — see § The chrome contract.
  metadata: { surface: 'atomic', semantics: { heading: 'text' }, ...web,
              category: 'content', icon: 'Type', description: 'Section heading' },
  fields: { /* … */ },
  render: (props) => <…/>,
};
```

`metadata` is the supported channel for any ONE-specific block flag — never add
bare keys to a Puck component config.

### The chrome contract (every block, no exceptions)

`tests/unit/blocks-enhance.test.ts` iterates `puckConfig` and fails the build if a
block skips either key. It is the reason a new block gets themeable for free.

**`surface`** — how much chrome the block may carry:

| Surface | Carries |
|---|---|
| `section` | background colour + texture + auto-contrast |
| `container` | background colour + auto-contrast; texture optional |
| `atomic` | text colour only — a fill on a Spacer is a bug |
| `social-preview` | images only, **never** a brand fill (a tweet card painted `--color-tertiary` stops being a tweet card) |
| `app` | images only |

A `section` must expose both `bgToken: bgTokenField` and `bgPattern: bgPatternField`;
a `container` must expose `bgToken`. `withChrome` paints them — do not read `bgToken`
in your render unless you also add the block to `SELF_CHROME`.

**`semantics`** — maps canonical roles to this block's own prop names,
`{ heading, body, cta, image }`. It exists because `genericEmailNode` was guessing
across ~20 aliases. Name only props that exist; a path (`testimonials[].avatar`) is
fine. `{}` is the honest answer for a Spacer.

**Contrast is never re-derived.** Import from `lib/puck/surface-chrome.ts`
(`surfaceChrome`, `onText`, `ON_TEXT`). The `on-*` classes must be **static strings** —
`text-on-${token}` compiles to nothing, which is exactly how text ends up the same
colour as the fill beneath it.

**Image fields** use the shared `imageSrcField` (`lib/puck/image-field.tsx`) so the
media library and R2 upload come for free. `src` means an image in `Image`,
`ImageBlock`, `PortfolioSection`, `LogoGridBlock`; in `VideoEmbed` and `MapEmbed` it is
an embed URL and stays a text box.

**Your defaultProps must render.** `blocks-enhance-ssr.test.ts` renders every fillable
block through `PuckRenderer` on a brand fill, with no exclusions — a block that crashes
on its own defaults fails there.

---

## Data-bound blocks (`resolve-bindings`, not `resolveData`)

ONE does **not** use Puck's `resolveData` hook. A data-bound block stores only an
**id**, and `resolvePageBindings` (`lib/puck/resolve-bindings.ts`) resolves it
server-side before render, injecting the live record as `_resolved`. The block's
`render` stays synchronous and never fetches.

Three moving parts:

1. **The field** stores the id — `type: 'custom'` + `RecordPickerField` (see
   § Custom field above).
2. **`resolve-bindings.ts`** walks `data.content` server-side, looks the id up
   through the workspace's binding manifest, and writes `_resolved` into props.
3. **`render`** reads `_resolved`, with the bare id as the fallback stub.

```tsx
import type { PriceRow } from '@/lib/storefront'

// ProductBlock is data-bound. resolvePageBindings resolves `productId` through the
// commerce binding server-side and injects the live product as `_resolved`; absent
// it (unbound id, or not published) the block falls back to the id stub.
ProductBlock: {
  metadata: { surface: 'section', semantics: {}, ...web, category: 'ecommerce',
              icon: 'Package', description: 'Data-bound product display' },
  fields: {
    bgToken: bgTokenField,
    bgPattern: bgPatternField,
    productId: {
      type: 'custom' as const,
      render: ({ value, onChange }: { value: string; onChange: (v: string) => void }) => (
        <Suspense fallback={<input type="text" value={value ?? ''}
          onChange={(e) => onChange(e.target.value)} style={{ width: '100%', padding: '4px' }} />}>
          <RecordPickerField value={value ?? ''} onChange={onChange} />
        </Suspense>
      ),
    },
  },
  defaultProps: { productId: '' },
  render: ({ productId, _resolved }: {
    productId: string
    _resolved?: { name: string; description: string | null; images: string; prices: PriceRow[] }
  }) => {
    if (!_resolved) return <div className="text-font/60 text-sm p-4">Pick a product in the inspector.</div>;
    return (
      <div className="rounded-lg border p-6" style={{ borderColor: 'var(--color-border)' }}>
        <h3 className="font-semibold text-font">{_resolved.name}</h3>
        <p className="text-font/60">{_resolved.description}</p>
      </div>
    );
  },
},
```

`RecordBlock` is the generic counterpart: any manifest-declared bound type renders
through it, keyed by `typeKey` (matching the manifest entry) plus `recordId`.

**Wire shapes** (`lib/resolvers/commerce.ts`) — both receivers exist:

| Receiver | In | Out |
|---|---|---|
| `products:list` | `{ slug }` | `{ products: ProductWithPrices[] }` |
| `products:get` | `{ slug, pid }` | `{ product: ProductWithPrices \| null }` |

There is no server-side `query` filter on `products:list` — the picker fetches the
workspace's products once and filters client-side. Never make an N+1 call per block:
resolution is one server-side pass over the whole page, not one fetch per block.

---

## The `usePuck` hook (custom editor UI)

Inside a custom field or a custom Puck override, `usePuck()` gives you access to editor state:

```tsx
import { usePuck } from "@puckeditor/core";

function MyCustomField({ value, onChange }) {
  const { appState, dispatch } = usePuck();
  // appState.data — the full page Data
  // dispatch({ type: "INSERT", ... }) — programmatic mutations
  return <input value={value} onChange={(e) => onChange(e.target.value)} />;
}
```

---

## Migration (`components[]` → Puck `Data`)

`pages.components` (the legacy `PageSection[]` shape) converts to Puck `Data` 1:1,
because block `type` names match the old `component` names exactly. One source of
truth, used on both the write path (`resolvers/pages.ts` dual-write) and the read
path (`/p/[slug].astro` lazy-migrate):

```ts
// one.ie/web/src/lib/puck/migrate.ts — the whole file
import type { Data } from '@puckeditor/core'
import type { PageSection } from '@/lib/pages'

export function componentsToPuck(sections: PageSection[]): Data {
  return {
    content: sections.map((s, i) => ({
      type: s.component,
      props: { ...s.props, id: `${s.component}-${i}` },
    })),
    root: {},
  } as unknown as Data
}
```

Two details that are easy to get wrong: the id is `${s.component}-${i}`
(deterministic per position, so a re-migration is idempotent), and the `as unknown
as Data` cast is deliberate — `ComponentData` requires an `id` that the mapped
literal cannot prove structurally.

Both columns still exist. The chat tools (`edit_page` / `create_page`) write
`pages.components`; manual Puck edits write `pages.data`.

---

## Starter templates

Seed `Data` skeletons that make the first page one click, in
`lib/puck/templates.ts`. The export is **`funnelTemplates: PuckTemplate[]`** — an
array, not a keyed record:

```ts
export interface PuckTemplate {
  id: string;
  name: string;
  description: string;
  // Static skeleton — applied instantly on click so the canvas is never blank.
  data: PuckData;
  // Sent to the chat on click; the model streams a complete, richly-filled
  // version of this page back as Puck JSON, replacing the skeleton.
  prompt: string;
}

export const funnelTemplates: PuckTemplate[] = [
  { id: 'opt-in', name: '…', description: '…', data: { content: [...], root: {} }, prompt: '…' },
  // …
];
```

The `prompt` field is the important half: a template is a skeleton **plus** an AI
instruction, not a finished page. `PuckEditor` imports `funnelTemplates` directly.

---

## Email target mode

The editor runs in `target: 'web' | 'email'`, defaulting to `'web'`. `PuckEditor`
takes `target` as a prop and publishes it through `PuckTargetContext`
(`components/puck/puck-target-context.ts`) so `BlockPalette` — rendered inside
`overrides.drawer`, where there is no prop path — can filter by
`metadata.targets`.

```tsx
import { PuckTargetContext, usePuckTarget } from '@/components/puck/puck-target-context';

// In PuckEditor: <PuckTargetContext.Provider value={target}>…</PuckTargetContext.Provider>
// In BlockPalette:
const target = usePuckTarget();  // 'web' | 'email'
```

A block opts into the email palette by spreading the shared `emailTarget` const
instead of `web`:

```ts
// config.tsx
const web = { targets: ['web'] as const };
const emailTarget = { targets: ['web', 'email'] as const };

Heading: {
  metadata: { ...emailTarget, category: 'content', icon: 'Type', description: '…' },
  fields: { /* … */ },
  render: (props) => <…/>,
},
```

**Email rendering is never done via React DOM `renderToString`** — that produces
flexbox HTML that breaks in Gmail. `lib/broadcast/render.ts` is a separate
serializer emitting table-based, inline-styled HTML with `safeUrl` scheme
allowlisting and `/go/:id` tracking.

---

## The three target renderers (decision matrix)

| Target | Renderer | Input | Output | ONE path |
|---|---|---|---|---|
| **Web** | `<Render>` (Puck SSR) | Puck `Data` | React → flexbox HTML | `PuckRenderer.tsx` |
| **Email** | `broadcast/render.ts` serializer | Puck `Data` | Table-based, inline-style HTML | `lib/broadcast/` |
| **Data** | `lib/data-bindings.ts` + `ResourceType` | `{type, id\|filter}` | Live workspace rows | `lib/puck/resolve-bindings.ts` |

Do not force email through React or web through the email serializer — they are separate, intentional.

---

## Kill-switch

```bash
# All three legs are green as of 2026-08-02:
grep -q '@puckeditor/core' one.ie/web/package.json \
  && test -f one.ie/web/src/lib/puck/config.tsx \
  && ! test -f one.ie/web/src/components/cro/PageRenderer.tsx \
  && (cd one.ie/web && bun vitest run tests/unit/puck/)
```

`tests/unit/puck/` holds 16 spec files — `config.test.ts` pins the structural and
CRO block sets; the rest cover the block packs, bindings, migration, and restore.

Note: `@puckeditor/core` is canonical across the funnels-pages doc set;
`@measured/puck`@0.20.x is the superseded upstream name.

---

## No Puck cloud

ONE does **not** use Puck's hosted cloud service or any Puck-managed storage. There is no `/puck/api` route. Storage goes through ONE's own D1 via receivers:

- `pages:create` / `pages:edit` — landing pages → `pages.data`
- `funnel:update-step` — funnel step pages → `funnel_definitions.steps[N].config.puck`

The `onPublish` callback in `<Puck>` calls ONE's own `/api/ask` endpoint:

```tsx
<Puck
  config={puckConfig}
  data={initialData}
  onPublish={async (data) => {
    await fetch("/api/ask", {
      method: "POST",
      body: JSON.stringify({ receiver: "pages:edit", data: { slug, data } }),
    });
  }}
/>
```

Do not use `resolveAllData` with external Puck cloud endpoints. All data resolution is through ONE's receivers, `lib/data-bindings.ts`, and the binding resolver.

---

## Don'ts (the guards)

| Don't | Why | Guard |
|---|---|---|
| Use Puck cloud / puckeditor.com hosted backend | ONE stores all page data in its own D1 via receivers | No `/puck/api` route; `onPublish` must call `/api/ask` |
| Import `@puckeditor/core/puck.css` in `PuckRenderer` or any Astro layout | Puck chrome styles bleed into visitor pages | Grep: `puck.css` appears only in `PuckEditor.tsx` |
| Set `prerender:true` on any `/p/` or `/f/` route | astro#16529: two React copies crash the page | All Puck routes must have `export const prerender = false` |
| Reimplement a component inside a block `render` fn | It already exists in `components/cro/`, `components/booking/`, etc.; the block is a thin wrapper | Named-import grep |
| Add a bare key beside `fields` in a block config | The 0.21 `ComponentConfig` type is strict and rejects it | Everything ONE-specific goes under `metadata` |
| Omit `as const` on a field `type` | TS widens the literal to `string` and `Fields` rejects the object | `bun run typecheck` |
| Trust `body.actorId` or `body.slug` in receiver resolvers | IDOR — use `ctx.ownerSlug` (attested) only | `authorizeWorkspace(locals, slug, db)` on every media/page write route |
| Fetch live data inside a block `render()` | N+1 — the page is resolved in one server-side pass | No `fetch` in a `render` fn; use `resolve-bindings.ts` + `_resolved` |
| Use a hex or a Tailwind palette class in a block | `rules/design.md` auto-loads here; the palette is wiped so it emits no CSS | `hook:design-check` blocks the edit |
| Merge Puck with the Workflow (ReactFlow) canvas | Different substrates: pages = layout tree, workflows = signal DAG | `lib/puck/` and `lib/workflow*/` must stay separate |

---

## Checklist — starting a new Puck cycle

1. **Read the plan** — `text/funnels-pages-plan.md` (architecture + pre-mortem table)
2. **Run the kill-switch** to see current state before editing
3. **Search the registry first** — the block you want probably exists. `buildBlockIndex` +
   `searchBlocks` (`lib/puck/block-index.ts`) answer "does this block exist?"
   without loading `config.tsx`
4. **Pick the right group** — a new block joins an existing group; never add a
   13th top-level spread
5. **Import, don't reimplement** — the component lives in `components/`
6. **Give it full `metadata`** — `category`, `icon`, `description`, and a
   `targets` spread (`...web` or `...emailTarget`); the palette and the block
   index both read it
7. **Check migration number** — `one.ie/web/migrations/` highest number before creating a new SQL file
8. **Keep all Puck routes `prerender:false`**
9. **Scope `puck.css` to `PuckEditor.tsx` only**
10. **authorizeWorkspace on every write route** (IDOR guard from `lib/analytics/authz.ts`)
11. **Put vitest files in `tests/unit/puck/`** — not in `src/` (web vitest only discovers `tests/**`)
12. **Run via `bun vitest run`** (not `bunx vitest`) — uses the local binary
