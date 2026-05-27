# markdown.md — streaming markdown spec

One renderer. Two surfaces. Zero switching.

---

## The single renderer

`streamdown` replaces `markdown-to-jsx` as the sole markdown renderer across the app.

**Why:** `streamdown` is built for AI streaming — it handles incomplete syntax mid-stream, provides token-by-token animation via a rehype transformer, and degrades to zero-overhead static rendering when `isAnimating=false`. There is no need to swap renderers between streaming and static states; the same component handles both.

`markdown-to-jsx` is removed. `MarkdownView` is rewritten around `Streamdown` with the same custom element overrides ported to the `components` prop.

---

## MarkdownView rewrite

`one.ie/web/src/components/ai-elements/markdown.tsx`

```tsx
interface MarkdownViewProps {
  children: string
  className?: string
  isAnimating?: boolean   // true while status === 'streaming' on last message
}
```

**Component overrides** (same visual output as before, ported from markdown-to-jsx):

| Element | Override |
|---------|---------|
| `pre` | `CodeBlock` with Shiki; during streaming, `useIsCodeFenceIncomplete()` shows a shimmer instead of broken output |
| `inlineCode` | rounded bg-foreground pill |
| `a` | `target="_blank"` + primary underline |
| `ul / ol / li` | list-disc / list-decimal + spacing |
| `p h1 h2 h3 blockquote table th td hr` | Tailwind class overrides |

**Animation config** (fixed — not user-configurable):

```tsx
animated={{ animation: 'blurIn', duration: 200, easing: 'ease-out' }}
caret="block"
```

`blurIn` is chosen over `fadeIn` because blur masks simultaneous token batch arrivals better — important for fast models.

**Chips stripping** — `stripControlTags()` runs before the string reaches `Streamdown`, unchanged from current implementation.

---

## Chat surface

`one.ie/web/src/components/chat/MessageList.tsx`

`AssistantTextPart` receives `isStreaming: boolean`. Only the last assistant message in the list gets `isStreaming=true` when `status === 'streaming'`. All prior messages render statically (`isAnimating=false`).

```
MessageList (status, messages)
  └─ AssistantTextPart (isStreaming = status==='streaming' && isLast)
       └─ MarkdownView (isAnimating=isStreaming)
            └─ Streamdown (animated, caret, isAnimating)
```

The caret disappears automatically when `isAnimating` flips to `false` — no cleanup needed.

---

## Editor surface

`one.ie/web/src/components/editor/Editor.tsx` (`OneEditor` — Novel/Tiptap)

**Why streaming directly into the editor is wrong:**

Tiptap operates on a ProseMirror AST. Streaming raw markdown tokens word-by-word produces invalid partial syntax (`**bold` mid-stream) — the parser cannot construct proper rich-text nodes from an incomplete stream. Inserting plain text token-by-token produces a typewriter effect in plaintext, losing all formatting.

**The correct pattern: Stream → Accept**

```
streamdown preview zone (animated) → [Accept] → editor.commands.insertContent(html)
```

1. AI response streams into a `streamdown` preview panel (same `MarkdownView` component, `isAnimating=true`)
2. Preview sits above or adjacent to the editor — visually distinct, not yet editable
3. When streaming ends, an **Accept** button appears
4. Accept calls `editor.commands.insertContent(completedHtml)` — Tiptap parses the final HTML into proper rich nodes
5. Preview zone unmounts; content is now live in the editor and fully editable

This is the pattern used by Notion AI, Linear AI, and Cursor. The streaming phase is for reading and reviewing; the editor phase is for editing. They are complementary, not merged.

**Accept seam** — one prop on whatever component hosts both:

```tsx
onStreamComplete?: (html: string) => void
// caller: editor.commands.insertContent(html)
```

---

## CSS

`streamdown/styles.css` imported once in `one.ie/web/src/layouts/Layout.astro`.

No other files import it.

---

## What does not change

- `stripControlTags()` — unchanged, runs before string reaches renderer
- `CodeBlock` + Shiki — unchanged, used as a custom `pre` override
- `OneEditor` props interface — unchanged
- All signal emission (`emitClick`) — unchanged

---

## Files touched

| File | Change |
|------|--------|
| `one.ie/web/src/components/ai-elements/markdown.tsx` | Rewrite: `markdown-to-jsx` → `streamdown`, add `isAnimating` prop |
| `one.ie/web/src/components/chat/MessageList.tsx` | Pass `isStreaming` to `AssistantTextPart` |
| `one.ie/web/src/layouts/Layout.astro` | Import `streamdown/styles.css` |
| `one.ie/web/package.json` | Add `streamdown` |

Editor accept flow is a separate implementation (new component, no changes to existing files) — tracked in `editor-ai-todo.md` when scoped.
