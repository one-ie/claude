---
name: react19
description: React 19 patterns as they are actually used in `one.ie/web` — Actions/useActionState, use(), useTransition, useOptimistic, ref-as-prop, document metadata — plus the repo's real async surfaces (props from the Astro page, SSE via useSurfaceRefresh, fetch-in-effect). Use when writing or reviewing a .tsx island in one.ie/web, choosing between a transition and an Action for a form, or deciding how a client component gets its data.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
---

# React 19 Development

React 19 patterns for the interactive islands in `one.ie/web/src/components/`.

Installed: **React 19.2.6** (declared `^19.1.0`), rendered by **Astro 6.3.7** on
Cloudflare Workers. `template/site` is a separate tree on Astro 7 — use the
`template:react19` skill there.

For prop typing, file structure, `cn()` styling, `useState`/`useReducer` choice,
and named-vs-default exports, read `.claude/rules/react.md`. It auto-loads on
every `*.tsx` and is already in context when you edit — this skill does not
repeat it.

## Works With

| Skill        | Load when                                                                        |
|--------------|----------------------------------------------------------------------------------|
| `/shadcn`    | Using Card, Tabs, Badge, Dialog — primitives under the 6-token system. |
| `/astro`     | The component lives in an Astro page — hydration directives (`client:load`, `client:idle`, `client:only`) decide worker bundle size. |
| `/puck`      | Block `render` fns are React components; the editor is a `client:only` island. |
| `/reactflow` | Graph islands — WorkflowFlow, OrgChartView, LifecycleFlow, PathGraph. |
| `/ai-ui`     | Agent reasoning UIs, tool-call visualization, generative components. |

Every semantic `onClick` emits `emitClick('ui:<surface>:<action>')` from
`@/lib/ui-signal`. That contract lives in `.claude/rules/ui.md`, which auto-loads
on `one.ie/web/src/components/**/*.tsx`. There is no `/signal` skill.

Rules auto-load via each rule file's own `paths:` frontmatter (not
`settings.json`, which wires hooks only): `rules/react.md` on `**/*.tsx`,
`rules/ui.md` on `one.ie/web/src/components/**/*.tsx`, `rules/design.md` on
`one.ie/web/**/*.{tsx,astro,css}`.

## When to Use This Skill

- Build a React island in `one.ie/web/src/components/`
- Implement form handling with Actions
- Use `use()` for promises/context
- Apply transitions for non-blocking updates
- Decide how a client component gets its data (SSE, fetch-in-effect, or props)

## Key React 19 Features

Adoption in `one.ie/web` is deliberate, not uniform. Before reaching for a
feature, know where it already lives:

| Feature | Files using it in `one.ie/web/src` |
|---|---|
| `useTransition` | 7 — the auth forms, `SubscribeForm`, `CampaignCardRenderer` |
| `useActionState` | 1 — `components/peer/VideoRoomManager.tsx` |
| `useDeferredValue` | 2 |
| `useSyncExternalStore` | 2 |
| `useReducer` | 1 |
| `useOptimistic` | **0** — no in-repo precedent |
| `forwardRef` | **0** — fully migrated to ref-as-prop |

### 1. Actions (Form Handling)

`useActionState` returns `[state, dispatch, isPending]`. The real usage in
`VideoRoomManager.tsx` posts through `ask()` from `@/lib/in/ask`:

```tsx
import { useActionState } from 'react';
import { ask } from '@/lib/in/ask';

interface CreateRoomState {
  ok: boolean;
  error?: string;
  slug?: string;
}

async function createRoom(
  _prev: CreateRoomState | null,
  formData: FormData
): Promise<CreateRoomState> {
  const name = formData.get('name') as string;
  const slug = formData.get('slug') as string;
  try {
    await ask('room:create', { name, slug });
    return { ok: true, slug };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

export function CreateRoomForm() {
  const [state, dispatch, isPending] = useActionState(createRoom, null);

  return (
    <form action={dispatch} className="space-y-3">
      <input name="name" placeholder="Room name" disabled={isPending} />
      <input name="slug" placeholder="room-slug" disabled={isPending} />
      <button type="submit" disabled={isPending}>
        {isPending ? 'Creating…' : 'Create room'}
      </button>
      {state?.error && <p className="text-destructive text-sm">{state.error}</p>}
      {state?.ok && <p className="text-success text-sm">Created {state.slug}</p>}
    </form>
  );
}
```

The initial state is `null` in the real call, so every read is `state?.field`.
If you initialise with an object instead, type it and drop the optional chain —
but be consistent within one component.

### 2. use() Hook

`use()` reads a promise or a context. **No component in `one.ie/web` uses it
today** — islands hydrate with props from the Astro page, or fetch in an effect.
Introduce it only when you also introduce the `<Suspense>` boundary and a stable
promise; a promise recreated each render suspends forever.

```tsx
import { use, Suspense } from 'react';

interface Stats { actors: number; signals: number }

function StatsDisplay({ statsPromise }: { statsPromise: Promise<Stats> }) {
  const stats = use(statsPromise); // suspends until resolved

  return (
    <div>
      <h2>Actors: {stats.actors}</h2>
      <h2>Signals: {stats.signals}</h2>
    </div>
  );
}

// The promise must be created OUTSIDE the suspending component —
// created in render, it is a new promise every attempt.
export function StatsContainer({ statsPromise }: { statsPromise: Promise<Stats> }) {
  return (
    <Suspense fallback={<div>Loading…</div>}>
      <StatsDisplay statsPromise={statsPromise} />
    </Suspense>
  );
}
```

Reading context with `use()` is the safe half — it may be called conditionally,
unlike `useContext`:

```tsx
import { use } from 'react';
import { EditorSlugContext } from '@/components/puck/editor-slug-context';

function BlockInspector({ enabled }: { enabled: boolean }) {
  if (!enabled) return null;
  const slug = use(EditorSlugContext); // legal after an early return
  return <span>{slug}</span>;
}
```

### 3. Transitions

The repo's most-used React 19 primitive. `SubscribeForm` and the auth pages wrap
their submit in `startTransition` so the button stays responsive:

```tsx
import { useState, useTransition } from 'react';
import { emitClick } from '@/lib/ui-signal';

interface Actor { id: string; name: string }

export function ActorTabs({ actors }: { actors: Actor[] }) {
  const [selected, setSelected] = useState(actors[0]?.id);
  const [isPending, startTransition] = useTransition();

  const actor = actors.find(a => a.id === selected);

  return (
    <div>
      <div className="flex gap-2">
        {actors.map(a => (
          <button
            key={a.id}
            onClick={() => {
              emitClick('ui:actors:select', { id: a.id });
              startTransition(() => setSelected(a.id));
            }}
            className={a.id === selected ? 'bg-primary text-on-primary' : ''}
          >
            {a.name}
          </button>
        ))}
      </div>
      <div className={isPending ? 'opacity-50' : ''}>
        {actor && <ActorContent actor={actor} />}
      </div>
    </div>
  );
}
```

### 4. Optimistic Updates

`useOptimistic` has **no precedent in this repo** — treat an introduction as a
new pattern and keep it inside one component. It only reverts correctly when the
update runs inside an Action or a transition; calling it from a bare event
handler throws.

```tsx
import { useOptimistic } from 'react';
import { ask } from '@/lib/in/ask';

interface Task { id: string; title: string; status: string }

export function TaskList({ tasks }: { tasks: Task[] }) {
  const [optimisticTasks, addOptimisticTask] = useOptimistic(
    tasks,
    (state: Task[], next: Task) => [...state, next]
  );

  // Must be a form action (or wrapped in startTransition) — not a plain onClick.
  async function createTask(formData: FormData) {
    const title = formData.get('title') as string;
    addOptimisticTask({ id: `temp-${Date.now()}`, title, status: 'pending' });
    await ask('tasks:create', { title });
  }

  return (
    <div>
      <form action={createTask}>
        <input name="title" />
        <button type="submit">Add</button>
      </form>
      <ul>
        {optimisticTasks.map(t => (
          <li key={t.id} className={t.id.startsWith('temp-') ? 'opacity-50' : ''}>
            {t.title}: {t.status}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

The optimistic entry disappears on its own when the Action settles and the real
`tasks` prop updates — do not remove it by hand.

### 5. ref as Prop

`forwardRef` is fully retired here — zero occurrences in
`one.ie/web/src/components/`. Declare `ref` as an ordinary prop:

```tsx
interface InputProps {
  ref?: React.Ref<HTMLInputElement>;
  placeholder?: string;
}

function Input({ ref, ...props }: InputProps) {
  return <input ref={ref} {...props} />;
}

function Form() {
  const inputRef = useRef<HTMLInputElement>(null);
  return <Input ref={inputRef} placeholder="Receiver" />;
}
```

### 6. Document Metadata

React 19 hoists `<title>` and `<meta>` from anywhere in the tree. In this repo
that is almost always the wrong layer — the Astro page owns the head, and an
island rendered `client:only` will not produce metadata for the SSR response or
for a crawler. Use it only for a genuinely client-routed sub-view.

```tsx
interface Room { id: string; name: string }

function RoomView({ room }: { room: Room }) {
  return (
    <div>
      <title>{room.name}</title>
      <h1>{room.name}</h1>
    </div>
  );
}
```

## Project-Specific Patterns

### How an island gets its data

Three real paths, in order of preference:

**1. Props from the Astro page (default).** The page runs SSR, queries, and
passes plain data across the island boundary. No client fetch, no loading state.

```astro
---
export const prerender = false;
import { OrgChartView } from '@/components/org/OrgChartView';
---
<OrgChartView chart="marketing" client:only="react" />
```

**2. Live refresh over SSE — `useSurfaceRefresh`.** A resolver mutation from
anywhere (UI, chat, MCP, CLI) broadcasts one frame; every mounted surface on that
dimension re-pulls. This is the repo's answer to "keep the view fresh", and it
replaces polling:

```tsx
import { useState, useCallback } from 'react';
import { useSurfaceRefresh } from '@/lib/use-surface-refresh';

interface Workflow { id: string; name: string }

export function WorkflowList({ slug }: { slug: string }) {
  const [rows, setRows] = useState<Workflow[]>([]);

  const reload = useCallback(() => {
    fetch(`/api/workflows?slug=${slug}`)
      .then(r => r.json() as Promise<{ data?: Workflow[] }>)
      .then(d => setRows(d.data ?? []))
      .catch(() => {});
  }, [slug]);

  useSurfaceRefresh(slug, 'workflows', reload);

  return <ul>{rows.map(w => <li key={w.id}>{w.name}</li>)}</ul>;
}
```

`useSurfaceRefresh(slug, dimension, onRefresh)` subscribes to the `inbox:{slug}`
topic on `/api/analytics/watch` and fires only for `surface:refresh` frames
matching `dimension`. It handles reconnect backoff and debounce itself.

**3. Fetch in an effect.** Still the common shape for one-shot loads
(`VideoRoomManager` does this). Acceptable; just keep the `.catch(() => {})` so a
failed load never leaves an unhandled rejection in a Worker.

### @oneie/react — for consumers, not for this app

`packages/react/` publishes `@oneie/react`: `SubstrateProvider` + `useSubstrate`,
**10 data hooks** (`useAgent`, `useAgentList`, `useDiscover`, `useHealth`,
`useHighways`, `useRecall`, `useRevenue`, `useStats`, `useWallet`, `useFn`), two
optimistic helpers (`useOptimisticMark`, `useOptimisticPay`), and two stream
helpers (`streamChat`, `streamTail`).

**`one.ie/web` does not depend on `@oneie/react`.** Its only `@oneie` dependency
is `@oneie/sdk` (`file:../../packages/sdk`). Do not import these hooks into a web
component — the package is for external apps embedding the substrate. Inside
this app, use the three data paths above.

## TypeScript Patterns

### Event Handlers

```tsx
function handleClick(e: React.MouseEvent<HTMLButtonElement>) {
  e.preventDefault();
}

function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
  const value = e.target.value;
}

function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault();
}
```

With an Action you do not write `handleSubmit` at all — `<form action={dispatch}>`
receives `FormData` directly and never needs `preventDefault`.

## Best Practices

1. **Props before fetch**: let the Astro page do the query; hydrate with data.
2. **`useSurfaceRefresh` before polling**: one SSE topic already carries every
   resolver mutation.
3. **Actions for forms**: `<form action={dispatch}>` beats a manual `onSubmit`.
4. **Transitions for tabs and filters**: the repo's most-used React 19 primitive.
5. **`use()` needs a stable promise**: created in render, it never resolves.
6. **`useOptimistic` only inside an Action or transition**: it throws otherwise.
7. **Never import `@oneie/react` into `one.ie/web`**: it is not a dependency.
8. **Emit the click signal first**: `emitClick(...)` then the local handler.

---

**Tech**: React 19.2.6 · Astro 6.3.7 · Tailwind 4
**Tree**: `one.ie/web` — for `template/site` (Astro 7) use `template:react19`
