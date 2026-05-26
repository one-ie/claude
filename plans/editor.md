# Markdown Editor — Options

**Goal:** Beautiful, web-page-quality markdown rendering that is also editable. Supports inline React components (ReactFlow diagrams, AI widgets), streaming AI responses, and feels like reading a polished document — not a textarea.

**Stack context:** Astro 6 + React 19 + Tailwind 4 + shadcn/ui + CF Workers

---

## The Core Tension

| Mode | Feels like | Inline components | Streaming | Complexity |
|------|-----------|-------------------|-----------|-----------|
| WYSIWYG (ProseMirror) | Google Docs | ✅ custom nodes | ✅ insert chars | high |
| Source + live preview | VS Code split | ✅ MDX renderer | ✅ natural | medium |
| Inline MDX render | Notion | ✅ native | ✅ with delta | medium |

---

## Option A — Novel (Tiptap + AI-ready)

**What it is:** Notion-style WYSIWYG built on Tiptap (ProseMirror). Slash commands, bubble menu, AI completion built in. shadcn-compatible headless styles.

**Rendering:** ProseMirror schema → HTML. Looks like a real document. Typography class from `@tailwindcss/typography` makes it web-page quality instantly.

**Inline React components:** Tiptap NodeView — wrap any React tree (including `<ReactFlowProvider>`) as a custom node. The node serializes to a placeholder in markdown; on load it re-hydrates.

**Streaming:** `useCompletion` from `ai` SDK writes tokens into the editor transaction stream. Novel already ships an `AIHighlight` extension for this pattern.

**Tradeoffs:**
- ✅ Most beautiful out of the box (Notion DNA)
- ✅ AI streaming already solved — ships with `@tiptap/extension-ai`
- ✅ Active ecosystem, shadcn integration, good TS types
- ⚠️ Markdown ↔ ProseMirror serialization is lossy at edges (tables, footnotes)
- ⚠️ Novel is opinionated — diverging from defaults adds weight

**Install:** `novel`, `@tiptap/react`, `@tiptap/starter-kit`

---

## Option B — Milkdown (Markdown-native WYSIWYG)

**What it is:** Editor built on ProseMirror + Remark. Markdown is the canonical format — the schema is derived from the remark AST, not the other way around. Editing always produces valid markdown.

**Rendering:** Remark pipeline → ProseMirror → DOM. Tables, footnotes, GFM all correct because Remark handles parsing.

**Inline React components:** `@milkdown/react` + Crepe framework. Custom nodes can mount React trees. Less turnkey than Tiptap NodeView but more markdown-accurate.

**Streaming:** Insert tokens at cursor via `milkdown.action(insert(token))`. Streaming into a read-only Milkdown view (then making it editable) is the clean pattern.

**Tradeoffs:**
- ✅ Markdown is always the source of truth — no roundtrip loss
- ✅ Remark ecosystem: rehype, remark-math, remark-mdx all plug in
- ✅ Cleaner for AI output (model emits markdown, editor accepts it natively)
- ⚠️ Smaller community than Tiptap
- ⚠️ React component embedding is less ergonomic than Tiptap NodeView
- ⚠️ Crepe (the new DX layer) is still maturing

**Install:** `@milkdown/core`, `@milkdown/react`, `@milkdown/preset-commonmark`

---

## Option C — Lexical (Meta, React-native)

**What it is:** Meta's replacement for Draft.js. No ProseMirror dependency — custom reconciler. React-first, very performant, built for large documents.

**Rendering:** Lexical node tree → React. Custom `LexicalMarkdownPlugin` for md parsing. The `@lexical/markdown` package handles import/export.

**Inline React components:** `DecoratorNode` — any React component. Clean API. ReactFlow inside a Lexical node is straightforward.

**Streaming:** `editor.update(() => $insertNodes([...]))` — fine-grained control, can insert character by character or in chunks. No built-in AI extension but the primitives are cleaner than ProseMirror.

**Tradeoffs:**
- ✅ Best React 19 alignment (same team, same model)
- ✅ Most performant on large documents
- ✅ Streaming primitives are the cleanest of all options
- ✅ No ProseMirror — lighter mental model
- ⚠️ Most setup work — no opinionated UI layer
- ⚠️ Markdown rendering requires `@lexical/markdown` + custom nodes for full GFM
- ⚠️ No shadcn integration out of the box

**Install:** `lexical`, `@lexical/react`, `@lexical/markdown`

---

## Option D — CodeMirror 6 + MDX Renderer (separated concerns)

**What it is:** Two panels or one toggled surface. CodeMirror 6 edits raw markdown/MDX source; a separate React tree renders it via `next-mdx-remote` or `@mdx-js/mdx`. Not WYSIWYG — but very stable.

**Rendering:** Full MDX → React render. Any component in the `components` map is live. ReactFlow renders exactly as it would in production.

**Inline React components:** Native MDX — `<Flow data={...} />` in the markdown source just works. No custom node machinery.

**Streaming:** Append tokens to source string → debounced re-render of preview. Or stream directly into CodeMirror dispatch. Very natural.

**Tradeoffs:**
- ✅ Zero rendering loss — what you see IS production output
- ✅ Inline components are first-class (MDX)
- ✅ Streaming is trivial (string append)
- ✅ Simplest architecture — no editor schema to maintain
- ⚠️ Not WYSIWYG — two panes or toggle mode
- ⚠️ Re-parsing MDX on every keystroke needs debounce + error boundary
- ⚠️ CodeMirror is powerful but markdown highlighting needs `@codemirror/lang-markdown`

**Install:** `@codemirror/view`, `@codemirror/lang-markdown`, `@mdx-js/mdx`

---

## Option E — Plate.js (Slate.js, headless, plugin-heavy)

**What it is:** Headless editor framework built on Slate.js. Massive plugin library — markdown, tables, callouts, links, math, drag-and-drop. Used by Vercel, Dub, others.

**Rendering:** Slate model → React nodes. `@udecode/plate-markdown` for serialization.

**Inline React components:** Plate element components — any React tree. Well-documented pattern.

**Streaming:** Insert at selection via Slate transforms. Community AI plugin exists.

**Tradeoffs:**
- ✅ Richest plugin ecosystem of any option
- ✅ Fully headless — bring your own styles
- ✅ React 19 support confirmed in Plate v40+
- ⚠️ Heavy — the plugin map grows fast
- ⚠️ Slate.js has had stability issues historically; Plate adds a maintenance layer
- ⚠️ Markdown serialization is less accurate than Milkdown

**Install:** `@udecode/plate`, `@udecode/plate-markdown`, `@udecode/plate-basic-elements`

---

## Comparison Matrix

| | Novel | Milkdown | Lexical | CodeMirror+MDX | Plate |
|---|---|---|---|---|---|
| Beauty out-of-box | ★★★★★ | ★★★★ | ★★★ | ★★★★ | ★★★ |
| Markdown fidelity | ★★★ | ★★★★★ | ★★★ | ★★★★★ | ★★★ |
| Inline React components | ★★★★ | ★★★ | ★★★★ | ★★★★★ | ★★★★ |
| Streaming AI | ★★★★★ | ★★★★ | ★★★★★ | ★★★★★ | ★★★ |
| ReactFlow integration | ★★★★ | ★★★ | ★★★★ | ★★★★★ | ★★★★ |
| Simplicity / stability | ★★★ | ★★★★ | ★★★ | ★★★★★ | ★★ |
| React 19 fit | ★★★★ | ★★★ | ★★★★★ | ★★★★★ | ★★★★ |

---

## Recommendation

**Primary: Novel for AI chat + document editing**

Novel gives the best out-of-box experience for the AI streaming use case. The editor looks like a real web page immediately (`prose` class). Tiptap NodeViews handle ReactFlow diagrams. The AI extension already wires streaming into the editor protocol.

**Secondary: CodeMirror + MDX for structured content / agent outputs**

When the content is agent-generated markdown with embedded `<Flow />` components — where fidelity matters more than WYSIWYG feel — CodeMirror source + MDX render panel is the simpler and more stable choice. No editor schema to fight.

**The combination:**

```
AI chat response → stream into Novel editor → user edits prose inline
Agent-generated report → render as MDX → CodeMirror source toggle
ReactFlow diagrams → Tiptap NodeView (Novel) or <Flow /> in MDX
```

---

## Implementation sketch (Novel path)

```tsx
// packages/react/src/components/Editor.tsx
import { Editor } from 'novel'
import { ReactFlowNode } from './extensions/ReactFlowNode'

export function OneEditor({ content, onUpdate, streaming }: Props) {
  return (
    <Editor
      defaultValue={content}
      extensions={[ReactFlowNode]}
      onUpdate={({ editor }) => onUpdate(editor.storage.markdown.getMarkdown())}
      className="prose prose-neutral dark:prose-invert max-w-none"
    />
  )
}
```

```tsx
// Streaming AI response into the editor
const { completion, complete } = useCompletion({ api: '/api/signal' })
useEffect(() => {
  if (completion) editor.commands.setContent(completion)
}, [completion])
```

---

## Next steps

1. Pick primary option (Novel or CodeMirror+MDX)
2. Create `one.ie/web/src/components/editor/` — `Editor.tsx`, `extensions/`, `toolbar/`
3. Wire streaming: `useCompletion` → editor update
4. Add ReactFlow node (NodeView for Novel; `<Flow />` component for MDX)
5. Style with `@tailwindcss/typography` + shadcn tokens

If going Novel: `bun add novel @tiptap/react @tiptap/starter-kit @tailwindcss/typography`
If going CodeMirror+MDX: `bun add @codemirror/view @codemirror/lang-markdown @mdx-js/mdx @mdx-js/react`
