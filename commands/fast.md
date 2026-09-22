---
description: /fast — write the page, look at it, iterate. No tests.
---

# /fast — page-building mode

`/fast <what to build or change>`

For UI work where the loop is **edit → render → look → edit**. Tests, ratchets,
reconcile canons and the /do spine are all OFF. Nothing is committed, nothing is
deployed, nothing is promised.

Use when: building or tweaking a page, component, layout, or copy and you want
to see it in a browser now.

Do NOT use when: touching `schema/`, `packages/sdk/`, auth/authority code, or
anything with a money path. Those take the normal lane — say so and stop.

## The loop

**0 — server up (once).** Reuse it for every later iteration.
```bash
curl -sf -o /dev/null http://localhost:4321 && echo UP || echo DOWN
```
DOWN → start it in the background and move on:
```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev
```
(run_in_background: true). If the port is wedged, `/restart`.

**1 — edit.** Write the code. Match the surrounding file's idiom. Rules under
`.claude/rules/` (astro/react/ui/design) still apply — they are how the page
comes out right the first time, not a gate.

**2 — look.** Astro HMRs; no rebuild needed.
```bash
node .claude/scripts/chrome.mjs --url http://localhost:4321/<path> --screenshot /tmp/fast.png
```
Then Read `/tmp/fast.png`. Read the screenshot yourself before saying it works —
`httpStatus: 200` is not a rendered page.

**3 — read the errors.** chrome.mjs returns `jsErrors` and `consoleErrors`.
A non-empty either one means broken, even if the shot looks fine. Fix, re-shoot.

**4 — repeat** from 1 until it looks right.

## What is skipped, and what is not

| Skipped | Kept |
|---|---|
| `bun run verify` / `verify:fast` | the TypeScript the editor already shows you |
| vitest, ratchets, honesty checks | design + a11y rules under `.claude/rules/` |
| do-reconcile canons | never inventing a receiver — `grep` it in `packages/sdk/src/receivers.ts` first |
| the /do spine, promises, TEACH | never editing schema/SDK/auth in this mode |
| commit, push, deploy | |

## Exit

Fast mode ends the moment the page is right. Before the work is committed or
merged, run the real gate once:

```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run verify:fast
```

Say plainly which lane ran. **A page proven only by screenshot is not a tested
page** — never report a `/fast` iteration as verified.
