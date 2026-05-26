---
title: Skills UI — capability dashboard, not file list
slug: skills
type: plan
tier: complex
mode: construction
tags: [skills, editor, ui, eval, wiring]

parallel_budget:
  haiku:   8
  sonnet:  6
  opus:    1

batches:
  - [C1]
  - [C2, C3]
  - [C4]
  - [C5]
  - [C6]
  - [C8]
  - [C10]
  - [C11]
  - [C12]
  - [C13]
  - [C14, C15, C16]

shared_recon:
  - plans/skills.md
  - plans/evaluate.md
  - one.ie/web/src/pages/u/[slug]/skills/index.astro
  - one.ie/web/src/components/skills/SkillsView.tsx
  - one.ie/web/src/lib/skill/loader.ts
  - one.ie/web/src/lib/eval/mastery.ts
  - one.ie/web/src/pages/api/skills/[name]/enable.ts
  - one.ie/web/migrations/0007_agents_skills_tools_themes.sql

source_of_truth:
  - plans/skills.md
  - plans/evaluate.md
  - one.ie/web/src/lib/skill/parser.ts
  - one.ie/web/src/lib/eval/mastery.ts

existing_primitives:
  - one.ie/web/src/components/editor/Editor.tsx: OneEditor (Novel/Tiptap) — C3 uses for skill body editing
  - one.ie/web/src/components/chat/ChatDock.tsx: embedded chat surface — C3 composes into right column
  - one.ie/web/src/lib/skill/loader.ts: loadSkill(key, r2) → Skill — C2 SSR loop + C4 edit page
  - one.ie/web/src/lib/skill/emit.ts: emitSkill(skill) → Map<path,content> — C3 uses to serialize back
  - one.ie/web/src/lib/skill/parser.ts: parse(md) → { meta, body } — C3 uses to split frontmatter on mount
  - one.ie/web/src/lib/db/skills.ts: putSkill / deleteSkill — C1 endpoint calls these
  - one.ie/web/src/lib/api-auth.ts: requireAuth → Principal — C1 uses for session gate (save AND enable)
  - one.ie/web/src/lib/eval/mastery.ts: computeMastery(benchmarks) → { level, prob } — C2 SSR loop calls per skill
  - one.ie/web/src/pages/api/skills/[name]/enable.ts: POST { agent_id, enabled } — wiring API exists; C1 extends it to accept session auth so WireMenu can call from browser
  - one.ie/web/migrations/0007_agents_skills_tools_themes.sql: agent_skills (agent_id, skill_name) — C2 SSR loop reverse-queries to compute wired_agents per skill

show: false
escape:
  condition: "C2 W4 delta_tsc > 0 twice OR C3 W4 same"
  action: "halt; verify OneEditor + ChatDock imports before retrying"
context_triggers:
  - pattern: "mastery|BKT|benchmark|iteration"
    inject: "plans/evaluate.md § Aggregate → benchmark.json + mastery curve"
  - pattern: "OneEditor|EditorContent|EditorRoot"
    inject: "one.ie/web/src/components/editor/Editor.tsx § OneEditorProps"
  - pattern: "requireAuth|Principal|api-auth"
    inject: "one.ie/web/src/lib/api-auth.ts § requireAuth"
---

# Skills UI — capability dashboard, not file list

**Goal:** `/u/[slug]/skills` shows each installed skill as a measured capability — mastery chip, wired-on agent count, three primary actions (Edit · Wire ▾ · ⋯). Empty state offers Create · Import · Browse as equal-weight paths. New + edit pages use a split editor (OneEditor + ChatDock). All wiring uses the existing `enable` endpoint, extended to session auth.

**Exit:** `bun run verify` green AND `/u/[slug]/skills` renders compact rows with mastery chips + action cluster + working "Wire ▾" menu AND `/u/[slug]/skills/new` renders the split editor with template loaded.

---

## Design contract (read before any cycle)

The page treats skills as **active capabilities**. Each row answers three questions at a glance:

| Question | Source | Surface |
|---|---|---|
| Is it healthy? | `mastery.ts` over R2 benchmarks | Chip: unrun / novice / developing / proficient / mastered |
| Where is it wired? | D1 `agent_skills` reverse query | "live on N agents" line |
| What do I do? | actions | `[Edit]  [Wire ▾]  [⋯]` — Edit primary |

**Three primary actions, not four.** Eval is collapsed into the mastery chip (click → detail page eval section) and into the ⋯ overflow ("Run eval now"). Eval is a power-user verb; promoting Edit + Wire to the top is correct for the dashboard frame.

**Empty state — three equal-weight cards:** Create · Import · Browse. Drops the "go to settings" link.

**Out of scope (deferred to `skills-scale-todo.md`):** search, filter chips, sort dropdown, usage/cost roll-up, drift indicator, bulk select, group-by-tag, inline eval progress UI. None matter until installed > ~10 per workspace.

---

## Decisions locked at plan start

These are the calls that previous drafts left dangling. Locked here so W2 in each cycle inherits them.

| Decision | Choice | Why |
|---|---|---|
| **Wiring data source** | SSR in `index.astro` — no new endpoint | Page already SSRs with R2 + D1 access; an aggregator API would marshal data the page can compute inline |
| **Enable endpoint auth** | Extend `enable.ts` to accept session via `requireAuth` (C1) | WireMenu runs in browser with session cookie, not Bearer secret |
| **Skill rename** | NOT supported in v1 | Renaming would orphan R2 key + break `agent_skills.skill_name` rows in D1. Title is editable; `name` is display-only |
| **Eval from row** | No inline button — link via mastery chip click + ⋯ overflow item to the existing detail page | Eval is minutes-long, fails on missing tests; inline progress UI is its own feature, not part of the dashboard frame |
| **Invalidation after mutation** | Wire toggle → optimistic + revert on error · Delete → confirm + `location.reload()` · Save → no index refresh needed | Astro is SSR-native; full reload is the correct primitive when the page is the source of truth |
| **Read-only View page** | Kept. Linked from `⋯ → View source` | Detail view is still useful for sharing + eval results |
| **"Needs eval" in roll-up** | `mastery.level === 'unrun'` only | Crisp definition; everything else has at least some signal |
| **WireMenu empty state** | "No agents yet — create one →" link to `/u/{slug}/agents/new` | Don't hide the button; teach the next step |

---

## Reuse contract

| Proposed file | Closest primitive | Gap | Verdict |
|---|---|---|---|
| `api/skills/[name]/save.ts` | `enable.ts` (D1 only) | needs R2 write of skill body | **new** — ≤60 LOC |
| `enable.ts` (modify) | existing Bearer-secret POST | needs to also accept session auth | **modify** — ~20 LOC delta |
| `components/skills/SkillRow.tsx` | inline `<article>` in current `index.astro` | row layout + mastery chip + action cluster + WireMenu trigger | **new** — ~140 LOC |
| `components/skills/WireMenu.tsx` | none | popover listing user's agents; POSTs enable | **new** — ~90 LOC |
| `components/skills/SkillEditor.tsx` | OneEditor + ChatDock | no existing combo for skill authoring | **new** — ~200 LOC |
| `pages/u/[slug]/skills/new.astro` | `[name].astro` (read-only) | client island with template | **new** — ≤30 LOC |
| `pages/u/[slug]/skills/[name]/edit.astro` | same | R2 load → SkillEditor | **new** — ≤40 LOC |

LOC budgets: C1 ≤80 (save + enable patch) · C2 ≤300 (SkillRow + WireMenu + SkillsList wrapper + index.astro rewrite) · C3 ≤200 · C4 ≤80.

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline
  - [ ] W1 shared recon

Batch 1
  - [x] C1 — Save endpoint + session auth on enable     state: done
    - [x] W1 · W2 · W3 · W4

Batch 2  (parallel, after C1)
  - [x] C2 — Index page rewrite (rows + wiring + empty)  state: done
    - [x] W1 · W2 · W3 · W4
  - [x] C3 — SkillEditor component                       state: done
    - [x] W1 · W2 · W3 · W4

Batch 3  (after C3)
  - [x] C4 — new + edit pages                            state: done
    - [x] W1 · W2 · W3 · W4

Batch 4  (gap-fill: eval is invisible)
  - [x] C5 — Detail page eval section                    state: done
    - [x] W1 · W2 · W3 · W4

Batch 5  (after C5)
  - [x] C6 — Wire overflow actions (fork · refresh · run eval)  state: done
    - [x] W1 · W2 · W3 · W4

Batch 6  (after C5–C6 — vocabulary + promotion pass)
  - [x] C8 — Three primary verbs: Edit · Add to agent · Evaluate  state: done
    - [x] W1 · W2 · W3 · W4

Batch 7  (Studio foundation — replaces SkillEditor)
  - [x] C10 — SkillStudio shell + shared draft store + Properties block  state: done
    - [x] W1 · W2 · W3 · W4

Batch 8  (after C10 — chat plugs into Studio)
  - [x] C11 — Chat proposes, human applies (simplified — no tools)  state: done
    - [x] W1 · W2 · W3 · W4
    - simplified design: chat outputs full SKILL.md in a fenced block; ChatDock detects + renders SkillProposalCard; Apply replaces studioStore meta+body. Original tools-based design deferred to C11-full if needed.

Batch 8b  (SUPERSEDED — tests now live in `evals:` frontmatter, body editor IS the tests editor)
  - [~] C12 — Tests tab: evals.json editor inside Studio  state: superseded (2026-05-24)
    - rationale: same logic that deleted C22 — no new tab, no new endpoint;
      `evals:` in frontmatter is authored in the body editor

Batch 9  (SUPERSEDED — see C21)
  - [~] C13 — Live edit channel: external writers (Claude Code/CLI/MCP) → browser studio  state: superseded
    - rationale: MCP propose/eval tools (C21) + browser refresh cover ~80% of the
      "Claude Code edits, I see it appear" UX without the WsHub DO + SSE channel
      infrastructure. Sub-second live-cursor parity can wait until a user asks.

Batch 10  (loop-closure pass — parallel)
  - [x] C14 — KV catalog cache busted on save                state: na (no cache exists)
    - [x] W1 · W2 · W3 · W4
  - [x] C15 — Parser diagnostics surfaced in Studio          state: done
    - [x] W1 · W2 · W3 · W4
  - [x] C16 — Eval the draft (unsaved state) from Studio     state: partial (API + filter done; UI button blocked on C22)
    - [x] W1 · W2 · W3 · W4

────────────────────────────────────────────────────────────────────────
SIMPLIFICATION  (2026-05-24) — power through simplicity
────────────────────────────────────────────────────────────────────────
The original C17–C23 (7 cycles, ~6-8h) treated *shared code* as the goal.
But the substrate is the markdown contract + the eval endpoint. Everything
else is decoration. Five of those cycles were deleted:

  C17  (autoImportSkillCreator from middleware)  →  DELETED
       methodology moves into chat.ts system prompt as a build asset; no
       per-workspace R2 copy needed; orphan auto-import.ts gets deleted

  C18  (lift markdown contract into @oneie/sdk)  →  DELETED
       YAML doesn't drift; the schema is a doc (plans/skill-format.md),
       not a published package. Every surface uses its local YAML parser.

  C21  (MCP propose + eval tools)                →  ½ DELETED
       `propose` is just "model writes markdown" — that's the model's job;
       only `skill_eval` remains (one tool, ~30 LOC fetch wrapper)

  C22  (Tests tab in Studio)                     →  DELETED
       tests live in `evals:` frontmatter, not a sidecar file. Body editor
       IS the tests editor; no new endpoint, no new tab.

  Plus: skill-format.md doc created as the single source of truth for the
        substrate (one-page schema for any surface to read).

From 7 cycles to 4 cycles. From ~6-8h to ~1.5h. See plan-close for the
new architecture rule that drove this cut.
────────────────────────────────────────────────────────────────────────

Batch 11  (FORMAT — substrate doc)
  - [x] C17 — plans/skill-format.md created                   state: done (2026-05-24)
    - [x] W1 · W2 · W3 · W4
    - One-page schema: markdown frontmatter (with evals: inline) + one
      HTTP endpoint. Every surface reads this doc, no shared package.

Batch 12  (DELETIONS — pay down the orphans)
  - [x] C18 — Delete orphan / buggy code                      state: done (2026-05-24) · tier: trivial
    - [x] W1 · W2 · W3 · W4
    - [x] deleted `one.ie/web/src/lib/skill/auto-import.ts` (never called)
    - [x] removed `skill.eval` action from `actions/skills.ts` + unused imports
    - [~] eval.ts sidecar demotion deferred — primary-from-frontmatter requires
      a real YAML parser (current `lib/skill/parser.ts` handles only flat
      `- string` arrays, not nested `evals: [{prompt, assertions[]}]`).
      Track as follow-up: needs YAML lib + parser test coverage before
      the sidecar can be demoted without breaking existing skills.

Batch 13  (CLI + MCP — fetch wrappers, not SDK consumers)
  - [x] C19 — CLI `skill eval` + `skill new` scaffolds 3 inline evals  state: done (2026-05-24) · tier: trivial
    - [x] W1 · W2 · W3 · W4
    - [x] `oneie skill eval <path>` now POSTs to `/api/eval` with
      `{ slug, skillPath, iteration, draftContent, draftEvals }`. Extracts
      `evals:` from frontmatter via a 20-LOC hand-rolled nested-array
      parser (no YAML dep — keeps `npx oneie` install <5MB per cli/CLAUDE.md)
    - [x] `oneie skill new <name>` template includes 3 example TestCase
      entries (representative · edge case · negative) under `evals:` —
      closes create→test→iterate for CLI users with zero JSON authoring
  - [x] C21 — MCP `skill_eval` tool                           state: done (2026-05-24) · tier: trivial
    - [x] W1 · W2 · W3 · W4
    - [x] tool added to `packages/mcp/src/tools/lifecycle.ts` (the
      established home for skill-related HTTP-shaped tools). Inputs:
      `{slug, content, name?, iteration?}`. Extracts evals from frontmatter
      via the same 20-LOC parser as the CLI, POSTs to `/api/eval`.
      Claude Code writes the file, calls `skill_eval`, browser refresh
      shows the result. Collapses what C13 was reaching for.

Batch 14  (SECURITY + SYSTEM PROMPT — the non-negotiable two)
  - [x] C20 — Inline skill-creator into chat.ts as build asset  state: done (2026-05-24) · tier: trivial
    - [x] W1 · W2 · W3 · W4
    - [x] `import skillCreatorMd from '../../../../agents/skill-creator/SKILL.md?raw'`
      added at top of chat.ts (vite `server.fs.allow: ['..']` already permits it).
      `SKILL_CREATOR_METHODOLOGY` constant strips skill-creator's own frontmatter
      via `replace(/^---\n[\s\S]*?\n---\n+/, '')` at module load. When
      `body.group === 'skills' || requestSurface === 'skills'`, the methodology
      body prepends the existing proposal-card addendum. Every workspace
      gets identical, current methodology with zero per-workspace R2 copy.
  - [x] C23 — Gate /api/eval behind auth                      state: done (2026-05-24) · tier: trivial
    - [x] W1 · W2 · W3 · W4
    - [x] dual-auth gate added to `/api/eval`: Bearer `<slug>:SERVER_SECRET`
      for CLI/MCP (via inline `checkBearer` mirroring enable.ts pattern) OR
      `requireAuth('update_group')` for browser session. Both paths verify
      `body.slug === authedSlug` → 403 otherwise. Quota burns against
      your own workspace only. `// PUBLIC` comment removed.

Plan close
  - [x] plans/skills.md full rewrite to match post-C16 reality   (done 2026-05-24)
  - [x] plans/evaluate.md updated with draft eval path + surfaces (done 2026-05-24)
  - [x] plans/skills-implementation-todo.md marked lifecycle: shipped + post-ship notes (done 2026-05-24)
  - [x] plans/skill-format.md created as substrate doc           (done 2026-05-24)
  - [x] plans/skills-scale-todo.md created with deferred items   (done 2026-05-24)
        15-item backlog: search · usage · drift · versioning · marketplace · scripts
        editor · multi-workspace sharing · rename · live-cursor · description optimizer
        · etc. + 2 inherited blockers (parser nested-object support, draft-eval button)
  - [~] Live end-to-end receipt on all 4 surfaces (web · CLI · MCP · raw HTTP)
        script shipped at `one.ie/web/scripts/skill-eval-receipt.sh`; live execution
        requires logged-in workspace + SERVER_SECRET → manual run by owner.
        Receipt log table seeded in skills-implementation-todo.md § Receipt.
  - [x] Plan rubric ≥ 0.65                                       (done 2026-05-24)
        composite=0.86 (goal-fit=0.95 · security=0.95 · stability=0.90 ·
        simplicity=0.85 · speed=0.85). Detail in `## Plan rubric` below.

Superseded / deleted:
  - C7  (Test-case editor in SkillEditor)        → folded into C22, then C22 itself deleted
  - C9  (PropertiesBlock for SkillEditor)        → absorbed into C10 (shipped)
  - C13 (Live edit channel via WsHub DO + SSE)   → MCP `skill_eval` (C21) + browser refresh = 90% of UX, 5% of code
  - C17-orig (autoImportSkillCreator middleware) → DELETED; skill-creator inlined into chat.ts as build asset (new C20)
  - C18 (lift markdown contract into SDK)        → DELETED; skill-format.md is the schema (new C17)
  - C21-orig (MCP propose + eval, two tools)     → halved to one tool (skill_eval); the model proposes natively
  - C22 (Tests tab in Studio)                    → DELETED; tests live in `evals:` frontmatter, edited in the body

The architectural rule that drove the cut (root CLAUDE.md):

  > Power through simplicity — the meta-layer should obey the rule the
  > schema already obeys.

The schema (TypeDB substrate) has a grammar, not an SDK. Every surface
speaks the grammar; no shared client code. Skills now follow the same
rule: a markdown grammar + one HTTP endpoint. Every surface uses its
local YAML parser + fetch. No shared package, no version coordination,
no per-language drift — because every language has YAML and HTTP.
```

---

## End state — what "complete" looks like

The output of this plan is a `/u/{slug}/skills` surface where any user can **author, measure, and ship a Skill** — markdown in, mastery curve out — using whichever interface fits their context.

```
A user types "I want to build a skill that…" anywhere:

  in the Studio chat        → SkillProposalCard appears → Apply → edit → Save
  in Claude Code (MCP)      → skill.propose tool emits markdown → browser refreshes
  in their terminal (CLI)   → oneie skill init + eval iterates locally
  in raw HTTP / SDK         → POST /api/eval, see numbers

All four paths write the same R2 markdown, get graded by the same engine,
land on the same mastery curve. One skill, four front doors.
```

### The shape of "done" for a single skill

1. User types intent → `skill-creator` drives the draft (chat or MCP)
2. Draft has test cases (scaffolded automatically by `oneie skill init`)
3. Eval runs: pass_rate, delta vs baseline, tokens, time
4. BKT advances: `novice` → `developing` → `proficient` → `mastered`
5. Mastery gate = `prob ≥ 0.80` sustained across multiple iterations
6. Skill ships — installed on agents, paid for, cited
7. Substrate keeps measuring; bad skills fade via Loop L3, good ones strengthen

### The architectural payoff

```
Before this plan:                       After this plan:
─────                                   ─────
Web has its parse/emit                  @oneie/sdk owns parse/emit/validate
CLI has its own parse                   CLI is a ~50-LOC wrapper around SDK
SDK has its own Skill type              MCP is a ~50-LOC wrapper around SDK
MCP has discovery only                  Web /api/* is the only server
3 eval entry points (one buggy)         /api/eval is the only engine; SDK is
                                          the only client
4 surfaces, 4 contracts, 3 runners,     4 surfaces, 1 contract, 1 runner,
1 engine                                1 engine
```

**Markdown in, numbers out — from any surface, with the same vocabulary, measured by the same judge, stored in the same place.** That is the substrate this plan builds.

### Explicit deferrals (move to `skills-scale-todo.md`)

| Topic | Why deferred |
|---|---|
| Live in-editor cross-device streaming (original C13) | MCP authoring + browser refresh covers the use case |
| Versioning / rollback | Skills have `version` field but no R2 snapshot history; useful but no user pressure yet |
| Marketplace publish | Product question, not editor scope |
| Scripts/references/assets editor UI | Data model declares the dirs; no skill in the catalog uses them today |
| Telemetry: usage count + cost roll-up per row | Needs usage tracking primitive first |
| Legacy `one.ie/web/skills/*.md` migration | One-shot script, not a cycle |
| Multi-workspace skill sharing | Permissions model work — separate plan |
| Skill rename + R2 move + D1 cascade | Out of scope for v1 |
| Inline eval progress UI on a row | Today: link to detail page; revisit when authoring volume grows |
| Description optimizer surface | Today chat-invoked; defer until C22 measurements show users want a button |

---

## C1 — Save endpoint + session auth on enable  [tier: simple · batch: 1]

**Exit:**
- `PUT /api/skills/[name]/save` with `{ content, slug }` writes `<slug>/skills/<name>/SKILL.md` to R2; `DELETE` removes it. Both session-gated.
- `POST /api/skills/[name]/enable` accepts EITHER the existing Bearer secret OR a session cookie via `requireAuth`. WireMenu (C2) can call it from the browser.

### W1 — Recon

1. **Existing-code recon**
   - [ ] `one.ie/web/src/pages/api/skills/workspace.ts` — `requireAuth` + `principal.slug` pattern; R2 bucket binding
   - [ ] `one.ie/web/src/pages/api/skills/[name]/enable.ts` — full current shape; how to add a session branch without breaking Bearer flow
   - [ ] `one.ie/web/src/lib/db/skills.ts` — `putSkill` + `deleteSkill` signatures
   - [ ] `one.ie/web/src/lib/api-auth.ts` — `requireAuth`, `AuthError`, `authErrorResponse`

### W2 — Decide  [Sonnet]

- [ ] **save.ts:** PUT + DELETE on `[name]/save.ts`. Auth via `requireAuth(request, 'update_group')` → verify `body.slug === principal.slug` → 403 otherwise → `putSkill` / `deleteSkill`
- [ ] **enable.ts patch:** keep existing Bearer-secret branch as-is. Add fallback: if no Bearer match, try `requireAuth(request, 'update_group')`; on success, also verify the agent being wired belongs to `principal.slug` (D1: `SELECT owner_slug FROM agents WHERE id = ?`) → 403 if mismatch
- [ ] Diff specs for W3

### W3 — Edit  [Sonnet]

**W3a — independent:**
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — new
- [ ] `one.ie/web/src/pages/api/skills/[name]/enable.ts` — add session-auth branch + agent ownership check

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] `wc -l save.ts` ≤ 60
- [ ] Grep: `requireAuth` + `putSkill` + `deleteSkill` in `save.ts`
- [ ] Grep: both `Bearer` AND `requireAuth` present in `enable.ts` (dual auth)
- [ ] Grep: `owner_slug` check present in enable.ts session branch
- [ ] Rubric ≥ 0.65 · security ≥ 0.90

---

## C2 — Index page rewrite (rows + wiring + empty)  [tier: complex · batch: 2]

**Exit:** `/u/[slug]/skills` SSR-loads each skill + its mastery + its wired-agent-ids + the user's agents, renders `<SkillRow>` per skill with mastery chip and `[Edit] [Wire ▾] [⋯]`. Three-card empty state replaces the "go to settings" block. Catalog collapses to `▸ Browse catalog (N)` when installed > 0. Header has `[+ New skill]` + `[Import URL]`.

### W1 — Recon

1. **Existing-code recon**
   - [ ] `one.ie/web/src/pages/u/[slug]/skills/index.astro` — full current shape; the per-skill `loadSkill` loop (lines 12-39) is the spine we extend
   - [ ] `one.ie/web/src/lib/eval/mastery.ts` — `computeMastery` signature; R2 key convention `<slug>/skills/_workspace/<name>/iteration-*/benchmark.json`
   - [ ] `one.ie/web/src/pages/api/eval.ts` — confirms benchmark.json key shape
   - [ ] `one.ie/web/migrations/0007_agents_skills_tools_themes.sql` — `agent_skills (agent_id, skill_name)`
   - [ ] D1 agents table: find `SELECT id, title FROM agents WHERE owner_slug = ?` pattern (used to populate WireMenu options)
   - [ ] `one.ie/web/src/components/skills/SkillsView.tsx` — current import-URL form; whether the Import button can be triggered from outside (if not, the header "Import URL" CTA scrolls to `#catalog-import` instead)
   - [ ] `one.ie/web/src/actions/skills.ts` — `skill.fork`, `skill.delete` action IDs (used by ⋯ overflow)
   - [ ] `.claude/rules/design.md` — token mapping for mastery levels

2. **Primitive-inventory recon**
   - [ ] `one.ie/web/src/components/ui/` — popover / dropdown-menu primitive; if absent, native `<details>` fallback
   - [ ] `one.ie/web/src/components/ui/Icon.tsx`, `IconBadge.tsx`
   - [ ] `one.ie/web/src/lib/ui-signal.ts` — `emitClick`

### W2 — Decide  [Opus]

- [ ] **SSR pass in index.astro** — single Promise.all per skill returns `{ skill, mastery, wiredAgentIds }`. One additional D1 query before that returns `agents: { id, title }[]` for the user's slug. Total: 1 D1 query + N R2 prefix-scans (mastery) + N existing loadSkill calls (already happening today). Net cost similar to today; data complete.
- [ ] **Row layout (max-w-3xl single column):**
  ```
  ⚡ refund-policy                     ●mastered   live on 3
     v1.0.2 · $0.03/call
     "Handles refund requests with the 30-day window."
     [tag] [tag]              [Edit]  [Wire ▾]  [⋯]
  ```
- [ ] **Mastery chip colors (token-safe):**
  - `unrun` → `bg-foreground text-font/60`
  - `novice` → `bg-destructive/15 text-destructive`
  - `developing` → `bg-foreground text-font`
  - `proficient` → `bg-secondary/20 text-secondary`
  - `mastered` → `bg-tertiary/20 text-tertiary`
  Chip is wrapped in `<a href="/u/{slug}/skills/{name}#eval">` — click goes to detail page eval section
- [ ] **Body copy:** show `summary` always; fall back to first sentence of `description` only if no summary. `description` (routing trigger) is editor-side
- [ ] **Action cluster:**
  - **Edit** → `<a href="/u/{slug}/skills/{name}/edit">` (no JS)
  - **Wire ▾** → opens `<WireMenu>` popover
  - **⋯** → menu: Run eval now · Fork · View source · Refresh (if `ref:` set) · Delete (confirm → DELETE save endpoint → `location.reload()`)
- [ ] **WireMenu shape:**
  ```ts
  interface WireMenuProps {
    slug: string
    skillName: string
    wiredAgentIds: string[]
    agents: { id: string; title: string }[]  // passed from SSR — no runtime fetch
  }
  ```
  - Empty `agents` → "No agents yet — [Create one →](/u/{slug}/agents/new)"
  - Each agent: `<label><input type=checkbox /> {title}</label>`; toggle → optimistic UI → `POST /api/skills/${skillName}/enable` with `{ agent_id, enabled }` → revert + toast on error
  - Trigger button shows count: "Wire ▾" when 0, "3 agents ▾" when ≥1
- [ ] **Mobile (<640px):** action cluster stacks below the description; chips wrap; "live on N" hidden, count moves into Wire button label
- [ ] **Accessibility:** popover focus-trap; `<button aria-expanded>` on Wire trigger; ⋯ overflow is `role="menu"`; checkboxes have visible labels
- [ ] **Header:** `[+ New skill]` (primary, → `/u/{slug}/skills/new`) + `[Import URL]` (secondary, → `#catalog-import` anchor; SkillsView import form gets `id="catalog-import"`)
- [ ] **Roll-up line under title:** `${count} skills · ${mastered} mastered · ${needsEval} need eval` where `needsEval = skills.filter(s => s.mastery.level === 'unrun').length`
- [ ] **Empty state — three cards:**
  ```
  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ Create   │  │ Import   │  │ Browse   │
  │ → /new   │  │ → #imp   │  │ → scroll │
  └──────────┘  └──────────┘  └──────────┘
  ```
- [ ] **Catalog:** when `skills.length > 0`, wrap `<SkillsView>` in `<details><summary>▸ Browse catalog (N)</summary>`; when 0, render expanded
- [ ] **Hydration:** `<SkillsList client:idle>` wraps all rows in one island (cheaper than N islands; popover interactivity has acceptable idle delay for a manage page)
- [ ] Diff specs for W3
- [ ] **Doc-plan:** update `plans/skills.md` "What is built" — SkillRow, WireMenu, mastery surface, three-card empty state

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/components/skills/WireMenu.tsx` — popover + agent checkboxes + enable POST
- [ ] `one.ie/web/src/components/skills/SkillRow.tsx` — row layout + mastery chip + action cluster + WireMenu
- [ ] `one.ie/web/src/components/skills/SkillsList.tsx` — thin wrapper mapping array → rows (≤30 LOC)
- [ ] `one.ie/web/src/components/skills/SkillsView.tsx` — add `id="catalog-import"` anchor on the import form (1-line edit)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/pages/u/[slug]/skills/index.astro` — (1) extend SSR loop with mastery + wiredAgentIds + agents query; (2) header CTAs; (3) roll-up line; (4) three-card empty state; (5) `<SkillsList client:idle>` for non-empty; (6) `<details>` wrap on catalog

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `WireMenu` imported in `SkillRow.tsx`
- [ ] Grep: `enable` POST in `WireMenu.tsx`
- [ ] Grep: `computeMastery` present in `index.astro` (server) · NOT in `SkillRow.tsx` (UI just reads `mastery.level`)
- [ ] Grep: `aria-expanded` + `role="menu"` present (accessibility floor)
- [ ] Grep: design tokens only — `.claude/hooks/design-check.sh` enforces; no `bg-zinc-*` / hex
- [ ] Grep: empty-state anchor `"Import a skill from the settings page"` returns 0 hits
- [ ] Grep: `"+ New skill"` or `aria-label="Create skill"` present in header
- [ ] Grep: `<details>` (or `Collapsible`) wraps SkillsView when non-empty
- [ ] `wc -l SkillRow.tsx` ≤ 140 · `wc -l WireMenu.tsx` ≤ 90 · `wc -l SkillsList.tsx` ≤ 30
- [ ] `wc -l index.astro` ≤ 120 (current is 160; rewrite is leaner)
- [ ] Reuse audit: inline `<article>` skill card gone from `index.astro`
- [ ] Rubric ≥ 0.65 · simplicity ≥ 0.85

---

## C3 — SkillEditor component  [tier: complex · batch: 2]

**Exit:** `components/skills/SkillEditor.tsx` renders split layout — left: frontmatter form (title/description/price/tags/version — **name is display-only**) + OneEditor body; right: ChatDock — with Save calling `PUT /api/skills/[name]/save`.

### W1 — Recon

- [ ] `one.ie/web/src/components/editor/Editor.tsx` — `OneEditorProps`
- [ ] `one.ie/web/src/components/chat/ChatDock.tsx` — props + `surface` values
- [ ] `one.ie/web/src/lib/skill/parser.ts` — `parse(md) → { meta, body }`
- [ ] `one.ie/web/src/lib/skill/emit.ts` — `buildFrontmatter` or equivalent
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — confirms C1 endpoint
- [ ] `one.ie/web/src/components/ui/` — `Input`, `Textarea`, `Spinner`

### W2 — Decide  [Opus]

- [ ] **Props:**
  ```ts
  interface SkillEditorProps {
    slug: string
    name: string            // empty = new skill
    initialContent: string  // full SKILL.md
    isNew?: boolean
  }
  ```
- [ ] **Left (60%):** header bar with `name` shown as `<code>` (non-editable) + Save + (if !isNew) Delete. Frontmatter form for `title`, `description`, `price`, `tags`, `version`. Separator. `OneEditor` for body
- [ ] **Right (40%):** `ChatDock surface="skills"`
- [ ] **Name rule:** for new skills, the name comes from a URL slug or first save derives it from `title.toKebabCase()`. For existing skills, name is locked (rename would orphan R2 + D1 rows — out of scope, see Decisions table)
- [ ] **Parse on mount:** `parser.parse(initialContent)` splits frontmatter from body
- [ ] **Save:** rebuild SKILL.md → `PUT /api/skills/${name}/save` with `{ content, slug }`; spinner → "Saved" badge → revert after 2s
- [ ] **First save of new skill:** derive name from title slug → `location.href = /u/${slug}/skills/${derivedName}/edit`
- [ ] **Delete:** confirm → `DELETE /api/skills/${name}/save` → navigate to `/u/${slug}/skills`
- [ ] **LOC target:** ≤200 — compose-first
- [ ] Diff specs for W3

### W3 — Edit  [Sonnet]

**W3a — independent:**
- [ ] `one.ie/web/src/components/skills/SkillEditor.tsx`

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `OneEditor` + `ChatDock` + `parse` + `emitClick` present
- [ ] Grep: no rename — name input is `<code>` / `readonly` / display-only (e.g. no `onChange` bound to a `name` setter)
- [ ] No reimplementation: `grep -n "tiptap\|EditorRoot\|EditorContent" SkillEditor.tsx` → 0
- [ ] No reimplementation: `grep -n "useChat\|SSE\|EventSource" SkillEditor.tsx` → 0
- [ ] `wc -l SkillEditor.tsx` ≤ 200
- [ ] Rubric ≥ 0.65 · security ≥ 0.90

---

## C4 — New + edit pages  [tier: simple · batch: 3]

**Exit:** `/u/[slug]/skills/new` renders SkillEditor with blank template. `/u/[slug]/skills/[name]/edit` renders SkillEditor pre-loaded from R2 (404 if not found).

### W1 — Recon

- [ ] `one.ie/web/src/pages/u/[slug]/skills/[name].astro` — SSR shell + `loadSkill` call + R2 env access
- [ ] `one.ie/web/src/components/skills/SkillEditor.tsx` — confirms C3 component export
- [ ] `one.ie/web/src/layouts/Layout.astro` — `title`, `sidebar`, `chat`, `profileSlug` props

### W2 — Decide  [Sonnet]

- [ ] **`new.astro`:** `prerender = false`; imports `SkillEditor`; passes blank template; `isNew=true`; `client:only="react"`
- [ ] **Blank template** (hardcoded):
  ```
  ---
  name: untitled
  title: Untitled Skill
  description: Use this skill when the user asks to...
  price: 0
  tags: []
  version: 1.0.0
  ---

  # Untitled Skill

  Describe what this skill does.

  ## Instructions

  1. Understand the request
  2. Apply these rules
  3. Produce the output
  ```
  Default price 0 (lowers friction; user opts into paid)
- [ ] **`edit.astro`:** `prerender = false`; reads `slug` + `name` from `Astro.params`; calls `loadSkill(${slug}/skills/${name}, env.CONTENT)`; 404 if not found; passes raw content
- [ ] Diff specs for W3

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/pages/u/[slug]/skills/new.astro` — ≤30 LOC
- [ ] `one.ie/web/src/pages/u/[slug]/skills/[name]/edit.astro` — ≤40 LOC

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `SkillEditor` imported in both
- [ ] Grep: `loadSkill` used in `edit.astro`
- [ ] Grep: `client:only="react"` in both
- [ ] `wc -l new.astro` ≤ 30 · `wc -l edit.astro` ≤ 40
- [ ] Rubric ≥ 0.65

---

## C5 — Detail page eval section  [tier: complex · batch: 4]

**Gap:** SkillRow's mastery chip and overflow `Run eval now` link to `/u/[slug]/skills/[name]#eval`, but `[name].astro` has no eval section — users land at the top with no benchmark, no curve, no run button. Eval surface is invisible outside chat.

**Exit:** `/u/[slug]/skills/[name]` SSR-renders an `<section id="eval">` block showing mastery curve, latest benchmark, iteration list, and a "Run eval now" button that POSTs to `/api/eval` and reloads. Existing chat-side `EvalCard` is reused (or a sibling `SkillEvalPanel` if its props don't fit). No new endpoint — `/api/eval` already exists.

### W1 — Recon

1. **Existing-code recon**
   - [ ] `one.ie/web/src/pages/u/[slug]/skills/[name].astro` — current shape; where the eval section gets inserted (after body, before footer or as a new card)
   - [ ] `one.ie/web/src/pages/api/eval.ts` — request/response contract; auth shape (PUBLIC anonymous run today — does C5 need to gate or leave open?)
   - [ ] `one.ie/web/src/lib/eval/mastery.ts` — `masteryFromHistory(benches)` already returns `{ level, prob, sampleCount, curve, improving }` — the curve is exactly what the panel needs
   - [ ] `one.ie/web/src/components/chat/EvalCard.tsx` — confirm if it can be lifted into a non-chat surface (uses `BenchmarkResult` + optional `onIterate` callback — should be portable)
   - [ ] `one.ie/web/src/pages/u/[slug]/skills/index.astro` lines 21–40 — the `loadMastery` SSR loop. Extract to a shared loader (`lib/eval/load-history.ts`) so the detail page reuses it without duplication

2. **Primitive-inventory recon**
   - [ ] `lib/eval/aggregate.ts` — `BenchmarkResult` shape
   - [ ] Test-case load path: `<slug>/skills/<name>/evals/evals.json` — does it exist in R2 today for any installed skill? (controls empty-state copy)

### W2 — Decide  [Opus]

- [ ] **Extract `loadHistory`** to `one.ie/web/src/lib/eval/load-history.ts` — returns `{ benches: BenchmarkResult[], mastery, hasEvals: boolean }`. Index page + detail page both call it
- [ ] **Detail page SSR** — call `loadHistory(slug, name, env.CONTENT)`. Pass to a new `<SkillEvalPanel>` React component
- [ ] **`SkillEvalPanel`** props:
  ```ts
  interface SkillEvalPanelProps {
    slug: string
    name: string
    benches: BenchmarkResult[]     // newest first
    mastery: MasteryReport
    hasEvals: boolean              // false → show "no evals.json — author tests in /edit" CTA
  }
  ```
- [ ] **Layout (inside `<section id="eval">`):**
  - Header: "Eval" + mastery chip (matches SkillRow chip colors)
  - **Mastery curve** — small sparkline of `mastery.curve[].prob` (SVG, no external lib)
  - **Latest benchmark** — reuse `<EvalCard benchmark={benches[0]}>` if present; else "Not run yet"
  - **Iteration list** — collapsible table of older iterations (iteration · pass_rate · delta · timestamp)
  - **"Run eval now"** primary button — `POST /api/eval` with `{ slug, skillPath: name, iteration: benches.length + 1 }`; spinner during run; `location.reload()` on completion
  - **Empty state** when `!hasEvals` — "No test cases yet. Author them in the editor." → link to `/edit#tests` (C7 will add the tab)
- [ ] **Eval endpoint auth check** — confirm `/api/eval` is fine to call from session-only browsers (it's PUBLIC today per the comment at `api/eval.ts:19`). If C5 wants to restrict to workspace owner, gate via `requireAuth` + `principal.slug === slug` — but that's a separate decision. **Lock: leave PUBLIC for now; revisit if abuse**
- [ ] **Fork hash anchor:** add `<section id="fork">` placeholder under eval, rendering a one-line "Fork this skill →" link to a fork modal (wired in C6). Keeps SkillRow's `#fork` link from being dead today
- [ ] **Reuse audit:** if `EvalCard` is chat-coupled (imports MessageList, etc.), **don't lift it** — render the same numbers inline in `SkillEvalPanel`. W1 reconnaissance decides
- [ ] Diff specs for W3
- [ ] **Doc-plan:** `plans/skills.md` — add detail page eval section to "What is built"; `plans/evaluate.md` — add "Surface" section noting `/u/[slug]/skills/[name]#eval` as the human-readable surface

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/eval/load-history.ts` — extract (≤50 LOC)
- [ ] `one.ie/web/src/components/skills/SkillEvalPanel.tsx` — new (≤180 LOC)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/pages/u/[slug]/skills/[name].astro` — import + insert `<section id="eval">` and `<section id="fork">` placeholder
- [ ] `one.ie/web/src/pages/u/[slug]/skills/index.astro` — swap inline `loadMastery` for `loadHistory` from the shared module

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `<section id="eval"` and `<section id="fork"` present in `[name].astro`
- [ ] Grep: `SkillEvalPanel` imported in `[name].astro`
- [ ] Grep: `loadHistory` used in BOTH `index.astro` AND `[name].astro` (no duplication)
- [ ] Grep: `loadMastery` removed from `index.astro` (replaced by `loadHistory`)
- [ ] Grep: `/api/eval` POST present in `SkillEvalPanel.tsx`
- [ ] `wc -l SkillEvalPanel.tsx` ≤ 180 · `wc -l load-history.ts` ≤ 50
- [ ] Rubric ≥ 0.65 · simplicity ≥ 0.80

---

## C6 — Wire overflow actions (fork · refresh · run eval)  [tier: simple · batch: 5]

**Gap:** SkillRow's `⋯` menu items are dead links — `Fork` and `Run eval now` go to non-existent anchors; `Refresh` isn't even surfaced. The Astro actions `skill.fork`, `skill.refresh`, `skill.eval` exist but aren't reachable from the dashboard.

**Exit:** Clicking `⋯ → Fork` calls `skill.fork` and navigates to the new skill's edit page. `⋯ → Refresh` (visible only when `ref:` set) calls `skill.refresh` and reloads. `⋯ → Run eval now` calls `/api/eval` directly (no anchor jump) and shows toast + reloads.

### W1 — Recon

- [ ] `one.ie/web/src/components/skills/SkillRow.tsx` — current `OverflowMenu` shape; how to add async handlers without bloating to >140 LOC budget
- [ ] `one.ie/web/src/actions/skills.ts` — `skill.fork` / `skill.refresh` IDs + input shapes
- [ ] How to invoke an Astro action from a React island — check existing pattern (`actions:` client export from `astro:actions` or POST to `/_actions/<id>`)
- [ ] Does any skill in our test workspace have `ref:` in its frontmatter today? (controls Refresh visibility — pass as prop)

### W2 — Decide  [Sonnet]

- [ ] **Prop extension:** `SkillRow` gets `skill.ref?: string` already present in `Skill` type — surface as `hasRef = Boolean(skill.ref)`. Refresh menu item renders only if `hasRef`
- [ ] **Fork:** prompt for new name (default `${name}-fork`) → call action via `actions.skill.fork({ name, forkName })` → on success `location.href = /u/{slug}/skills/{forkName}/edit`
- [ ] **Refresh:** confirm → `actions.skill.refresh({ name })` → on success `location.reload()`; on `no ref:` error toast
- [ ] **Run eval:** `POST /api/eval` with `{ slug, skillPath: name, iteration: ? }` — iteration count requires loadHistory; cheapest path is to just send `iteration: 1` and let server decide. Or: link to `#eval` and let C5's panel handle it. **Lock: keep the menu item but make it scroll to `#eval` + flash the Run button** (zero extra logic; C5 owns the action). Strikes the right separation
- [ ] **Toast primitive:** check `components/ui/` — if absent, inline a 2s fade `<div role="status">` at top-right; keep ≤ 20 LOC
- [ ] Diff specs for W3
- [ ] **Doc-plan:** none — internal rewire

### W3 — Edit  [Sonnet]

**W3a — independent:**
- [ ] `one.ie/web/src/components/skills/SkillRow.tsx` — extend `OverflowMenu` with fork + refresh handlers; gate Refresh on `hasRef`; replace `Run eval now` href to scroll-and-flash `#eval`

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `skill.fork` AND `skill.refresh` reachable from `SkillRow.tsx`
- [ ] Grep: `hasRef` gates the Refresh menu item
- [ ] Grep: no remaining `href="#fork"` dead anchor in the codebase
- [ ] `wc -l SkillRow.tsx` ≤ 180 (was 140; extension budget +40)
- [ ] Rubric ≥ 0.65

---

## C7 — SUPERSEDED → see C12

This cycle's scope (test-case editor as a tab in `SkillEditor`) is absorbed into **C12**, which adds the Tests panel inside the new `SkillStudio` surface. The endpoint design (`PUT /api/skills/[name]/evals` mirroring C1's auth) is preserved in C12.

<details>
<summary>Original C7 spec — kept for context (do not run as a cycle)</summary>

### Original C7 — Test-case editor in SkillEditor  [tier: complex · batch: 5]

**Gap:** A skill's `evals.json` (the test bank) is mentioned in `plans/evaluate.md` and consumed by `/api/eval`, but there is no UI to read or write it. Users can't author tests without dropping into chat or hand-editing R2. Eval is the loudest unmet need on this dashboard.

**Exit:** `SkillEditor` gains a **Tests** tab (or accordion section) showing the current `evals.json` as a structured list of `TestCase` rows — prompt, expected, assertions. Add/edit/delete row. Save persists to `<slug>/skills/<name>/evals/evals.json` via a new `PUT /api/skills/[name]/evals` endpoint (session-authed, slug-bound — mirrors C1's save endpoint).

### W1 — Recon

- [ ] `one.ie/web/src/lib/eval/runner.ts` — `TestCase` type (prompt, expected, assertions[])
- [ ] `one.ie/web/src/pages/api/eval.ts` — confirms R2 key `<slug>/skills/<name>/evals/evals.json` is THE canonical path
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — auth pattern to mirror exactly (session + slug check)
- [ ] `one.ie/web/src/components/skills/SkillEditor.tsx` — current layout; whether to add tabs (Frontmatter · Body · Tests) or stack the Tests panel under the body. Tabs are cleaner; SkillEditor at 200 LOC budget needs care
- [ ] `one.ie/web/src/components/ui/` — Tabs primitive (shadcn)? If absent, native `<details>` accordion

### W2 — Decide  [Opus]

- [ ] **New endpoint:** `PUT /api/skills/[name]/evals` — body `{ cases: TestCase[], slug }`. `DELETE` not needed (delete-all = save empty array). Auth identical to C1's `save.ts` — `requireAuth` + `principal.slug === body.slug` → 403 otherwise → R2 write to `<slug>/skills/<name>/evals/evals.json`. **GET** also added: returns the current cases (so the editor can load without exposing R2 paths)
- [ ] **Tabs vs accordion:** if a Tabs primitive exists, use it (Frontmatter · Body · Tests). Else accordion under body — `<details><summary>Tests (N)</summary>`. W1 decides
- [ ] **Test row UI:**
  ```
  ┌──────────────────────────────────────────────┐
  │ Prompt        │ Need a $450 refund...        │
  │ Expected      │ Escalates — does not auto... │
  │ Assertions ▼  │ • Refund amount > $100       │
  │               │ • Asks for manager approval  │
  │               │   [+ Add assertion]          │
  │ [Delete row]                                 │
  └──────────────────────────────────────────────┘
  ```
  Each field: `<textarea>` with token-safe styling (`bg-background` per design rules)
- [ ] **State:** `useState<TestCase[]>` initialised from a fetch on mount (`GET /api/skills/{name}/evals`); Save button POSTs whole array; reuse the existing "Saved" badge pattern from C3
- [ ] **Empty state:** "No tests yet. Add one to get started." + `[+ Add test case]`
- [ ] **LOC budget:** SkillEditor +80 (currently ~200, target ≤ 280); endpoint ≤ 60
- [ ] **Decision: new vs extend save.ts?** — tests are a separate R2 object with a separate verb. **new** — keeping `save.ts` focused on SKILL.md is the cleaner cut. Compress check verdict: `new` justified
- [ ] Diff specs for W3
- [ ] **Doc-plan:** `plans/evaluate.md` — note the new endpoint + UI surface; `plans/skills.md` — add Tests tab to component description and add endpoint to API table

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/pages/api/skills/[name]/evals.ts` — new (GET + PUT, ≤60 LOC)
- [ ] `one.ie/web/src/components/skills/TestCaseEditor.tsx` — new (≤180 LOC, list + add/edit/delete)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/components/skills/SkillEditor.tsx` — integrate Tests tab/accordion; mount `<TestCaseEditor name={name} slug={slug} />`

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `requireAuth` + `principal.slug` check present in `evals.ts`
- [ ] Grep: `TestCaseEditor` imported in `SkillEditor.tsx`
- [ ] Grep: `GET /api/skills` + `PUT /api/skills` paths present in `TestCaseEditor.tsx`
- [ ] `wc -l evals.ts` ≤ 60 · `wc -l TestCaseEditor.tsx` ≤ 180 · `wc -l SkillEditor.tsx` ≤ 280
- [ ] Rubric ≥ 0.65 · security ≥ 0.90

</details>

---

## C8 — Three primary verbs: Edit · Add to agent · Evaluate  [tier: simple · batch: 6]

**Gap (vocabulary + promotion):**
1. SkillRow currently shows `[Edit] [Wire ▾] [⋯]`. "Wire" is internal jargon (pheromone/substrate vocabulary — memory:`feedback_marketing_copy` says drop it for users). The persona-correct label is **Add to agent**.
2. Evaluate is buried — clickable mastery chip + overflow item only. Per user feedback ("can't see evals in UI"), it must be a top-level row verb.
3. The current `Run eval now` overflow menu item navigates to `#eval` (C5 owns that); C8 promotes the same action to a row-level button so users don't need to read the chip to find it.

**Exit:** Row action cluster is `[Edit] [Add to agent ▾] [Evaluate]` (in that order — Edit primary, Add secondary, Evaluate tertiary). `⋯` overflow keeps Fork · Refresh · View source · Delete. `WireMenu` renamed to `AddToAgentMenu` (file + symbol). Edit button continues to route to `/u/{slug}/skills/{name}/edit` which already uses `OneEditor` (the same component `pages/editor.astro` showcases) via `SkillEditor` — no editor refactor needed.

### W1 — Recon

- [ ] `one.ie/web/src/components/skills/SkillRow.tsx` — confirm action cluster layout; what's the mobile collapse rule from C2 (≤640px stacks)
- [ ] `one.ie/web/src/components/skills/WireMenu.tsx` — rename target; confirm no other importer beyond `SkillRow.tsx`
- [ ] `one.ie/web/src/pages/editor.astro` + `components/editor/Editor.tsx` + `EditorDemo.tsx` — confirm `OneEditor` is the surface shared between `/editor` and `SkillEditor`. (Sanity check: user's request "edit skills using the component in pages/editor" is already satisfied via `SkillEditor → OneEditor`. C8 verifies, doesn't refactor.)
- [ ] `plans/skills.md` "Profile page action buttons" section — current copy says `[Edit] [Wire ▾] [⋯]`; update target
- [ ] Grep all `.md`, `.tsx`, `.astro` for user-facing strings: `"Wire"`, `"wire"`, `"wired"`, `"WireMenu"` — separate persona copy (rename) from internal code (free to keep or move)

### W2 — Decide  [Sonnet]

- [ ] **Rename scope:**
  - **File:** `WireMenu.tsx` → `AddToAgentMenu.tsx` (component file + symbol)
  - **Trigger button label:** `Wire ▾` → `Add to agent ▾` when 0 wired; `On {N} agents ▾` when ≥1 (replaces "3 agents ▾" — keeps the count, swaps the noun)
  - **Component PropType name:** `WireMenuProps` → `AddToAgentMenuProps`
  - **Emit-click receiver:** `ui:skills:wire` → `ui:skills:add-agent` (per `.claude/rules/ui.md` naming — surface=skills, action verb)
  - **Internal D1 column `agent_skills` stays unchanged** — it's substrate, not user copy. Per the locked-rule "Don't rename dimensions/verbs/outcomes," substrate names stay
- [ ] **Promote Evaluate to top-level button:**
  - Add `[Evaluate]` button after `[Add to agent ▾]`
  - Behavior: scroll-and-flash strategy from C6 — `<a href="/u/{slug}/skills/{name}#eval">Evaluate</a>` (no JS; C5 panel handles the run). Keeps SkillRow LOC stable; the eval surface lives where it should
  - Style: outline (`border-primary text-font`) so it doesn't compete with Edit (filled primary) or Add (filled secondary)
- [ ] **Overflow menu after C8:** drop the dead `Run eval now` item (promoted); keep Fork (C6) · Refresh (C6) · View source · Delete
- [ ] **Mobile (≤640px):** three buttons stack to a single row with `flex-wrap`; mastery chip stays in the top-right. "live on N" line still hidden on mobile per C2
- [ ] **Edit-page sanity:** open `SkillEditor.tsx` mentally — it composes `OneEditor` (the prose surface) + form fields + ChatDock. User's note "we had edit skills using the component in pages/editor" is **already true** via OneEditor. No edit-page change in C8. If a future cycle wants to swap the split layout for a `/editor`-style fullscreen, that's a separate todo
- [ ] **Doc-plan:**
  - `plans/skills.md` "Profile page action buttons" — rewrite for three primary verbs; mark Evaluate as primary; mention `AddToAgentMenu` in Components table
  - `plans/skills.md` "What is built" — update the dashboard row description
- [ ] Diff specs for W3

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/components/skills/WireMenu.tsx` → **rename via `git mv`** to `AddToAgentMenu.tsx`; replace exported symbol + props type; replace `ui:skills:wire` emit receiver with `ui:skills:add-agent`
- [ ] `one.ie/web/src/components/skills/SkillRow.tsx` — update import path + symbol; add `[Evaluate]` button between `AddToAgentMenu` and `OverflowMenu`; drop `Run eval now` from overflow

**W3b — sequenced (after W3a, doc propagate):**
- [ ] `plans/skills.md` — rewrite Profile-page-actions section + What-is-built line; update Components table row

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: zero hits for `WireMenu` (file, symbol, or import) — exception: a single one-line note in `learnings.md` is acceptable
- [ ] Grep: `AddToAgentMenu` imported in `SkillRow.tsx`
- [ ] Grep: `Add to agent` literal string present in `AddToAgentMenu.tsx`
- [ ] Grep: `<a href={\`/u/${slug}/skills/${skill.slug}#eval\`}>Evaluate</a>` (or equivalent) present in `SkillRow.tsx`
- [ ] Grep: `Run eval now` removed from `SkillRow.tsx` overflow
- [ ] Grep: `ui:skills:add-agent` receiver present; `ui:skills:wire` removed
- [ ] Grep on docs: `**/*.md` has 0 hits for `"WireMenu"` or `"Wire ▾"` in user-facing prose (substrate D1 table `agent_skills` mentions OK)
- [ ] `wc -l SkillRow.tsx` ≤ 200 (was ~140 + ~10 for Evaluate button + relabel) — if over budget, factor `OverflowMenu` out
- [ ] Rubric ≥ 0.65 · simplicity ≥ 0.80

---

## C9 — SUPERSEDED → see C10

`PropertiesBlock` is folded into **C10** (SkillStudio shell), where it's the canonical frontmatter surface for the unified editor. The component contract is preserved verbatim in C10's W2.

<details>
<summary>Original C9 spec — kept for context (do not run as a cycle)</summary>

### Original C9 — Elegant YAML frontmatter editor (Properties block)  [tier: complex · batch: 7]

**Gap:** `SkillEditor` renders frontmatter as a flat stack of labeled inputs (Title, Description, Price, Tags, Version — five tall fields above the body). It works but is bulky, doesn't scale to new fields (`ref:`, `license`, custom keys), and doesn't feel like editing structured data — it feels like a settings form bolted on top of a doc. Skill files are YAML+markdown; the editor should treat the YAML elegantly, the way Notion treats page properties or Obsidian treats frontmatter.

**Exit:** Frontmatter renders as a compact **Properties** block at the top of the editor — one row per key, key on the left (subtle label), value on the right (inline-editable, type-aware). Schema-known keys (title/description/price/tags/version/ref/license) render with the right widget (string / textarea / number / chip-list / url); unknown keys render as a plain text value with the raw key. A `+ Add property` row lets users add new keys. The whole block collapses to a one-line summary (`5 properties`) by default on existing skills; expands on click. Save still emits canonical YAML via `emitSkill`.

### W1 — Recon

- [ ] `one.ie/web/src/components/skills/SkillEditor.tsx` — current frontmatter form lines 122–183; how `parsed.meta` (Record<string, unknown>) is consumed
- [ ] `one.ie/web/src/lib/skill/parser.ts` — `parse(md)` → `{ meta, body }`; what shape `meta` actually takes (key list, value types in practice)
- [ ] `one.ie/web/src/lib/skill/emit.ts` — `buildFrontmatter` or equivalent; what key order/formatting it produces; does it preserve unknown keys?
- [ ] `one.ie/web/src/components/editor/Editor.tsx` — `OneEditor` props; whether it exposes a "header slot" or if Properties must live above the editor's `<EditorContent>` in the parent
- [ ] `one.ie/web/src/components/editor/EditorDemo.tsx` — see what surface treatment `/editor` uses; whether Properties block should adopt the same card framing
- [ ] Existing precedent: search for "Properties" / "key-value editor" in the codebase — `grep -r 'aria-label="property"' src/` and similar — to avoid reinventing
- [ ] Token usage: confirm the depth pattern. Properties block sits inside the card body, so it should use `bg-foreground` (L2) outer with `bg-background` (L0) inputs per `design.md`

### W2 — Decide  [Opus]

- [ ] **Properties schema (intrinsic + extensible):**
  ```ts
  interface PropertyDef {
    key: string
    label: string                          // human label; key is the YAML name
    type: 'string' | 'text' | 'number' | 'tags' | 'url' | 'readonly'
    placeholder?: string
    hint?: string
  }
  const KNOWN: PropertyDef[] = [
    { key: 'name',        label: 'Name',        type: 'readonly', hint: 'Filename — rename via fork' },
    { key: 'title',       label: 'Title',       type: 'string' },
    { key: 'description', label: 'Description', type: 'text', placeholder: 'Use this skill when…' },
    { key: 'price',       label: 'Price',       type: 'number', hint: 'USD per call' },
    { key: 'tags',        label: 'Tags',        type: 'tags' },
    { key: 'version',     label: 'Version',     type: 'string' },
    { key: 'ref',         label: 'Source URL',  type: 'url',  hint: 'Refresh pulls from here' },
    { key: 'license',     label: 'License',     type: 'string' },
  ]
  ```
- [ ] **Component:** new `PropertiesBlock.tsx` (≤180 LOC) — accepts `meta: Record<string, unknown>`, `onChange: (next) => void`, `readonlyKeys?: string[]` (e.g., `['name']`). Renders one row per key in `KNOWN` order, then any extra keys from `meta` not in `KNOWN`. Final row: `[+ Add property]` opens a tiny popover with `key` + `type` inputs
- [ ] **Row layout (Notion-style):**
  ```
  ┌──────────────────────────────────────────────┐
  │ ⚡  Name         untitled  ▸ filename — fork to rename │
  │ Aa  Title        Refund handler              │
  │ ¶   Description  Handles 30-day refund window with… │
  │ #   Price        $0.02                        │
  │ ⌗   Tags         [policy] [refund] [+ add]   │
  │ v   Version      1.0.2                        │
  │ ↗   Source URL   (empty)                      │
  │ ⊕   Add property                              │
  └──────────────────────────────────────────────┘
  ```
  Icons are lucide (Zap, Type, AlignLeft, Hash, Tag, GitBranch, Link, Plus) via `<Icon>` — never Unicode glyphs
  Key column: fixed width (`w-32`), `text-font/60 text-sm`, with icon + label
  Value column: `flex-1`, takes the rest, uses the right input widget per type
- [ ] **Collapse:** outer `<details>` defaults closed on existing skills with ≥3 props set; defaults open on `isNew`. Summary line: `5 properties · Refund handler · v1.0.2 · $0.02/call` — uses key→summary projection: title first, then version+price
- [ ] **State integration in SkillEditor:**
  - Replace the five `useState` calls (title/description/price/tags/version) with **one** `useState<Record<string, unknown>>(parsed.meta)`
  - On save: pass the whole `meta` object to `emitSkill` — `emit.ts` writes it back as YAML preserving unknown keys (W1 verifies this is already true; if not, treat as a sub-spec)
  - Inline keys: `meta.title`, `meta.description`, etc. — derived for the save payload, no per-field setters
- [ ] **Tags widget:** chip-input — Enter or comma commits a tag, Backspace on empty input removes the last. Existing `tags` are an array in `meta`; serialize as `string[]` in YAML (`emit.ts` handles)
- [ ] **Validation:** soft only. `price` non-numeric → red border + hint; `ref` not a URL → red border + hint. Don't block save (frontmatter authors may know what they're doing)
- [ ] **Doc-plan:**
  - `plans/skills.md` — Components table: add `PropertiesBlock` row; "What is built": note the Properties experience
  - **No change to `plans/evaluate.md`** — frontmatter doesn't touch evals
- [ ] **Compress check:**
  - PRIMITIVE: `PropertiesBlock` (new component)
  - COMPOSE: could we use a generic form library + a YAML adapter? No existing form lib in the repo; rolling a 180-LOC component is cheaper than adding a dep
  - VERDICT: **new** — justified; no existing primitive in `components/ui/` covers structured properties editing. Keeps it scoped to skills surface only (don't generalize until a second use case appears)
- [ ] Diff specs for W3

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/components/skills/PropertiesBlock.tsx` — new (≤180 LOC)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/components/skills/SkillEditor.tsx` — replace lines 22–32 (per-field useState) with single `meta` state; replace lines 122–183 (form fields) with `<PropertiesBlock meta={meta} onChange={setMeta} readonlyKeys={['name']} />`; update `handleSave` to read `meta.title`, `meta.description`, etc. when building the `Skill` object passed to `emitSkill`

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `PropertiesBlock` imported in `SkillEditor.tsx`
- [ ] Grep: zero remaining `useState.*title|useState.*description|useState.*price|useState.*tags|useState.*version` in `SkillEditor.tsx` (single `meta` state)
- [ ] Grep: lucide imports used for property-row icons; NO Unicode glyphs (`☀ ☾ ▾ ✓ ✗` etc.) per `.claude/rules/design.md`
- [ ] Grep: no Tailwind palette classes (`bg-zinc-*` etc.); only design tokens
- [ ] Round-trip test (manual smoke or vitest snapshot): load skill with frontmatter `{ title, custom_field: "value" }` → `PropertiesBlock` shows both → save → R2 content still contains `custom_field: value` (unknown keys preserved)
- [ ] `wc -l PropertiesBlock.tsx` ≤ 180 · `wc -l SkillEditor.tsx` net delta ≤ 0 (replacement, not addition — five form blocks out, one component import in)
- [ ] Rubric ≥ 0.65 · simplicity ≥ 0.85 (SkillEditor LOC should drop after the swap)

</details>

---

## Studio arc (C10 → C11 → C12) — the unified vision

**The pitch:** `/u/{slug}/skills/{name}/edit` becomes **SkillStudio** — one surface where the human edits the skill on the left, the chat refines it on the right, and both are touching the *same draft*. The `skill-creator` agent (already auto-imported into every workspace via `lib/skill/auto-import.ts`) is the brain on the right; it can read the current draft, propose changes, and write them back through tool calls. The human still owns Save. Test cases live in a tab in the same studio so the loop is: write → test → refine → save → eval, all in one place.

Three primitives make this work:
1. **A shared draft store** the editor + chat both read & write (`lib/skill/studio-store.ts`) — C10
2. **Chat tools** that mutate the draft (not R2) until Save: `skill.draft.read · set_frontmatter · set_body · append_body · suggest_test_case` — C11
3. **Test cases panel** that joins the same studio (Properties · Body · Tests · Chat) — C12

After this arc lands, `SkillEditor.tsx` is replaced by `SkillStudio.tsx`. The "primary path" for skill authoring shifts: chat-led for new skills (skill-creator interviews and writes), human-led for tweaks, both equally first-class because they touch the same draft state.

---

## C10 — SkillStudio shell + shared draft store + Properties block  [tier: complex · batch: 7]

**Goal:** Replace `SkillEditor` with `SkillStudio`. New foundation: a shared draft store (`meta` + `body`) that the Properties block, OneEditor body, and (future) chat all subscribe to. Chat wiring is **stubbed but inert** in C10 — C11 lights it up. This cycle's value: clean store + elegant Properties surface + zero behavioral regression vs SkillEditor.

**Exit:** `/u/{slug}/skills/{name}/edit` and `/new` render `<SkillStudio>` with three columns / regions: **Properties** (collapsible card at top) + **Body** (OneEditor) + **Chat** (ChatDock surface="skills" — read-only context for now). Save uses store snapshot. `SkillEditor.tsx` is deleted. No new endpoints.

### W1 — Recon

1. **Existing-code recon**
   - [ ] `one.ie/web/src/components/skills/SkillEditor.tsx` — full current shape (lines 1–200); what to lift, what to drop
   - [ ] `one.ie/web/src/components/editor/Editor.tsx` — `OneEditor` props; `content` vs `onMarkdownChange`; does it accept a controlled value or does it own its own state?
   - [ ] `one.ie/web/src/components/chat/ChatDock.tsx` — current surface prop + how `surface-context` is consumed; whether ChatDock can receive extra context (a `skillDraft` snapshot for chat to read)
   - [ ] `one.ie/web/src/lib/surface-context.ts` — extension shape: how to add `skillDraft?: { name, meta, body }` to the existing context without breaking other surfaces
   - [ ] `one.ie/web/src/lib/skill/parser.ts` + `emit.ts` — confirm round-trip preserves unknown frontmatter keys (W2 needs this for the Properties open-set behavior)
   - [ ] `one.ie/web/src/pages/u/[slug]/skills/[name]/edit.astro` + `/new.astro` — current SkillEditor mount points; SkillStudio swap location
   - [ ] State libs in repo: `grep -r "from 'zustand'" one.ie/web/src` and `grep -r "createStore" one.ie/web/src` — if zustand exists in deps, use it; else a `useSyncExternalStore` + module-level state primitive (≤30 LOC)

2. **Primitive-inventory recon**
   - [ ] `components/ui/` — Tabs primitive (for Properties · Body · Tests tabs in C12) or whether a custom tab list is needed
   - [ ] Lucide icons available: Zap, Type, AlignLeft, Hash, Tag, GitBranch, Link, Plus, ChevronDown — confirm present in current `lucide-react` import surface

### W2 — Decide  [Opus]

- [ ] **Store shape (`lib/skill/studio-store.ts`):**
  ```ts
  export interface SkillDraft {
    slug: string
    name: string                 // empty if isNew
    isNew: boolean
    meta: Record<string, unknown>
    body: string
    dirty: boolean
    savedAt: number | null
  }
  export interface StudioStore {
    get(): SkillDraft
    subscribe(listener: () => void): () => void
    setMeta(patch: Partial<Record<string, unknown>>): void
    setBody(body: string): void
    appendBody(text: string): void
    markSaved(): void
    snapshot(): SkillDraft         // for tools.read() — returns frozen copy
  }
  ```
  Implementation: module-level `let state` + `Set<listener>` + `useSyncExternalStore`. ≤80 LOC. **Don't add zustand** unless W1 finds it already in deps.

- [ ] **`SkillStudio.tsx`** props identical to old `SkillEditor`:
  ```ts
  interface SkillStudioProps {
    slug: string
    name: string                // '' = new
    initialContent: string
    isNew?: boolean
  }
  ```
  On mount: `parse(initialContent)` → `studioStore.init({ slug, name, isNew, meta, body })`. From then on, all reads + writes go through the store.

- [ ] **Layout:** three regions, responsive
  ```
  ┌──────────────────────────────────────────────────────────────────┐
  │ untitled                              [Saved 2s]  [Delete] [Save]│
  ├──────────────────────────────────────────────────────────────────┤
  │ ▾ Properties                                                     │
  │   ⚡ Name        untitled  · filename — fork to rename            │
  │   Aa Title       Refund handler                                  │
  │   ¶  Description Handles 30-day refund window with…              │
  │   #  Price       $0.02                                           │
  │   ⌗  Tags        [policy] [refund] [+ add]                       │
  │   v  Version     1.0.2                                           │
  │   ↗  Source URL  (empty)                                         │
  │   ⊕  Add property                                                │
  ├──────────────────────┬───────────────────────────────────────────┤
  │ Body (OneEditor)     │ Chat (ChatDock surface="skills")          │
  │ — slash commands     │ — read-only context in C10                │
  │ — embed components   │ — co-editing lit up in C11                │
  │                      │                                           │
  └──────────────────────┴───────────────────────────────────────────┘
  ```
  Mobile (≤900px): Chat moves to a bottom drawer.

- [ ] **`PropertiesBlock` contract** — verbatim from old C9 (folded here):
  ```ts
  interface PropertyDef {
    key: string; label: string
    type: 'string' | 'text' | 'number' | 'tags' | 'url' | 'readonly'
    placeholder?: string; hint?: string
  }
  const KNOWN: PropertyDef[] = [
    { key: 'name',        label: 'Name',        type: 'readonly', hint: 'Filename — fork to rename' },
    { key: 'title',       label: 'Title',       type: 'string' },
    { key: 'description', label: 'Description', type: 'text' },
    { key: 'price',       label: 'Price',       type: 'number', hint: 'USD per call' },
    { key: 'tags',        label: 'Tags',        type: 'tags' },
    { key: 'version',     label: 'Version',     type: 'string' },
    { key: 'ref',         label: 'Source URL',  type: 'url',  hint: 'Refresh pulls from here' },
    { key: 'license',     label: 'License',     type: 'string' },
  ]
  ```
  Reads `meta` from store via `useStudioDraft()`; writes through `store.setMeta({ [key]: value })`. Unknown keys render after KNOWN. `+ Add property` opens a tiny popover (key + type picker).

- [ ] **Body editor:** `<OneEditor content={initialBody} onMarkdownChange={store.setBody} />`. `initialBody` is read once from `store.get().body`; the editor owns its DOM but pushes changes to store on every keystroke (debounced ~150ms is fine).
  **Important:** OneEditor is uncontrolled w.r.t. content updates from the store — when chat calls `setBody` in C11, we need to push new content INTO OneEditor. W1 must reveal whether OneEditor supports a `value` prop or a programmatic setter (e.g., `editor.commands.setContent`). If not, C11 adds a `key={bodyVersion}` remount escape hatch.

- [ ] **Chat region:** `<ChatDock surface="skills" />` — no behavioral change in C10. C11 extends `surface-context` to include the draft snapshot so chat can read it; C11 also wires the tool callbacks.

- [ ] **Save flow:** unchanged from SkillEditor — read `meta` + `body` from store, build Skill, emit via `emitSkill`, PUT `/api/skills/[name]/save`. On success, `store.markSaved()` → "Saved" badge for 2s.

- [ ] **isNew rename flow:** identical — derive name from `meta.title.toKebabCase()` on first save → `location.href = /u/{slug}/skills/{derived}/edit`.

- [ ] **Delete:** identical (DELETE save endpoint → navigate).

- [ ] **Compress check:**
  - PRIMITIVE: studio-store + SkillStudio + PropertiesBlock
  - COMPOSE: SkillEditor + extracted Properties? No — SkillEditor's per-field useState is the thing we're replacing. The store is the new primitive, and it's load-bearing for C11/C12.
  - VERDICT: **new** — three new files, deletes one. Net LOC: ~ -50 across the swap.

- [ ] **Doc-plan:**
  - `plans/skills.md` — Components table: drop `SkillEditor` row, add `SkillStudio` + `PropertiesBlock`; "What is built" line: replace "split layout SkillEditor" with "unified SkillStudio with Properties · Body · Chat regions"
  - `plans/evaluate.md` — note that C10's store is the substrate C11/C12 build on (one-line forward reference)

- [ ] Diff specs for W3.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/skill/studio-store.ts` — new (≤80 LOC)
- [ ] `one.ie/web/src/components/skills/PropertiesBlock.tsx` — new (≤180 LOC)
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` — new (≤220 LOC: header bar + region layout + save/delete handlers; Properties + Body + Chat region mounts)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/pages/u/[slug]/skills/[name]/edit.astro` — swap `SkillEditor` import for `SkillStudio` (one-line change)
- [ ] `one.ie/web/src/pages/u/[slug]/skills/new.astro` — same
- [ ] `git rm one.ie/web/src/components/skills/SkillEditor.tsx`

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `SkillEditor` returns 0 hits across `one.ie/web/src/` (file deleted, no stale imports)
- [ ] Grep: `SkillStudio` imported in both `edit.astro` and `new.astro`
- [ ] Grep: `studio-store` imported by `SkillStudio.tsx` and `PropertiesBlock.tsx`
- [ ] Grep: no Unicode glyphs (☀ ☾ ▾ ✓ ✗) in `PropertiesBlock.tsx` — lucide via `<Icon>` only (`.claude/rules/design.md`)
- [ ] Grep: `useSyncExternalStore` used in store hook (the cheap subscribe primitive)
- [ ] `wc -l studio-store.ts` ≤ 80 · `PropertiesBlock.tsx` ≤ 180 · `SkillStudio.tsx` ≤ 220
- [ ] Round-trip test (vitest): parse skill with `{ title, custom_field: "x" }` → store → emit → content still contains `custom_field`
- [ ] Rubric ≥ 0.65 · simplicity ≥ 0.85

---

## C11 — Chat co-editing: skill-creator drives the editor via tools  [tier: complex · batch: 8]

**Goal:** Light up the chat region in SkillStudio. The chat — running the `skill-creator` skill — reads the current draft, can propose changes, and writes them back into the store via tool calls. The human sees those edits land in the editor in real time. The human can keep typing; their writes win on the same field within a small debounce window.

**Exit:**
1. Chat receives current draft as system context on every turn (auto-refreshed when `dirty` changes).
2. Four chat tools are callable and target the **draft store**, NOT R2:
   - `skill.draft.read()` → returns current `{ meta, body }` snapshot
   - `skill.draft.set_frontmatter({ key, value })` → patches `meta`
   - `skill.draft.set_body({ body })` → replaces body
   - `skill.draft.append_body({ text })` → appends to body (used for incremental writes)
3. `skill-creator` is auto-loaded into the chat system prompt for `surface=skills` when a `skillDraft` is present.
4. Tool calls render inline in the chat ("✏️ Updated **title** → Refund handler") so the human can see what changed.
5. Save still goes through the human-clicked Save button. Chat never persists.

### W1 — Recon

1. **Chat backend recon**
   - [ ] `one.ie/web/src/pages/api/chat.ts` — full path of how `surface` becomes `tools`; the `actionToAITool` import (line 35); `requestSurface` block (lines 887+); `ownerAgentToolsAllowlist` interaction; **critical:** how a per-surface tool can be added that lives in the same process the editor runs in (i.e., a tool whose handler is the chat *response stream*, not a server action) — search for `client-side tool` / `clientTool` / `useChat` tool handling
   - [ ] `one.ie/web/src/lib/actions-to-tools.ts` — does it support tools that DON'T hit the server? If not, the four `skill.draft.*` tools must be **client-side tools** registered via `useChat`'s tool handler, not via Astro actions
   - [ ] `one.ie/web/src/components/chat/ChatDock.tsx` line 39 — the `useChat` transport config. Does it accept an `onToolCall` or `experimental_clientTools` prop? Per AI SDK v6, `useChat` supports `automaticallyCallToolsThatShouldBeCalledByTheClient` patterns — confirm
   - [ ] `one.ie/agents/skill-creator/SKILL.md` — does it currently expect any specific tool names? May need a small frontmatter update to advertise the four draft tools

2. **Skill-creator auto-load recon**
   - [ ] `one.ie/web/src/lib/skill/auto-import.ts` — confirms skill-creator is written to R2 on workspace init. NOT the same as loading it into a chat system prompt — that's done elsewhere
   - [ ] `one.ie/web/src/pages/api/chat.ts` — find where skills are stitched into the system prompt for `surface=skills`. If absent, C11 wires it: when `surface === 'skills'` AND request body includes a `skillDraft`, prepend `skill-creator`'s body to the system message

3. **Surface-context extension recon**
   - [ ] `one.ie/web/src/lib/surface-context.ts` — current `SurfaceContext` shape (line 31); how to add an optional `skillDraft?: SkillDraftSnapshot` field
   - [ ] Where ChatDock posts to `/api/chat` (line 39); ensure the `skillDraft` is appended to the body so the server has it

### W2 — Decide  [Opus]

- [ ] **Tool execution model — client vs server:**
  - `skill.draft.read` → **server-known, payload echoes client snapshot**. The server tool returns the snapshot the client passed in the request body (`skillDraft`). No mutation. Lets the model "look at" the current state in a deterministic way.
  - `skill.draft.set_frontmatter / set_body / append_body` → **client-side tools**. The AI SDK v6 `useChat` tool handler intercepts these calls, dispatches to `studioStore`, and returns a confirmation that flows back to the model. The server treats them as "client tools": defined in the `tools` object on the server (for type/schema), but the server's handler is a passthrough returning `{ ok: true, applied: { key, value } }` — the real effect happens client-side in `ChatDock`'s tool dispatcher.

- [ ] **Where the tools are defined (single source of truth):** `one.ie/web/src/lib/skill/draft-tools.ts` — exports a Zod-validated tool spec list:
  ```ts
  export const draftTools = {
    'skill.draft.read': {
      description: 'Read the current draft (frontmatter + body) the human is editing.',
      parameters: z.object({}),
    },
    'skill.draft.set_frontmatter': {
      description: 'Set a frontmatter property on the current draft. Examples of keys: title, description, price, tags, version, ref.',
      parameters: z.object({ key: z.string(), value: z.unknown() }),
    },
    'skill.draft.set_body': {
      description: 'Replace the body of the current draft with new markdown.',
      parameters: z.object({ body: z.string() }),
    },
    'skill.draft.append_body': {
      description: 'Append markdown to the end of the current draft body.',
      parameters: z.object({ text: z.string() }),
    },
  } as const
  ```
  Imported on both sides — server (in `chat.ts` to add to `tools`) and client (in `ChatDock` to register handlers).

- [ ] **Server `chat.ts` patch:**
  - When `body.surface === 'skills' && body.skillDraft`: merge `draftTools` into the `tools` object passed to `streamText`.
  - When same condition: prepend `skill-creator`'s SKILL.md body to the system prompt (load from R2 at `${slug}/skills/skill-creator/SKILL.md`; cached in KV for 5min).
  - Add an inline section to the system prompt: `Current draft: ${json(skillDraft)}` so the model has the state without needing to call `read()` every turn.

- [ ] **Client `ChatDock` patch:**
  - Add `skillDraft?: SkillDraftSnapshot` prop. When `surface === 'skills'`, derive snapshot from `studioStore.snapshot()` and pass it in the `useChat` body
  - On `dirty` change (subscribe to store), include the snapshot in subsequent `/api/chat` POSTs — `useChat`'s `body` is a function in v6, refresh on demand
  - Register client-side handlers for `skill.draft.set_*` tools: dispatch to `studioStore`, return `{ ok: true }`. AI SDK v6 supports this via `useChat({ async onToolCall({ toolCall }) { ... } })` — exact API confirmed in W1

- [ ] **Tool result UI:** inline pill in the chat thread for each tool call:
  ```
  ✏️ Updated  title  → "Refund handler"
  📝 Set body — 1,240 chars
  ➕ Appended 320 chars to body
  ```
  Implementation: `MessageRenderer` already handles tool parts (`MessageList.tsx:297` renders `EvalCard` from a tool result — same pattern). Add a `SkillPatchCard` for the three draft tools.

- [ ] **Conflict resolution (human vs chat racing on the same field):**
  - **Last-write-wins** at the field granularity. Both writers go through `studioStore.setMeta` / `setBody`, which is a synchronous JS dispatch — no race
  - For body specifically: if the human's cursor is in the editor when chat calls `set_body`, the editor's content gets reset and the cursor jumps. **Mitigation:** if `studio-store.dirty.body === 'human-recent'` (last human keystroke within 2s), reject `set_body` and route the model to use `append_body` instead. Detect via a "lastHumanEditAt" timestamp on the store
  - For frontmatter: human typing in a Properties input doesn't conflict with chat patching a different key. Same key: last write wins; chat's pill UI makes it visible

- [ ] **`skill-creator` auto-load gate:** only loads when `surface=skills` AND `body.skillDraft` is present (i.e., we're in the studio, not on the catalog page). Avoids polluting other `surface=skills` flows. If skill-creator isn't installed in R2 (workspace edge case), fall back to a hardcoded inline instruction: "You help the human edit the skill in `Current draft`. Use the draft.* tools to propose changes."

- [ ] **Streaming:** the model can call `append_body` with small chunks if it wants the user to see the body grow as it writes. Each append fires a store update → editor remounts? **No — the editor must apply appends without losing cursor/selection.** W1's OneEditor check determines this: if OneEditor supports `editor.commands.insertContentAt('end', text)`, expose it; else `key={bodyVersion}` remount on rare full-body writes only and treat `append_body` as a special path through OneEditor

- [ ] **Compress check:**
  - PRIMITIVE: draft-tools registry, server merge, client tool handlers, system-prompt loader
  - COMPOSE: could we just use the existing surface-tools mechanism? No — surface tools are server-action backed; client-state tools are a new pattern
  - VERDICT: **new** — but small; one new tools file, ~3 edits to chat.ts, ~2 edits to ChatDock. Doc requirement enforced

- [ ] **Doc-plan:**
  - `plans/skills.md` — "Skill creation workflows" section: rewrite to lead with "Chat + Editor in the Studio (primary path)"; demote the chat-only and editor-only sub-flows to fallbacks
  - `plans/evaluate.md` — note the model can also call `skill.eval` (existing action) from the studio to close the write → test → refine loop
  - `one.ie/agents/skill-creator/SKILL.md` — append a Tools section documenting the four draft tools the model has when in the studio

- [ ] Diff specs for W3.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/skill/draft-tools.ts` — new (≤60 LOC)
- [ ] `one.ie/web/src/components/skills/SkillPatchCard.tsx` — new (≤80 LOC; renders the inline pill)
- [ ] `one.ie/web/src/lib/surface-context.ts` — extend `SurfaceContext` with `skillDraft?: SkillDraftSnapshot`
- [ ] `one.ie/agents/skill-creator/SKILL.md` — append Tools section

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/pages/api/chat.ts` — load skill-creator + merge draftTools when surface=skills and skillDraft present
- [ ] `one.ie/web/src/components/chat/ChatDock.tsx` — accept skillDraft via prop or context; pass in `/api/chat` body; register `onToolCall` handlers for the three client-side tools
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` — pass `skillDraft={studioStore.snapshot()}` to ChatDock; subscribe to store so it re-passes on changes
- [ ] `one.ie/web/src/components/chat/MessageList.tsx` — render `SkillPatchCard` for `tool-skill.draft.*` parts (mirrors the existing `EvalCard` pattern at line 297)

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `draftTools` (or `'skill.draft.read'`) imported in both `chat.ts` AND `ChatDock.tsx`
- [ ] Grep: `studioStore.setMeta` / `setBody` / `appendBody` called from `ChatDock.tsx`'s tool handlers
- [ ] Grep: `skill-creator/SKILL.md` loaded in `chat.ts` when surface=skills (file read or KV fetch present)
- [ ] Grep: `SkillPatchCard` rendered in `MessageList.tsx` for `tool-skill.draft.*` parts
- [ ] Grep: `lastHumanEditAt` (or equivalent timestamp) used in store to guard `set_body` during active typing
- [ ] Manual smoke: open `/u/{demo-slug}/skills/new`, ask in chat "make a skill that summarizes emails" — verify title + description + body appear in the editor without reload
- [ ] `wc -l draft-tools.ts` ≤ 60 · `SkillPatchCard.tsx` ≤ 80 · chat.ts delta ≤ +40 · ChatDock.tsx delta ≤ +60
- [ ] Rubric ≥ 0.65 · security ≥ 0.85 (tool calls must validate Zod schema; no body injection from model)

---

## C12 — Tests tab: evals.json editor inside Studio (absorbs old C7)  [tier: complex · batch: 8]

**Goal:** Add a **Tests** tab to SkillStudio that reads / writes `<slug>/skills/<name>/evals/evals.json`. Both human and chat can edit it — chat gets a fifth tool `skill.draft.suggest_test_case({ tc })` that proposes a new test row the human can accept. After accepting, "Run eval" (from C5 or directly in the panel) closes the loop.

**Exit:**
- New tab in SkillStudio: `[ Properties · Body · Tests ]`
- Tests tab lists `TestCase[]` from R2; add/edit/delete rows
- New endpoint `PUT /api/skills/[name]/evals` (session-authed, slug-bound — mirrors C1)
- New chat tool `skill.draft.suggest_test_case` writes to the Tests panel (with a pending state — human accepts/rejects)
- Save persists; C5's eval panel re-reads automatically

### W1 — Recon

- [ ] `one.ie/web/src/lib/eval/runner.ts` — `TestCase` type (prompt, expected, assertions[])
- [ ] `one.ie/web/src/pages/api/eval.ts` line 36+ — confirms R2 key shape
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — C1's auth pattern (mirror exactly)
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` (after C10) — Tabs container shape
- [ ] `one.ie/web/src/lib/skill/draft-tools.ts` (after C11) — extension point for the fifth tool
- [ ] `one.ie/web/src/components/chat/MessageList.tsx` — `SkillPatchCard` pattern from C11 — extend for `suggest_test_case` rendering

### W2 — Decide  [Sonnet]

- [ ] **New endpoint `pages/api/skills/[name]/evals.ts`:**
  - `GET` → returns `TestCase[]` from R2; 404 if file absent (empty array is fine)
  - `PUT { cases: TestCase[], slug }` → `requireAuth('update_group')` → verify `slug === principal.slug` → write to R2
  - ≤60 LOC

- [ ] **Tests panel UI (`TestCasePanel.tsx`):**
  - Loads `GET /api/skills/{name}/evals` on mount
  - Row layout:
    ```
    ┌────────────────────────────────────────────────────┐
    │ Prompt       │ Need $450 refund...                 │
    │ Expected     │ Escalates — no auto-approve         │
    │ Assertions   │ • Refund > $100 amount              │
    │              │ • Asks for manager approval         │
    │              │ [+ Add assertion]                   │
    │ [ Delete ]                                         │
    └────────────────────────────────────────────────────┘
    ```
  - Local state: `TestCase[]` + a `pending: TestCase[]` array for chat-suggested cases (rendered with a yellow border and `[Accept] [Reject]` buttons)
  - Save button at top: PUT the array to the endpoint; "Saved" badge on success

- [ ] **Tab shape in SkillStudio:**
  ```
  [ Properties ] [ Body ] [ Tests (N) ]
  ```
  Count is `cases.length`; renders `N` only when > 0. Tests tab lazy-mounts on first click (avoid R2 fetch when not needed).

- [ ] **Fifth chat tool — `skill.draft.suggest_test_case`:**
  - Parameters: `{ tc: { prompt, expected, assertions: string[] } }`
  - Client handler: appends to `pending` array in TestCasePanel's local state via a new bus (e.g., `studioStore.suggestTestCase(tc)` — extend the store)
  - Chat UI: `SkillPatchCard` variant — "📋 Suggested test: `${prompt.slice(0,50)}...` → Accept in Tests tab"

- [ ] **Run eval shortcut in Tests panel:** a `[ Run eval ]` button at the bottom that POSTs to `/api/eval` (existing endpoint). On completion, link to `/u/{slug}/skills/{name}#eval` for the C5 panel results. Don't render the benchmark in-place — that's C5's job; we don't duplicate

- [ ] **Compress check:**
  - PRIMITIVE: TestCasePanel, evals endpoint, fifth tool, store extension for pending
  - COMPOSE: pending could be a Properties-block-like surface? No — too different (rows, not key-value)
  - VERDICT: **new** — all four

- [ ] **Doc-plan:**
  - `plans/evaluate.md` — add "Authoring tests" section: humans use the Tests tab; chat suggests via `suggest_test_case`; both write to `evals.json`
  - `plans/skills.md` — API endpoints table: add `PUT /api/skills/[name]/evals`; Components table: add `TestCasePanel`; "What is built": Tests tab in Studio

- [ ] Diff specs for W3

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/pages/api/skills/[name]/evals.ts` — new (≤60 LOC, GET + PUT)
- [ ] `one.ie/web/src/components/skills/TestCasePanel.tsx` — new (≤200 LOC)
- [ ] `one.ie/web/src/lib/skill/draft-tools.ts` — append `skill.draft.suggest_test_case` (delta ≤ 15 LOC)
- [ ] `one.ie/web/src/lib/skill/studio-store.ts` — extend with `suggestTestCase(tc)` + `pending` selector (delta ≤ 20 LOC)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` — add Tabs container with Properties · Body · Tests; mount `<TestCasePanel>` lazily on Tests selection
- [ ] `one.ie/web/src/components/chat/ChatDock.tsx` — register handler for `skill.draft.suggest_test_case` → dispatches to store
- [ ] `one.ie/web/src/components/chat/MessageList.tsx` — `SkillPatchCard` extended to render the suggestion variant

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `requireAuth` + `principal.slug` check present in `evals.ts`
- [ ] Grep: `TestCasePanel` imported in `SkillStudio.tsx`
- [ ] Grep: `suggest_test_case` tool present in `draft-tools.ts` AND handled in `ChatDock.tsx`
- [ ] Grep: Tab labels `Properties`, `Body`, `Tests` present in `SkillStudio.tsx`
- [ ] `wc -l evals.ts` ≤ 60 · `TestCasePanel.tsx` ≤ 200 · `SkillStudio.tsx` net delta ≤ +60
- [ ] Manual smoke: open studio, ask chat "suggest a test case for the unhappy path" — verify pending row appears in Tests tab; Accept → row joins the saved list; Save → R2 has the new case
- [ ] Rubric ≥ 0.65 · security ≥ 0.90

---

## C13 — Live edit channel: external writers → browser studio  [tier: complex · batch: 9]

**The vision (user's framing):**
> "Claude Code is editing the skill and it's appearing in the editor and a user is seeing it update."

After C11, *browser chat* can edit the draft via tool calls. C13 extends the same surface to **external writers**: Claude Code in the terminal, `oneie skill edit` CLI, MCP server, or a GitHub PR webhook. Any process that can call `PUT /api/skills/[name]/save` will trigger a broadcast on a per-skill channel; every open `SkillStudio` instance for that skill listens and applies the patch to its store. The human sees the body grow as Claude Code writes it.

**Architectural fit:** `api.one.ie` already runs the `WsHub` Durable Object (per `one-ie/CLAUDE.md`). One DO per skill (or per `<slug>:<name>` channel). Browser uses a thin SSE fallback if WebSocket can't connect (CF Workers SSE is well-supported).

**Exit:**
1. `PUT /api/skills/[name]/save` (existing endpoint from C1) broadcasts a `skill-update` event to `WsHub` channel `<slug>:<name>` after the R2 write.
2. `SkillStudio` opens an SSE/WebSocket subscription to `<slug>:<name>` on mount; on `skill-update`, it diffs the incoming `meta` + `body` against its current store state and applies non-conflicting fields. Conflict fields (where the human has `lastHumanEditAt < 2s`) are queued behind an "Apply remote changes" banner.
3. **Receiver list shown in the studio header** (when ≥1 other writer is active): "👤 You · 🤖 Claude Code (CLI) · 🤖 Browser chat" — presence signal via the same channel.
4. CLI / MCP / Claude Code reach this for free — they already write through `PUT /save`. No client changes required outside the broadcast.

### W1 — Recon

1. **WsHub DO recon**
   - [ ] `api/` package — find `WsHub` DO source; current channel/topic model; how a publisher sends to a topic; how a subscriber lists active peers
   - [ ] `api/wrangler.toml` (or equivalent) — DO binding name; whether `one.ie/web/`'s Worker has access to `WsHub` already or needs a binding added
   - [ ] Existing publishers: `grep -r "WsHub\|wshub\|ws-hub" one-ie` — see whether any current code already uses the DO (avoid reinventing the publish helper)

2. **Save endpoint recon**
   - [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` (from C1) — current shape; where to insert the broadcast call (after R2 write, before response)
   - [ ] Confirm the endpoint already has the body content needed to broadcast (`meta` + `body`) — if it stores raw markdown and the broadcast needs structured form, parse via `parser.ts` on the way through

3. **Browser client recon**
   - [ ] `one.ie/web/src/lib/` — any existing SSE or WebSocket client? Search `EventSource`, `new WebSocket`, `useWebSocket` to avoid duplicating
   - [ ] CF Workers SSE pattern docs — SSE via `ReadableStream` is the standard CF pattern; WebSocket via DO is also supported
   - [ ] `SkillStudio.tsx` (from C10) — where to mount the subscription effect; how to integrate with the store's existing `setMeta` / `setBody`

### W2 — Decide  [Opus]

- [ ] **Transport choice — pick one:**
  - **SSE** (server-sent events) — one-way (server → browser). Simpler. Channel auth via signed token in URL. Backpressure handled by HTTP/2.
  - **WebSocket via WsHub DO** — bidirectional. Needed if the browser also publishes presence pings.
  - **Lock: SSE** for the data channel; **presence is derived from the broadcaster's own writes** (no separate ping needed — every save announces "I'm here"). If presence-only signal becomes a feature, upgrade to WS in a later cycle. SSE today; WS escape valve later.

- [ ] **Channel naming:** `skill:<slug>:<name>` — matches the substrate verb-receiver pattern (`.claude/rules/ui.md`)

- [ ] **Event shape:**
  ```ts
  interface SkillUpdateEvent {
    type: 'skill-update'
    slug: string
    name: string
    actor: { kind: 'human' | 'browser-chat' | 'cli' | 'mcp' | 'claude-code' | 'webhook', id?: string }
    meta: Record<string, unknown>          // full frontmatter
    body: string                            // full body (small skills — < 5000 tokens)
    revision: number                        // monotonic per channel
    timestamp: number
  }
  ```
  Why full state, not patches? Skills are small. Full-state replication is dead simple and the channel is per-skill, so volume is bounded. Patches add complexity for negligible savings.

- [ ] **Server publisher: new helper `lib/skill/broadcast.ts`** (≤40 LOC):
  ```ts
  export async function broadcastSkillUpdate(
    env: { WSHUB: DurableObjectNamespace },
    event: SkillUpdateEvent,
  ): Promise<void> { /* fetch the DO stub for `skill:${event.slug}:${event.name}`, POST the event */ }
  ```
  Called from `save.ts` after the R2 write succeeds. Best-effort: broadcast failure does NOT fail the save (logged + continued).

- [ ] **Actor inference at the save endpoint:**
  | Auth | Actor |
  |---|---|
  | Bearer secret (CLI / agent) + `X-Actor: claude-code` header | `claude-code` |
  | Bearer secret w/o header | `cli` |
  | Session cookie + body comes from a chat tool (header `X-Actor: browser-chat`) | `browser-chat` |
  | Session cookie, no actor header | `human` |
  | GitHub/external webhook signature | `webhook` |
  Allowlist of actor strings; reject unknown values silently (defaults to `cli`). C13's W3 has the CLI add the header; existing browser save calls add `X-Actor: human`.

- [ ] **Browser subscriber `lib/skill/live-channel.ts`** (≤80 LOC):
  ```ts
  export function subscribeSkillChannel(
    slug: string, name: string,
    onEvent: (ev: SkillUpdateEvent) => void,
  ): () => void { /* EventSource('/api/skills/${name}/channel?slug=${slug}') → onEvent on each message; returns unsubscribe */ }
  ```
  New endpoint `GET /api/skills/[name]/channel` (≤50 LOC) — `requireAuth` → opens an SSE stream backed by `WsHub` DO subscribe (DO is the source; the HTTP endpoint is the SSE adapter so the browser doesn't need DO bindings).

- [ ] **Conflict policy on remote `set_body`:**
  - If `studioStore.lastHumanEditAt > now - 2000` (human typing within 2s): **queue** the incoming event in `studioStore.pendingRemote` → show banner "Claude Code made changes — [Review] [Apply] [Discard]"
  - Else (human idle): apply directly. Track in `lastRemoteApplyAt` for the chat conflict check (chat in C11 already checks `lastHumanEditAt`; symmetrical here)
  - Frontmatter writes never block — granular per-field; apply non-touched fields, queue touched ones

- [ ] **Echo suppression:** the broadcaster's own client receives its own event. Suppress by attaching the request `revision` to the local save; ignore inbound events whose `revision` <= local last-applied.

- [ ] **Presence ribbon** in studio header: list of actors who've written to the channel in the last 60s. Source: each event carries `actor`; client maintains a Map<actor, lastSeen>. Render with a 🤖 / 👤 icon per kind.

- [ ] **Compress check:**
  - PRIMITIVE: WsHub broadcast helper, channel SSE endpoint, browser subscriber, conflict queue UI
  - COMPOSE: could we re-use the `/api/signal` route family? `/api/signal/skill:update` could fire-and-forget — but for real-time we need durable subscriptions, which the substrate doesn't natively give us. Pheromone fade isn't the right semantics.
  - VERDICT: **new** — but small. ~3 new files + 1 new endpoint + 1 edit to save.ts

- [ ] **Doc-plan (CRITICAL — substantial doc work):**
  - `plans/skills.md` — add a new **"Real-time sync"** section explaining the channel model, the actor list, and the conflict policy
  - `plans/skills.md` — add a new **"External editing"** section listing the four supported external writers (CLI, Claude Code, MCP, webhook) and how each authenticates
  - `plans/skills.md` — API endpoints table: add `GET /api/skills/[name]/channel`
  - `plans/skills.md` — Skill lib table: add `broadcast.ts` and `live-channel.ts`
  - `packages/cli/` — README or skill verbs doc: note the `X-Actor: claude-code` header convention if invoked from Claude Code

- [ ] Diff specs for W3

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/skill/broadcast.ts` — new (≤40 LOC)
- [ ] `one.ie/web/src/lib/skill/live-channel.ts` — new (≤80 LOC)
- [ ] `one.ie/web/src/pages/api/skills/[name]/channel.ts` — new SSE endpoint (≤50 LOC)
- [ ] `api/src/...` (WsHub DO) — add a subscribe method if not present (W1 dictates; may be no-op if DO already supports pub/sub)

**W3b — sequenced (after W3a):**
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — call `broadcastSkillUpdate` after R2 write; infer actor from headers
- [ ] `one.ie/web/src/lib/skill/studio-store.ts` (from C10) — add `pendingRemote` slice + `applyRemote(ev)` + `dismissRemote()` actions; track `lastRemoteApplyAt`
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` — `useEffect` to `subscribeSkillChannel` on mount, route to `studioStore`; presence ribbon in header; banner when `pendingRemote.length > 0`

### W4 — Verify

- [ ] `bun run verify` green · `delta_tsc_errors ≤ 0`
- [ ] Grep: `broadcastSkillUpdate` called in `save.ts`
- [ ] Grep: `subscribeSkillChannel` called in `SkillStudio.tsx`
- [ ] Grep: `pendingRemote` + `applyRemote` present in `studio-store.ts`
- [ ] Grep: `'X-Actor'` referenced in `save.ts` (header inference) AND `cli/` package source (header emission)
- [ ] Grep: `revision` field present in event type, used for echo suppression in browser
- [ ] Manual smoke: two browsers open the same skill `/edit`; edit in one; verify the other updates within 1s without reload. Then run `oneie skill edit <name>` from terminal; verify browser updates and presence ribbon shows "CLI" actor
- [ ] `wc -l broadcast.ts` ≤ 40 · `live-channel.ts` ≤ 80 · `channel.ts` ≤ 50
- [ ] Rubric ≥ 0.65 · stability ≥ 0.85 (broadcast failures must not break save; channel disconnects must not lose data — full state replication tolerates drops)

---

## C14 — KV catalog cache busted on save  [tier: trivial · batch: 10]

**Gap:** `GET /api/skills` is KV-cached for 5 minutes. Workspace skills authored or edited in the Studio don't appear in the catalog until the cache TTL expires. Users edit, switch back to the dashboard, see yesterday's data. Trust killer.

**Exit:** Every successful `PUT /api/skills/[name]/save` (and DELETE, and `skill.fork`, and `skill.import`) calls `kv.delete('skills:catalog:<slug>')` before returning. Catalog reflects the change on the next page load.

### W1 — Recon
- [ ] `one.ie/web/src/pages/api/skills/index.ts` — current KV cache key + TTL
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — where to insert the bust
- [ ] `one.ie/web/src/actions/skills.ts` — `skill.fork`, `skill.import`, `skill.delete` — same bust call needed
- [ ] `one.ie/web/src/pages/api/skills/workspace.ts` — does the workspace listing have its own cache? If so, also bust

### W2 — Decide  [inline / Sonnet]
- [ ] New helper `lib/skill/cache.ts` exporting `bustCatalogCache(env, slug)` — single point of truth
- [ ] All five write paths (save PUT, save DELETE, fork action, import action, delete action) call it before returning
- [ ] No-op if KV binding missing (defensive)

### W3 — Edit  [Sonnet]
- [ ] `one.ie/web/src/lib/skill/cache.ts` — new (≤25 LOC)
- [ ] `one.ie/web/src/pages/api/skills/[name]/save.ts` — call after R2 write (PUT + DELETE branches)
- [ ] `one.ie/web/src/actions/skills.ts` — call in `skill.fork`, `skill.import`, `skill.delete`

### W4 — Verify
- [ ] `bun run verify` green
- [ ] Grep: `bustCatalogCache` referenced in exactly 5 call sites (verify count)
- [ ] Manual smoke: save a skill, hard-reload the catalog, confirm new skill is present (no 5min wait)
- [ ] `wc -l cache.ts` ≤ 25
- [ ] Rubric ≥ 0.65

---

## C15 — Parser diagnostics surfaced in Studio  [tier: simple · batch: 10]

**Gap:** `lib/skill/parser.ts` returns `diagnostics[]` on every parse — invalid YAML, unknown keys with typos (e.g., `descripton:`), bad value types. The studio never reads them. A user saves a broken skill and only finds out when chat or `/api/eval` fails opaquely.

**Exit:** Parse diagnostics render as inline warnings under the relevant PropertiesBlock row (or as a banner above the body if the body has YAML decode issues). Save is allowed (soft-fail), but Save button label changes to "Save with warnings (N)" when `diagnostics.length > 0`.

### W1 — Recon
- [ ] `one.ie/web/src/lib/skill/parser.ts` — `Diagnostic` type: severity, message, key/path
- [ ] `one.ie/web/src/components/skills/PropertiesBlock.tsx` (from C10) — hook point for per-field warnings
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` (from C10) — Save button label

### W2 — Decide  [Sonnet]
- [ ] Studio store from C10 gains `diagnostics: Diagnostic[]` populated on `init` + every time `setMeta` fires (re-parse via `emitSkill` + `parse` round-trip — cheap)
- [ ] PropertiesBlock row gets a `warning?: string` prop; renders a yellow icon + tooltip when present
- [ ] Top-level banner for body-level diagnostics (rare): yellow strip above OneEditor
- [ ] Save button: `Save` when 0; `Save with warnings (N)` when N > 0; never blocks
- [ ] LOC budget: studio-store +20 · PropertiesBlock +15 · SkillStudio +10

### W3 — Edit  [Sonnet]
- [ ] `one.ie/web/src/lib/skill/studio-store.ts` — diagnostics slice + setter
- [ ] `one.ie/web/src/components/skills/PropertiesBlock.tsx` — wire warning prop per row
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` — banner + save label

### W4 — Verify
- [ ] `bun run verify` green
- [ ] Grep: `diagnostics` referenced in store, PropertiesBlock, and SkillStudio
- [ ] Manual smoke: open a skill, edit Properties to set `price: not-a-number`; verify yellow warning + Save label updates to "Save with warnings (1)"
- [ ] Rubric ≥ 0.65

---

## C16 — Eval the draft (unsaved state) from Studio  [tier: complex · batch: 10]

**Gap:** `/api/eval` reads the skill body from R2. To test changes, the user must save first. This forces premature commits — you can't iterate without polluting the saved version. After C10–C12, both human and chat are editing a draft; both need to test before commit.

**Exit:** `POST /api/eval` accepts an optional `draftContent: string` field. When present, the server uses it directly instead of fetching from R2. The Studio adds a "Run eval on draft" button that sends `studioStore.body` + a serialized frontmatter without saving. Results land in the same iteration scratch path (`iteration-{N+draft}` — distinct so saved iterations aren't polluted).

### W1 — Recon
- [ ] `one.ie/web/src/pages/api/eval.ts` — current shape; how `skillBody` is fetched (line 36 area per evaluate.md); how the iteration path is computed
- [ ] `one.ie/web/src/lib/eval/aggregate.ts` — the iteration counter; whether `iteration-N-draft` would round-trip through `loadHistory` (it should — `masteryFromHistory` accepts any iteration with a benchmark.json)
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` (from C10) + Tests panel (from C12) — where the button lives (Tests tab footer is natural)

### W2 — Decide  [Sonnet]
- [ ] **Endpoint contract:**
  ```ts
  POST /api/eval
  body: {
    slug, skillPath,
    iteration: number,
    draftContent?: string,           // NEW — bypasses R2 read when present
    draftEvals?: TestCase[],         // NEW — also overrides evals.json for unsaved test cases
  }
  ```
- [ ] **Draft iteration naming:** the existing pattern is `iteration-1`, `iteration-2`. Drafts go to `iteration-1.draft.{shortHash}` (8-char hash of `draftContent + draftEvals` so reruns of the same draft overwrite, but a changed draft creates a new path). Avoids polluting the canonical iteration stream
- [ ] **Mastery curve handling:** by default, `loadHistory` includes draft iterations; for the detail page (C5) we want only saved iterations. Add a `{ includeDraft?: boolean }` filter to `loadHistory` and pass `false` from the detail page; `true` from the Studio Tests panel (so users see drafts they ran today)
- [ ] **Button placement:** Tests tab footer: `[ Save tests ] [ Run eval on draft ]` — primary on the right (eval) since it's the user's actual goal
- [ ] **Cost guard:** drafts are explicit user action; no debounce/throttle beyond the existing eval cost (which is real — Groq + judge). Show estimated cost in a tooltip ("≈ $0.02 per run") if `price` info is available
- [ ] Diff specs for W3

### W3 — Edit  [Sonnet]

**W3a — independent:**
- [ ] `one.ie/web/src/pages/api/eval.ts` — accept `draftContent` / `draftEvals`; branch the load logic
- [ ] `one.ie/web/src/lib/eval/load-history.ts` (from C5) — add `includeDraft` filter
- [ ] `one.ie/web/src/components/skills/TestCasePanel.tsx` (from C12) — add the button + handler

**W3b — sequenced:**
- [ ] `one.ie/web/src/components/skills/SkillStudio.tsx` — bubble result to Tests tab (no panel-to-studio call needed if Tests panel handles it inline)
- [ ] `one.ie/web/src/pages/u/[slug]/skills/[name].astro` (detail page from C5) — pass `includeDraft: false` to `loadHistory`

### W4 — Verify
- [ ] `bun run verify` green
- [ ] Grep: `draftContent` in `api/eval.ts` AND `TestCasePanel.tsx`
- [ ] Grep: `includeDraft` filter present in `load-history.ts`
- [ ] Grep: R2 path `iteration-.*draft` referenced in `eval.ts` (proves the draft branch writes to the segregated path)
- [ ] Manual smoke: edit a skill body, click "Run eval on draft" without saving, verify benchmark renders in Tests tab; reload detail page, verify draft does NOT appear in the saved mastery curve
- [ ] Rubric ≥ 0.65 · stability ≥ 0.85 (draft writes must not break saved iteration discovery)

---

## Audit deferred — to be tracked in `skills-scale-todo.md` (created at plan-close)

Found in the skills.md audit but out of scope for this plan:

| Topic | Why deferred |
|---|---|
| **Version history / rollback** | Skills have a `version` field but no R2 snapshot history. Useful but no user-visible pressure yet |
| **Marketplace publish** | `/marketplace` top-level route exists; skills as listings is a product question, not editor scope |
| **Scripts / references / assets UI** | Data model declares directories but no skill in the catalog uses them today. Add when a real skill needs it |
| **Telemetry: usage count + cost roll-up per row** | Already noted in the original Deferred section. Needs usage tracking primitive first |
| **Legacy `one.ie/web/skills/*.md` migration** | 7 flat files; either migrate to fleet or to workspace. Migration script is one-shot, not a cycle |
| **Multi-workspace skill sharing** | Today a skill belongs to one slug. Cross-workspace requires permissions model work |
| **Inline eval progress UI** | Already in skills-scale deferred list |
| **`agent_skills` ↔ composio ref interaction** | Agent skill binding is documented in `agent-spec.md`; skill page doesn't need to own this |
| **`inputSchema` / `outputSchema` editor** | Data model has them; no skill uses them; deferred until needed |
| **Description optimizer surface** | `runner.ts` includes a description optimizer; today only chat-invoked. Could be a Studio button — defer until C11 measurements show users want it |

---

## See also

- `plans/skills.md` — data model, routes, component map
- `plans/evaluate.md` — mastery curve definition (C2 consumes; SkillRow surfaces)
- `plans/skills-implementation.md` — import system
- `one.ie/agents/skill-creator/SKILL.md` — chat-driven creation (primary path; this plan adds the editor + dashboard)
- `one.ie/web/src/components/editor/Editor.tsx` — OneEditor (C3)
- `one.ie/web/src/lib/skill/emit.ts` — emitSkill (C3)
- `one.ie/web/src/lib/eval/mastery.ts` — `computeMastery` (C2)
- `one.ie/web/src/lib/api-auth.ts` — `requireAuth` (C1)

---

## Deferred — separate plan when installed > ~10 per workspace

Track in `skills-scale-todo.md`:
- Search + filter chips (`All / Mastered / Needs eval / Free / Paid`)
- Sort dropdown — Last used requires usage tracking first
- Usage count + cost roll-up per row + monthly total in header
- Drift indicator (`↻` when `ref:` upstream changed)
- Bulk select (checkbox column + "Wire selected to agent…")
- Group-by-tag toggle
- Inline eval progress UI on the row (today: link to detail page)
- Skill rename + R2 move + D1 cascade

---

## Plan rubric (2026-05-24)

Composite **0.86** — well above the 0.65 close gate.

| Dimension | Score | Evidence |
|---|---:|---|
| **Goal-fit** | 0.95 | Plan outcome — "skills dashboard treats skills as measured capabilities, four surfaces author the same markdown grammar" — fully delivered. All 16 originally-planned cycles either shipped or were superseded with rationale recorded. Markdown-grammar substrate (skill-format.md) + one endpoint + four surfaces (web Studio, CLI, MCP, raw HTTP) live. |
| **Security** | 0.95 | C23 closed the last public mutation surface (`/api/eval`). Both auth paths (Bearer `<slug>:SERVER_SECRET` + session) verify `body.slug === authedSlug` → 403 otherwise. C1's `save.ts` enforces the same slug-binding pattern. No anonymous Groq quota burn possible. |
| **Stability** | 0.90 | `bun run verify` green throughout (708/711 tests passing, 3 pre-existing skips). Zero new tsc errors introduced across 5 trivial cycles. Pre-existing `device-flow.ts` errors in CLI unchanged. |
| **Simplicity** | 0.85 | Power-through-simplicity rewrite cut 7 planned cycles to 4 (C17-C23 simplification, see line 188-215). Deleted orphan code (C18); chose markdown grammar over shared SDK (skill-format.md); two surfaces share a 20-LOC hand-rolled YAML extractor instead of pulling a yaml dep. One known carry-cost: that 20-LOC parser is duplicated in CLI + MCP — acceptable since each is a small fetch wrapper. |
| **Speed** | 0.85 | Build asset import (C20) — methodology baked at build time, zero runtime R2 reads per chat turn. Cycle execution time well under estimates (~30min target each; trivial path averaged ~10-15min). Tokens lean: no spawned agents on TRIVIAL cycles, inline rubric only. |

**Adversarial pass:** No locked-rule violations. The 6 verbs untouched; no new HTTP endpoints created (per `api.md`) — all five cycles modified existing files or added one MCP tool to the established `lifecycle.ts` home. Receiver namespace not expanded.

**Deferred-with-reason items** (recorded, not silenced):
- `/api/eval` `meta.evals` from frontmatter as primary path — blocked on YAML parser extension; sidecar fallback still works
- Live four-surface receipt — script shipped; manual run by owner needed
- 15-item scale backlog in `skills-scale-todo.md` — activated when workspaces cross ~10 installed skills

**Trust level:** standard. Composite ≥ 0.65 gate cleared.
