# Create React Component

**Category:** astro
**Version:** 2.0.0
**Used By:** `astro` skill · `/do` W3 edit wave

## Purpose

Add a React 19 island under `one.ie/web/src/components/`, styled with the ONE 6-token
design system. `.claude/rules/design.md` and `.claude/rules/react.md` auto-load on
`*.tsx` — this file is the short version.

## Example

```tsx
// src/components/pricing/PricingTable.tsx
import { cn } from "@/lib/utils"
import { Card } from "@/components/ui/card"

interface PricingTableProps {
  tiers: { name: string; price: number }[]
  className?: string
}

export function PricingTable({ tiers, className }: PricingTableProps) {
  return (
    <div className={cn("grid gap-6 md:grid-cols-3", className)}>
      {tiers.map((tier) => (
        <Card key={tier.name} className="bg-foreground text-font p-6">
          <h3 className="text-lg font-medium">{tier.name}</h3>
          <p className="text-muted">${tier.price}/mo</p>
        </Card>
      ))}
    </div>
  )
}
```

Rules that bite:

- **Token classes only — never a hex value.** The 6 editable tokens are `background`,
  `foreground`, `font`, `primary`, `secondary`, `tertiary`; plus the invariants
  (`white`, `black`, `transparent`, `destructive`, `success`) and derived helpers
  (`muted`, `border`, `on-primary`, …). `Layout.astro` sets `--color-*: initial`, so a
  Tailwind default palette class emits **no CSS at all** — it fails silently.
- Depth: L1 canvas is `background`, L2 chrome (cards, panels, sidebar) is `foreground`.
- Take a `className?` and merge it through `cn` so callers can position the island.
- Import shadcn primitives from `@/components/ui/*`; add new ones via the CLI, not by hand.
- Mount it from the `.astro` page — `client:load` above the fold, `client:visible` below,
  `client:only="react"` when the dependency tree is heavy.

## Version History

- **2.0.0** (2026-08-02): Added the 6-token constraint, `cn`, the silent-failure trap,
  and the hydration hand-off. The 1.0.0 example used none of the ONE conventions.
- **1.0.0** (2025-10-18): Initial implementation
