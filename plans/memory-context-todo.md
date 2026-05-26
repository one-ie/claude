---
title: Memory Context — one company-context paragraph injected into every chat reply
slug: memory-context
type: plan
tier: simple
mode: construction
tags: [memory, context, chat, settings, company-context, fast-path]

parallel_budget:
  haiku:   6
  sonnet:  4
  opus:    0

batches:
  - [C1]                        # one cycle, one shippable slice

shared_recon:
  - one.ie/web/src/lib/in/workspace-settings.ts
  - one.ie/web/src/pages/api/settings.ts
  - one.ie/web/src/pages/api/chat.ts
  - one.ie/web/src/lib/menu.ts

source_of_truth:
  - one.ie/web/src/pages/api/CLAUDE.md
  - one.ie/web/src/lib/in/workspace-settings.ts
  - one.ie/web/src/pages/api/chat.ts

existing_primitives:
  - one.ie/web/src/lib/in/workspace-settings.ts: WorkspaceScope union + readWorkspaceSetting / writeWorkspaceSetting / isWorkspaceScope / scopeField / SCOPE_COLUMN map — EXTEND to add 'company-context'. NO new file.
  - one.ie/web/src/pages/api/settings.ts: GET/PUT /api/settings?scope=X&workspace=Y — already auth-gated (view_onchain / update_group). NO changes needed; new scope routes through it for free.
  - one.ie/web/src/pages/api/chat.ts: buildSystem(slug, displayName) at line 45; concat at line 959 chains the suffixes into the final prompt — EXTEND with a companyContextSuffix.
  - one.ie/web/src/lib/menu.ts: getUserMenu(slug, viewer) — extend with a Memory entry.
  - one.ie/web/src/components/ui/textarea.tsx + button.tsx: compose for the editor — NO bespoke <textarea>.
  - one.ie/web/migrations/0044_workspace_settings_csp.sql: example of the ALTER TABLE pattern — new migration mirrors this shape.

show: false

escape:
  condition: "C1 W4: chat replies do not include the saved context paragraph after saving, even with cache-buster and after waiting for the next turn."
  action: "halt; verify the chat.ts concat order — companyContextSuffix may need to land before persona suffix so the persona overrides don't bury it. Diff the production system prompt vs local."

context_triggers:
  - pattern: "scope|settings|workspace"
    inject: "one.ie/web/src/lib/in/workspace-settings.ts (the whole file)"
  - pattern: "buildSystem|systemPrompt"
    inject: "one.ie/web/src/pages/api/chat.ts § buildSystem (line 45-60) + the concat at line 959"
---

# Memory Context

**The job:** Give every workspace one editable paragraph of company context (brand voice, products, customers, policies) that gets injected into the chat system prompt on every turn. No structured memory, no hypothesis rows, no per-fact tracking — just one persisted blob per workspace.

**Goal:** Ship a `/u/[slug]/memory/` page with a `<textarea>` + Save button. On Save, the value is written to `workspace_settings.company_context`. On every chat turn, `buildSystem()` in `chat.ts` reads that value and appends it to the system prompt.

**Exit:** From `/u/{slug}/memory/`, type "We sell consulting services to mid-market SaaS companies. Our voice is calm and technical." → Save → open `/chat` in the same workspace → ask "what do you sell?" → reply quotes the saved fact within one turn. Verified by `bun vitest run one.ie/web/tests/e2e/memory-context.test.ts`.

**Scope-defending rule:** if a feature requires a schema change beyond one D1 ALTER TABLE column add, or a new route file, or any agents/ change, it belongs in `memory-ui-todo.md` (the bigger plan), not here. This plan stays one cycle.

---

## What this plan ships and what it doesn't

| Ships | Defers |
|---|---|
| ✅ One paragraph per workspace, persisted in D1 | ❌ Per-row hypothesis memory |
| ✅ Injected into chat system prompt automatically | ❌ Per-user private notes |
| ✅ Sidebar Memory entry | ❌ Verify / forget per row |
| ✅ Multi-tenant (workspace_settings already scoped per slug) | ❌ Agent recall via TypeDB |
| ✅ ~5 files, ~150 LOC, one cycle | ❌ Paste-anything pipeline |

The bigger structured-memory plan lives in `plans/memory-ui-todo.md` and is not deleted — it picks up when per-fact tracking becomes a real need.

---

## Status

```
Batch 0 (shared)
  - [x] W0 baseline (plan-level)
  - [x] W1 shared recon (plan-level)

Batch 1
  - [x] C1 — company-context paragraph + chat injection    state: closed
    - [x] W1 recon
    - [x] W2 decide
    - [x] W3 edit
    - [x] W4 verify

Plan close
  - [x] Append entry to plans/learnings.md
```

---

## C1 — company-context paragraph + chat injection  [tier: simple · batch: 1]

**Exit:** Save a paragraph at `/u/{slug}/memory/`, ask the chat a question whose answer requires that paragraph, the reply uses it. Demo gate decides.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run one.ie/web/tests/e2e/memory-context.test.ts"
  asserts:  "PUT settings?scope=company-context → GET returns the same value → chat handler injects it into buildSystem output"
  budget:   "<3s wall · <100 LOC test (mocks the LLM, asserts the system prompt the handler constructs)"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon (mandatory):**
   - [ ] `one.ie/web/src/lib/in/workspace-settings.ts` — full file: confirm `WorkspaceScope` union, `SCOPE_COLUMN` map, `SCOPE_FIELD` map, `readWorkspaceSetting`/`writeWorkspaceSetting` shapes. Document the exact additions needed (3 places).
   - [ ] `one.ie/web/src/pages/api/chat.ts` — read `buildSystem` (line 45-60) AND the concat at line 959. Document where the new suffix will splice in. Order matters: company context goes BEFORE persona suffix so persona-specific overrides win on conflict.
   - [ ] `one.ie/web/src/pages/api/settings.ts` — confirm zero code changes needed; new scope flows through GET/PUT automatically once the union is extended.
   - [ ] `one.ie/web/migrations/` — list latest migration number (`ls migrations/ | sort | tail -3`) and the ALTER TABLE pattern from `0044_workspace_settings_csp.sql` to copy.
   - [ ] `one.ie/web/src/lib/menu.ts` — confirm `getUserMenu` shape from earlier recon.

2. **Primitive-inventory recon:**
   - [ ] `one.ie/web/src/components/ui/textarea.tsx` — confirm shipped, get prop signature
   - [ ] `one.ie/web/src/components/ui/button.tsx` — confirm shipped
   - [ ] grep `one.ie/web/src/components/settings/` for an existing settings-page editor pattern to compose instead of inventing

3. **Auth-pattern recon:**
   - [ ] How does an existing `/u/[slug]/{something}/index.astro` page resolve viewer + slug + role? Pick the closest example (e.g. `/u/[slug]/settings/...` if it exists). Document the exact frontmatter snippet to copy.

### W2 — Decide  [Sonnet]

- [ ] **Compose-or-construct verdict** filed per file (table below)
- [ ] **Scope name** — `'company-context'` (kebab-case, matches the URL query param). Document.
- [ ] **D1 column name** — `company_context TEXT NOT NULL DEFAULT ''` — empty string sentinel = "no context set" (no nullable column → simpler reads).
- [ ] **JSON field name** — `companyContext` (camelCase) returned by GET / accepted by PUT body. Document.
- [ ] **Injection order in chat.ts** — `buildSystem(slug, displayName) + (companyContext ? "\n\nCompany context:\n" + companyContext : '') + systemSuffix + ...`. Goes immediately after buildSystem so it's part of the "who you serve" identity block, before persona overrides.
- [ ] **Length cap** — soft cap 4000 chars on the textarea client-side; hard cap 8000 in the writeWorkspaceSetting path. Pick numbers based on token budget (~2000 tokens at the high end).
- [ ] **Empty handling** — if `company_context = ''`, the chat handler appends NOTHING (no "Company context:" header, no blank line). Test asserts this.
- [ ] **Auth** — page uses the existing workspace auth pattern (role: `member`+ to read, `update_group` to write — matches settings.ts PUT). No new role action needed.
- [ ] **Diff specs output**

Proposed files:

| File | Closest primitive | Verdict |
|---|---|---|
| `one.ie/web/src/lib/in/workspace-settings.ts` | itself | **extend** — 3 single-line additions (union, column map, field map) |
| `one.ie/web/migrations/00XX_workspace_company_context.sql` | `0044_workspace_settings_csp.sql` | **new** — one ALTER TABLE ADD COLUMN |
| `one.ie/web/src/pages/api/chat.ts` | itself | **extend** — fetch context once per request, splice into system prompt concat |
| `one.ie/web/src/pages/u/[slug]/memory/index.astro` | sibling workspace page | **new** — page route, ≤40 LOC |
| `one.ie/web/src/components/memory/CompanyContextEditor.tsx` | `ui/textarea.tsx` + `ui/button.tsx` | **compose** — ≤60 LOC; useState for draft, fetch on Save |
| `one.ie/web/src/lib/menu.ts` | itself | **extend** — one row added to `getUserMenu` |
| `one.ie/web/tests/e2e/memory-context.test.ts` | existing settings tests | **new** — demo gate, ≤100 LOC |

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (one message):**
- [ ] `one.ie/web/src/lib/in/workspace-settings.ts` — add `'company-context'` to `WorkspaceScope` union; add row to `SCOPE_COLUMN`: `'company-context': 'company_context'`; add row to `SCOPE_FIELD`: `'company-context': 'companyContext'`
- [ ] `one.ie/web/migrations/00XX_workspace_company_context.sql` — `ALTER TABLE workspace_settings ADD COLUMN company_context TEXT NOT NULL DEFAULT '';`
- [ ] `one.ie/web/src/components/memory/CompanyContextEditor.tsx` — composes `Textarea` + `Button`; `useState` for draft + saving state; on Save: PUT `/api/settings?scope=company-context&workspace={slug}` with `{ companyContext: draft }`
- [ ] `one.ie/web/src/pages/u/[slug]/memory/index.astro` — SSR GET `/api/settings?scope=company-context&workspace={slug}`, mount `CompanyContextEditor` with `client:only="react"` and pass current value as a prop
- [ ] `one.ie/web/src/lib/menu.ts` — add `{ href: \`${base}/memory\`, label: 'Memory', icon: <chosen lucide icon>, viewer: ['owner', 'agency', 'client'] }` to `getUserMenu` main array
- [ ] `one.ie/web/src/pages/api/chat.ts` — in the route handler, fetch the workspace's `company_context` once (alongside other workspace data already loaded); splice into the system prompt concat: change line 959 to insert the conditional `\n\nCompany context:\n${companyContext}` immediately after `buildSystem(slug, ownerDisplayName)`
- [ ] `one.ie/web/tests/e2e/memory-context.test.ts` — three asserts: (a) PUT then GET returns the same value, (b) buildSystem output includes the context when set, (c) buildSystem output excludes the "Company context:" header when value is empty

**W3b — dependent:** (empty — all edits independent)

### W4 — Verify  [inline composite — simple tier]

- [ ] `cd one.ie/web && bun run db:migrate:local` runs the new migration cleanly
- [ ] `cd one.ie/web && bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] Demo gate exits 0
- [ ] **Reuse audit:**
  - [ ] No new API route file (`ls one.ie/web/src/pages/api/memory/` returns nothing — settings.ts handles it)
  - [ ] No bespoke `<textarea>` (`grep -nE "<textarea" one.ie/web/src/components/memory/` returns 0 — `Textarea` primitive composed)
  - [ ] No new role action in `role-check.ts` (this slice reuses `update_group`)
  - [ ] `wc -l` for the 4 new code files (migration + editor + astro page + test) ≤ 250 total
- [ ] **Live verification (touches D1 + chat surface):** post-deploy:
  - [ ] `curl -s -o /dev/null -w "%{http_code}" -X PUT "$DEPLOY/api/settings?scope=company-context&workspace=$TEST_SLUG" -H 'Content-Type: application/json' -d '{"companyContext":"smoke test"}'` returns 200 or 401 (never 500)
  - [ ] One real chat turn against the same workspace surfaces "smoke test" in the streamed reply (or, if that's hard to assert from CI, the test asserts the system prompt the handler constructs includes the substring)
- [ ] Composite ≥ 0.65 — targets: **simplicity ≥ 0.95** (this should be embarrassingly small) · stability ≥ 0.90 · security ≥ 0.90 · speed ≥ 0.85

Report: `delta_tsc=±N  delta_loc=+N  new_files=N  scope_added=company-context  injection_site=chat.ts:959`

---

## What this plan must not produce

- ❌ A new `/api/memory/*` route family — `/api/settings?scope=company-context` is the route
- ❌ Any TypeDB schema change — D1 ALTER TABLE only
- ❌ Any `agents/` worker change — chat injection happens in web's `chat.ts`
- ❌ A new role action — reuse `update_group` (write) and `view_onchain` (read), same as other scopes
- ❌ More than one paragraph per workspace — if multi-paragraph or per-fact is needed, that's `memory-ui-todo.md`
- ❌ Markdown rendering of the saved context inside the system prompt — the LLM gets the raw text; the textarea is plain text only

---

## See also

- `plans/memory-ui-todo.md` — the bigger structured-memory plan (hypothesis rows, memory-of relation, per-user scope). Not in conflict; this plan's data can later be migrated into a hypothesis row when that ships.
- `one.ie/web/src/pages/api/CLAUDE.md` — receiver-IS-the-API contract (and the legitimacy of new settings scopes vs new routes)
- `one.ie/web/src/lib/in/workspace-settings.ts` — the file every existing scope lives in
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands

---

*One scope. One column. One textarea. One injection line. One cycle. Then keep going.*
