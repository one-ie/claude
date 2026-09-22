---
name: reactflow
description: Node-based graph surfaces in `one.ie/web` built on @xyflow/react v12 — WorkflowFlow, OrgChartView, SignalGraph, LifecycleFlow, PathGraph, TypesCanvas. Covers the v12 NodeProps/EdgeProps generic pattern the repo actually uses, node/edge type registries, 6-token styling inside a canvas, dagre auto-layout, and client:only mounting. Use when adding a custom node or edge, wiring a nodeTypes registry, fixing a graph that renders unstyled or fails tsc, or laying out substrate paths.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# ReactFlow Development

Interactive graph surfaces in `one.ie/web`, built on `@xyflow/react` **12.10.2**
(declared `^12.10.2`).

This is a live, heavily-used dependency — **25 files** under
`one.ie/web/src/components/` import it. Read one of them before writing a new
graph; the conventions below are extracted from them, not from upstream docs.

| Surface | Entry | Node registry |
|---|---|---|
| Workflow canvas | `components/workflows/WorkflowFlow.tsx` | `NODE_TYPES` — 8 step kinds + `chain` + `route` |
| Org chart | `components/org/OrgChartView.tsx` | `{ role: RoleNode }` |
| Signal graph | `components/org/SignalGraph.tsx` | `{ role: RoleNode }` · `{ path: PathEdge }` |
| Lifecycle | `components/lifecycle/LifecycleFlow.tsx` | 8 node types · `{ lifecycle: LifecycleEdge }` |
| Paths | `components/paths/PathGraph.tsx` + `path-flow.ts` | substrate strength/resistance |
| Types canvas | `components/data/TypesCanvas.tsx` | dagre auto-layout |
| Router brain | `components/do/RouterBrain.tsx` | `{ shape, model }` · `{ 'signal-edge': SignalEdge }` |
| AI canvas | `components/ai-elements/{canvas,node,edge,controls}.tsx` | generic primitives |

## Works With

| Skill      | Load when                                                                                    |
|------------|----------------------------------------------------------------------------------------------|
| `/react19` | Custom nodes/edges are React components — ref-as-prop, transitions for non-blocking updates.  |
| `/typedb`  | Edge weights render `path.strength` / `path.resistance`; query highways for layout. |
| `/astro`   | Graph pages are Astro routes — mount `client:only="react"` (the canvas cannot SSR).        |
| `/shadcn`  | Side panels, node detail sheets, toolbars.           |
| `/puck`    | `OrgChartView` and `WorkflowFlow` are lazy-loaded as Puck blocks in `lib/puck/config.tsx`. |

Every node/edge click emits `emitClick('ui:<surface>:<action>')` from
`@/lib/ui-signal` — see `.claude/rules/ui.md`. `rules/design.md` auto-loads on
these files too: a canvas is not exempt from the 6-token system.

## When to Use This Skill

- Add a custom node or edge type to an existing canvas
- Build a new graph surface over substrate data
- Fix a node component that fails `tsc` on `NodeProps`
- Lay out a graph with dagre or a hand-rolled tier layout
- Style a canvas so it follows the workspace brand tokens

## Installation

Already installed — do not re-add:

```
@xyflow/react   ^12.10.2   (one.ie/web/package.json)
@dagrejs/dagre  ^3.0.0     (used by components/data/TypesCanvas.tsx)
```

## Core Setup

Register node and edge types as **module-level constants**. Defining them inside
the component body creates a new object identity every render and ReactFlow
remounts every node.

```tsx
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  Panel,
  useNodesState,
  useEdgesState,
  type Node,
  type Edge,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

import { TriggerNode } from './nodes/TriggerNode';
import { AgentNode } from './nodes/AgentNode';

const NODE_TYPES = { trigger: TriggerNode, agent: AgentNode };

export function FlowCanvas({ initialNodes, initialEdges }: {
  initialNodes: Node[];
  initialEdges: Edge[];
}) {
  const [nodes, , onNodesChange] = useNodesState(initialNodes);
  const [edges, , onEdgesChange] = useEdgesState(initialEdges);

  return (
    <div className="h-full w-full bg-background">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={NODE_TYPES}
        fitView
        panOnScroll
        proOptions={{ hideAttribution: true }}
      >
        <Background bgColor="var(--sidebar)" />
        <Controls showInteractive={false} />
        <MiniMap pannable zoomable />
      </ReactFlow>
    </div>
  );
}
```

`proOptions={{ hideAttribution: true }}` is on every canvas in the repo.
`<Background>` takes `bgColor` as a CSS value — pass a token var, never a hex.

## Custom Nodes

### The v12 typing pattern

`NodeProps` in v12 is **not** generic over your data interface. `NodeProps<T>`
expects a `Node` type, so `NodeProps<AgentNodeData>` fails to compile. Every node
in this repo uses the same intersection instead:

```tsx
import { Handle, Position, type NodeProps } from '@xyflow/react';

export interface StepNodeData {
  name: string;
  kind: string;
  paused?: boolean;
  [key: string]: unknown;   // required — v12 constrains node data to Record<string, unknown>
}

export type StepNodeProps = Omit<NodeProps, 'data'> & { data: StepNodeData };
```

The `[key: string]: unknown` index signature is mandatory. Without it TypeScript
rejects the type when ReactFlow assigns it into `Node['data']`.

For edges the equivalent is an interface extension:

```tsx
import type { EdgeProps } from '@xyflow/react';

export interface SignalEdgeData {
  strength: number;
  resistance: number;
  traversals: number;
  isHighway?: boolean;
  [key: string]: unknown;
}

interface Props extends EdgeProps {
  data: SignalEdgeData;
}
```

`data` can arrive undefined on a freshly-connected edge — every real edge in the
repo defaults it: `const d = data ?? { strength: 1, resistance: 0, traversals: 0 }`.

### A step node

Nodes share a presentational shell so the card, badge, and handle styling live in
one place. `components/workflows/nodes/StepNodeShell.tsx` is that shell; the eight
kind nodes are ~8 lines each.

```tsx
// components/workflows/nodes/TriggerNode.tsx — the whole file
import { STEP_VISUAL } from '../step-visual';
import { StepNodeShell, type StepNodeProps } from './StepNodeShell';

const { icon, tone, label } = STEP_VISUAL.trigger;

/** Trigger — the workflow's entry point. No inbound handle (nothing precedes it). */
export function TriggerNode({ data }: StepNodeProps) {
  return <StepNodeShell icon={icon} label={label} accent={tone} data={data} hasTarget={false} />;
}
```

The shell renders a token-styled card and a shared `StepHandle`:

```tsx
import { Handle, Position } from '@xyflow/react';
import type { LucideIcon } from 'lucide-react';

export function StepHandle({ type, position, id, color }: {
  type: 'source' | 'target';
  position: Position;
  id?: string;
  color: string;
}) {
  const edge = position === Position.Top ? { top: -5 } : { bottom: -5 };
  return (
    <Handle
      type={type}
      id={id}
      position={position}
      style={{
        width: 9,
        height: 9,
        background: color,
        border: '2px solid var(--color-background)',
        ...edge,
      }}
    />
  );
}
```

Node colors come from the token vars, resolved from an accent name. The shell
receives the lucide component as a prop and renames it to a capitalized local so
JSX treats it as a component, not an intrinsic element:

```tsx
// inside StepNodeShell({ icon: Icon, accent, ... }: { icon: LucideIcon; accent: Accent; ... })
type Accent = 'primary' | 'secondary' | 'tertiary' | 'font';
const color = `var(--color-${accent})`;

<article
  className="bg-background border rounded-2xl w-[200px] flex flex-col relative"
  style={{ borderColor: 'var(--color-border)', boxShadow: 'var(--shadow-card)' }}
>
  <span style={{ background: `color-mix(in oklab, ${color} 18%, transparent)`, color }}>
    <Icon size={15} strokeWidth={1.75} />
  </span>
</article>
```

Never write a hex or a Tailwind palette class inside a node. `PathGraph.tsx`
still carries four hex literals (lines 27–29, 55) — it predates the design hook
and is a known offender, not a pattern to copy.

## Building the graph from substrate data

Graph data is derived in a **pure module** with no React and no xyflow runtime
import, so it is unit-testable. `components/paths/path-flow.ts` is the reference:

```ts
import type { Edge, Node } from '@xyflow/react';

export interface PathRow {
  from: string;
  to: string;
  fromName?: string;
  toName?: string;
  strength: number;
  resistance: number;
  traversals: number;
}

export function toFlow(paths: PathRow[]): { nodes: Node[]; edges: Edge[] } {
  const actors = [...new Set(paths.flatMap(p => [p.from, p.to]))];

  const nodes: Node[] = actors.map((id, i) => ({
    id,
    type: 'role',
    position: { x: (i % 4) * 260, y: Math.floor(i / 4) * 200 },
    data: { name: id },
  }));

  const edges: Edge[] = paths.map(p => ({
    id: `${p.from}-${p.to}`,
    source: p.from,
    target: p.to,
    type: 'path',
    animated: p.traversals > 0,
    data: { strength: p.strength, resistance: p.resistance, traversals: p.traversals },
  }));

  return { nodes, edges };
}
```

Edge weight maps to stroke width and token color — the visual encoding of
`strength` vs `resistance`, straight from `components/org/SignalEdge.tsx`:

```tsx
function strokeWidth(strength: number): number {
  return Math.max(1, Math.min(8, Math.log2(strength + 1) * 2));
}

function strokeColor(data: SignalEdgeData): string {
  if (data.isHighway) return 'var(--color-tertiary)';
  if (data.resistance > data.strength) return 'var(--color-secondary)';
  return 'var(--color-primary)';
}
```

## Interactive Flow Canvas

An editable canvas adds `onConnect`, a click handler, and gating props. Note the
handler signature: `onNodeClick` receives `(event, node)` and `node` must be
imported as a type — omitting the import is the most common tsc failure here.

```tsx
import { useCallback } from 'react';
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  Panel,
  addEdge,
  useNodesState,
  useEdgesState,
  type Connection,
  type Node,
  type Edge,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { emitClick } from '@/lib/ui-signal';
import { TriggerNode } from './nodes/TriggerNode';
import { AgentNode } from './nodes/AgentNode';
import { PathEdge } from './PathEdge';

const NODE_TYPES = { trigger: TriggerNode, agent: AgentNode };
const EDGE_TYPES = { path: PathEdge };

interface Props {
  initialNodes: Node[];
  initialEdges: Edge[];
  editable?: boolean;
  onNodeOpen?: (id: string) => void;
}

export function InteractiveFlowCanvas({
  initialNodes,
  initialEdges,
  editable = false,
  onNodeOpen,
}: Props) {
  const [nodes, , onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);

  const onConnect = useCallback(
    (connection: Connection) => {
      setEdges(eds => addEdge({ ...connection, animated: true }, eds));
    },
    [setEdges]
  );

  const onNodeClick = useCallback(
    (_: React.MouseEvent, node: Node) => {
      emitClick('ui:graph:open', { id: node.id });
      onNodeOpen?.(node.id);
    },
    [onNodeOpen]
  );

  return (
    <div className="h-full w-full">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onNodeClick={onNodeClick}
        nodeTypes={NODE_TYPES}
        edgeTypes={EDGE_TYPES}
        nodesDraggable={editable}
        nodesConnectable={editable}
        edgesReconnectable={false}
        deleteKeyCode={editable ? ['Backspace', 'Delete'] : null}
        fitView
        panOnScroll
        proOptions={{ hideAttribution: true }}
      >
        <Background bgColor="var(--sidebar)" />
        <MiniMap pannable zoomable />
        <Controls showInteractive={false} />
        {editable && <Panel position="top-left">{/* toolbar */}</Panel>}
      </ReactFlow>
    </div>
  );
}
```

`deleteKeyCode={null}` is how a read-only canvas blocks node deletion — there is
no `deletable` prop on `<ReactFlow>`.

## Custom Edges

`LifecycleFlow.tsx` picks its path function from edge data and animates a dot
along it with SVG `animateMotion`:

```tsx
import {
  BaseEdge,
  EdgeLabelRenderer,
  getBezierPath,
  getStraightPath,
  type EdgeProps,
} from '@xyflow/react';

interface EdgeData extends Record<string, unknown> {
  kind: 'forward' | 'loop';
  flow?: boolean;
  showLabel?: boolean;
  label?: string;
}

function LifecycleEdge({
  sourceX, sourceY, targetX, targetY,
  sourcePosition, targetPosition, markerEnd, style, data,
}: EdgeProps) {
  const d = data as EdgeData | undefined;
  const [path, labelX, labelY] =
    d?.kind === 'forward'
      ? getStraightPath({ sourceX, sourceY, targetX, targetY })
      : getBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition });

  return (
    <>
      <BaseEdge path={path} markerEnd={markerEnd} style={style} />
      {d?.flow && (
        <circle r={3.5} fill="var(--color-primary)">
          <animateMotion dur="2.4s" repeatCount="indefinite" path={path} />
        </circle>
      )}
      {d?.showLabel && d?.label && (
        <EdgeLabelRenderer>
          <div
            className="pointer-events-none px-2 py-0.5 rounded-full text-xs font-semibold bg-background border text-font/80 whitespace-nowrap"
            style={{
              position: 'absolute',
              transform: `translate(-50%,-50%) translate(${labelX}px,${labelY}px)`,
              borderColor: 'var(--color-border)',
              boxShadow: 'var(--shadow-card)',
            }}
          >
            {d.label}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
}
```

`getBezierPath` needs `sourcePosition` and `targetPosition`; `getStraightPath`
takes only the four coordinates. Passing the extra keys to `getStraightPath` is
harmless but passing too few to `getBezierPath` yields a degenerate path.

## Edge Types Registration

```tsx
import { LifecycleEdge } from './LifecycleEdge';

const EDGE_TYPES = { lifecycle: LifecycleEdge };

<ReactFlow edgeTypes={EDGE_TYPES} /* ... */ />
```

Module scope, same as `NODE_TYPES`. An edge opts in via `type: 'lifecycle'` in
its `Edge` object.

## Auto-Layout with dagre

`components/data/TypesCanvas.tsx` is the only dagre consumer. It falls back to a
grid when there are no edges — dagre on a disconnected graph stacks everything at
the origin:

```ts
import dagre from '@dagrejs/dagre';
import type { Node, Edge } from '@xyflow/react';

const NODE_WIDTH = 240;
const NODE_HEIGHT = 160;

function dagreLayout(nodes: Node[], edges: Edge[]): Node[] {
  const g = new dagre.graphlib.Graph();
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: 'LR', ranksep: 120, nodesep: 60 });
  for (const node of nodes) g.setNode(node.id, { width: NODE_WIDTH, height: NODE_HEIGHT });
  for (const edge of edges) g.setEdge(edge.source, edge.target);
  dagre.layout(g);
  return nodes.map(node => {
    const { x, y } = g.node(node.id);
    return { ...node, position: { x: x - NODE_WIDTH / 2, y: y - NODE_HEIGHT / 2 } };
  });
}

const GRID_COLS = 3;

function gridLayout(nodes: Node[]): Node[] {
  return nodes.map((node, i) => ({
    ...node,
    position: { x: (i % GRID_COLS) * 300 + 32, y: Math.floor(i / GRID_COLS) * 220 + 32 },
  }));
}

export function layoutNodes(nodes: Node[], edges: Edge[]): Node[] {
  return edges.length === 0 ? gridLayout(nodes) : dagreLayout(nodes, edges);
}
```

Build the graph fresh per call — a module-level `dagre.graphlib.Graph()` reused
across renders accumulates stale nodes.

For a known hierarchy, skip dagre. `OrgChartView` and `SignalGraph` place tiers
on fixed rows:

```ts
const ROW_Y: Record<Tier, number> = {
  chairman: 0, ceo: 260, director: 560, specialist: 880,
};
```

## Astro Page with ReactFlow

Always `client:only="react"` — the canvas measures the DOM and cannot SSR.
`client:load` renders an empty container on the server and flashes.

```astro
---
// src/pages/org/index.astro
export const prerender = false;
import Layout from "@/layouts/Layout.astro";
import { OrgChartView } from "@/components/org/OrgChartView";
---

<Layout title="Org chart">
  <div class="h-screen">
    <OrgChartView chart="complete" client:only="react" />
  </div>
</Layout>
```

The parent must have a resolved height. ReactFlow measures its container; inside
a `h-auto` wrapper it collapses to zero and renders nothing.

## Real-time Updates

Do not poll and do not hand-roll an event emitter. A resolver mutation anywhere —
UI, chat, MCP, CLI — broadcasts one SSE frame that every mounted surface on that
dimension receives:

```tsx
import { useCallback } from 'react';
import { useNodesState, useEdgesState, ReactFlow, type Node, type Edge } from '@xyflow/react';
import { useSurfaceRefresh } from '@/lib/use-surface-refresh';
import { buildGraph, type WorkflowDef } from './build-graph';

export function WorkflowCanvas({ slug, workflowId }: { slug: string; workflowId: string }) {
  const [nodes, setNodes] = useNodesState<Node>([]);
  const [edges, setEdges] = useEdgesState<Edge>([]);

  const reload = useCallback(() => {
    fetch(`/api/workflows/${workflowId}?slug=${slug}`)
      .then(r => r.json() as Promise<{ data?: WorkflowDef }>)
      .then(d => {
        if (!d.data) return;
        const g = buildGraph(d.data);
        setNodes(g.nodes);
        setEdges(g.edges);
      })
      .catch(() => {});
  }, [slug, workflowId, setNodes, setEdges]);

  useSurfaceRefresh(slug, 'workflows', reload);

  return <ReactFlow nodes={nodes} edges={edges} /* ... */ />;
}
```

## Best Practices

1. **Registries at module scope**: `NODE_TYPES` / `EDGE_TYPES` defined in the
   component body remount every node on every render.
2. **`Omit<NodeProps,'data'> & { data: T }`**: the v12 pattern. `NodeProps<T>`
   does not compile with a bare data interface.
3. **Index-signature your data types**: `[key: string]: unknown`, or the type is
   rejected at `Node['data']`.
4. **Tokens inside the canvas too**: `var(--color-primary)`, `color-mix(...)`,
   `var(--color-border)`. Never a hex, never a palette class.
5. **`client:only="react"`, sized parent**: the canvas cannot SSR and collapses
   without a resolved height.
6. **Derive the graph in a pure module**: no React, no xyflow runtime import — so
   it can be unit-tested.
7. **Default undefined edge `data`**: a newly-connected edge has none.
8. **`emitClick` before the handler**: node and edge clicks are signals.
9. **`proOptions={{ hideAttribution: true }}`**: on every canvas in the repo.

---

**Tech**: @xyflow/react 12.10.2 · @dagrejs/dagre 3.0 · React 19.2.6 · Astro 6.3.7
**Tree**: `one.ie/web` — 25 importing files under `src/components/`
