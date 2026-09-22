You are the hand. Build task task:01a07591e5c350a306c93933: "In pages/components add a button > add this component to a page — it shows a list of pages in the workspace, you select the page to add the component, then edit the page or continue adding components".
Notes from the board:
SPEC (the title is the whole spec; the row's notes were empty — this brief was assembled by the launching session from a real read of the tree on 2026-09-06, every file:line verified).

WHAT TO BUILD
On /components (the Component Library gallery, ComponentBrowser.tsx), give every block an 'Add to page' affordance. Clicking it opens a picker listing the workspace's pages; choosing one appends that block to that page; after the write, offer two exits — 'Edit page' (link to the page editor) and 'Continue adding components' (dismiss the picker, stay in the gallery).

BOTH RECEIVERS ALREADY EXIST — DO NOT WRITE A NEW ONE, DO NOT ADD AN API ROUTE.
- pages:list — one.ie/web/src/lib/resolvers/pages.ts:670. Request { slug }. Returns { pages: [{ slug, title, status, updated_at }] } ordered by updated_at DESC. This is the picker's list. Returns { pages: [] } on any auth denial.
- pages:add-block — one.ie/web/src/lib/resolvers/pages.ts:630. Request { slug, page, section: { component, props }, atIndex? }. atIndex omitted = append to end, which is what this feature wants. It already runs normalizeBlockProps(BLOCK_SCHEMA, ...) server-side, so send the block's defaultProps verbatim — do NOT normalize on the client.

EXACT CALL-SITE PRECEDENT — copy this shape:
one.ie/web/src/components/chat/BlockFrame.tsx:112-125. It is the same feature one surface over ('Add to page' from chat). Note its gate: `const canAddToPage = addToPage && !!slug && !!page`, its pending/added state machine, and `emitClick('ui:chat:add-to-page', { component })` before the call. Use `ask` from '@/lib/in/ask'. Emit a sibling signal name, e.g. 'ui:component-browser:add-to-page'.

THE ONE DESIGN DECISION, ALREADY SETTLED — DO NOT RE-OPEN IT.
/components is a genuinely PUBLIC route. pages/components.astro mounts <ComponentBrowser client:only="react" /> with a plain Layout and passes NO props, and ComponentBrowser takes none. It is NOT one of the slugless console pages: those (see pages/tasks.astro) call resolveRoom() and rewrite to /u/[slug]/..., and components.astro does neither. There is also no workspace-scoped mount — ComponentBrowser appears only in pages/components.astro and is referenced by components/puck/BlockFinder.tsx.

So: derive the workspace slug SERVER-SIDE in pages/components.astro (from Astro.locals.workspaceContext?.workspace ?? Astro.locals.slug — verify which is right against how another workspace-aware page reads it) and pass it down as an optional `slug` prop to ComponentBrowser. When there is no session there is no slug, and the 'Add to page' button MUST NOT RENDER — same gate shape as BlockFrame's canAddToPage. An anonymous visitor keeps exactly today's public gallery, unchanged. Do NOT invent a client-side workspace read, do NOT add a new route, do NOT make /components members-only.

WHERE THE BUTTON GOES
ComponentBrowser.tsx has two surfaces for a block: the grid card (article, ~line 250) and PreviewModal (~line 143). Put the affordance in the PreviewModal footer at minimum — the modal is the block's detail view and already has a footer row. A card-level quick-add is welcome but must not swallow the card's existing onClick (which opens the preview).

DONE LOOKS LIKE
1. Signed in, /components → open any block → 'Add to page' → picker lists this workspace's real pages → pick one → success state → 'Edit page' and 'Continue adding components' both present and both work.
2. The block actually lands: re-open that page in the editor and the block is there, rendered, at the end.
3. Signed out, /components renders exactly as before with no 'Add to page' button anywhere.
4. `cd one.ie/web && bun run verify:fast` green. Add a unit test for the picker gate (no slug ⇒ no button).

CONSTRAINTS
- 6-token palette only (hook:design-check blocks otherwise) — follow the existing var(--color-border) / text-font / bg-foreground idiom in this very file.
- Do not regress the IntersectionObserver lazy-mount or the PreviewErrorBoundary; the gallery renders ~376 blocks.
- Edit in a worktree, never on shared main.

RULES, each one a recorded outage (text/factory-do.md § Concurrency):
1. Work in YOUR OWN worktree, never the shared main tree. Slug: task-task:01a07591e5c350a306c93933.
   UI task — run:  bash .claude/scripts/worktree-preview.sh up task-task:01a07591e5c350a306c93933 --route /components
   It cuts the worktree from main, links node_modules CONTENTS (never the dir), copies .env, allocates a port (never sweeps), and hands you a URL only after 3 consecutive 200s. Use the path and URL it prints.
2. NEVER `bun install` inside the worktree. NEVER symlink node_modules itself.
3. Make the change the task describes — minimal, in the worktree. Write or extend the test that names the concrete failure this change prevents (input → wrong result). No test that guards a shape.
4. Run only YOUR test file(s) in the worktree:  cd <wt>/one.ie/web && bunx vitest related --run <files>  — through bash ../../.claude/scripts/gate-run.sh doer -- … . Do NOT run the suite; factory-walk.sh runs the tier's lane after you.
5. Commit in the worktree by EXPLICIT PATH (git add <file>...), message: "task(task:01a07591e5c350a306c93933): <what was measured>". Never git add -A.
6. Report files from `git status --porcelain` / `git show --stat` in the worktree, never from memory.
7. THE BRAIN AND THE EDGE (root CLAUDE.md, LOCKED): if the change adds or touches a receiver, it reads KV / BrainDO JSON — never typedbQuery — and writes to the brain fire-and-forget or via sync/. resolvers/factory.ts is the one exception. Prove the door: bash .claude/scripts/signal-watch.sh --local (with your preview as SIGNAL_WATCH_LOCAL) — a door over budget or reaching for the brain is red, and red closes nothing.
If the task cannot be done as written, do the part that can, say exactly what you left out and why, and return committed:false rather than inventing scope.
