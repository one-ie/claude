# Playbook — ELEVATE Framework Page

**Route:** `/playbook`  
**Source SVG:** `https://one.ie/images/drawings/Elevate.svg` (2000×1722 viewBox)

## What it is

An interactive ReactFlow diagram of the ELEVATE Framework — the ONE AI Playbook for e-commerce growth. The diagram is a static, non-draggable flow with hover states and `emitClick` signals on every node.

## Layout (derived from SVG coordinates)

```
┌─────────────────────────────────────────────────────────────────┐
│  GROW ↑        [Upsell]  ──X──  [Educate]  ──X──  [Share]      │
│  Elevate Value     │ ↖          │ ↗↙          │                 │
│                    │    ╳       │    ╳         │                 │
│  CONVERT ↑      [Nurture] ──→  [Sell]  ←──  [Engage]           │
│  Elevate Sales     │             │                │              │
│                    │             │                │              │
│  ATTRACT ↑      [Hook]  ──>>  [Gift]  ──>>  [Identify]          │
│  Elevate Reach   ↑             ↗                                │
│                [Customer]                                        │
│                                                                  │
│  FOUNDATION  [Company] ──> [Market] ──> [Customers]             │
└─────────────────────────────────────────────────────────────────┘
```

## Node grid (ReactFlow canvas, pixels)

| | Col 1 (x=265) | Col 2 (x=510) | Col 3 (x=747) |
|---|---|---|---|
| GROW (y=110) | Upsell | Educate | Share |
| CONVERT (y=315) | Nurture | **Sell** (highlighted) | Engage |
| ATTRACT (y=531) | Hook | Gift | Identify |

Foundation bar at y=640. Customer figure at (279, 632).

## Edge map

| Edge | Direction | Style |
|------|-----------|-------|
| Hook → Gift → Identify | `>>` right | 55% opacity, arrow |
| Nurture → Sell ← Engage | converge on Sell | 55% opacity, arrow |
| Upsell → Educate → Share | `>>` right | 55% opacity, arrow |
| Upsell ↔ Nurture | left column vertical | 18% opacity |
| Engage ↔ Identify | right column vertical | 18% opacity |
| Nurture ↗ Educate + Sell ↖ Upsell | X cross GROW/CONVERT | 18% opacity |
| Gift → Nurture | ATTRACT→CONVERT diagonal | 18% opacity |
| Customer → Hook | upward | 50% opacity, arrow |
| Company → Market → Customers | foundation row | 40% opacity, arrow |

## Files

| File | Purpose |
|------|---------|
| `one.ie/web/src/pages/playbook.astro` | Marketing page — hero + diagram + phase cards |
| `one.ie/web/src/components/playbook/PlaybookFlow.tsx` | ReactFlow diagram, `client:only="react"` |

## Icons (lucide-react)

| Node | Icon |
|------|------|
| Upsell | BarChart2 |
| Educate | Lightbulb |
| Share | RefreshCcw |
| Nurture | RotateCcw |
| Sell | ShoppingCart |
| Engage | MessageSquare |
| Hook | Radio |
| Gift | Gift |
| Identify | UserCheck |

## Signals

Every node emits `ui:playbook:node-{label}` on click.  
Foundation items emit `ui:playbook:foundation-{label}`.

## Future cycles

- [ ] Click-through to detailed module drawer (description, prompts, case study metrics)
- [ ] Animated path highlight when hovering a phase section
- [ ] Mobile: condensed vertical layout or scrollable canvas
- [ ] Connect nodes to agent capabilities (skill import from ONE)
