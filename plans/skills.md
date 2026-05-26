---
lifecycle: active
surfaces: one.ie/web, packages/cli, packages/sdk, packages/mcp
last-updated: 2026-05-24
---

# Skills

A skill is a versioned, priced, eval-gated capability. Skills activate via the `description` field — the model reads it and decides whether to consult the skill body. The full creation + iteration workflow is driven by the `skill-creator` skill, hosted in chat, CLI, or MCP.

---

## End state (the destination)

**Markdown in, numbers out — from any surface, with the same vocabulary, measured by the same judge, stored in the same place.**

```
A user types "I want to build a skill that…" anywhere:

  in the Studio chat        → SkillProposalCard appears → Apply → edit → Save
  in Claude Code (MCP)      → skill.propose tool emits markdown → browser refreshes
  in their terminal (CLI)   → oneie skill init + eval iterates locally
  in raw HTTP / SDK         → POST /api/eval, see numbers

All four paths write the same R2 markdown, get graded by the same engine,
land on the same mastery curve. One skill, four front doors.
```

A skill is "done" when:

1. User types intent → `skill-creator` drives the draft (chat or MCP)
2. Draft has test cases (scaffolded automatically by `oneie skill init`)
3. Eval runs: `pass_rate`, `delta` vs baseline, `tokens`, `time`
4. BKT advances: `novice` → `developing` → `proficient` → `mastered`
5. Mastery gate: `prob ≥ 0.80` sustained across multiple iterations
6. Skill ships — installed on agents, paid for, cited
7. Substrate keeps measuring; bad skills fade via Loop L3, good ones strengthen

**Schema (source of truth):** [`skill-format.md`](skill-format.md) — one page, the substrate every surface reads.
Detailed cycle plan + status: [`skills-todo.md`](skills-todo.md).
Detailed eval lifecycle: [`evaluate.md`](evaluate.md).

---

## Architecture — one contract, four surfaces

```
                ┌──────────────────────────────────┐
                │  skill-creator (SKILL.md)        │
                │  the methodology, not code       │
                └──────────────────────────────────┘
                              │
                runs inside any of these surfaces:
        ┌───────────────┬───────────────┬──────────────┐
        ▼               ▼               ▼              ▼
   Studio chat     Claude Code      Terminal       Anything
   (web)           via MCP          `oneie`        with HTTP
        │               │               │              │
        └────────┬──────┴───────┬───────┴──────┬───────┘
                 ▼              ▼              ▼
          ┌────────────────────────────────────────┐
          │  @oneie/sdk  — the only client         │
          │    parse · emit · validate             │
          │    create · import · publish · fork    │
          │    eval · history · mastery            │
          └────────────────────────────────────────┘
                              │
                              ▼
                ┌──────────────────────────────────┐
                │  web /api/{skills,eval}/*        │
                │  R2 · D1 · KV · benchmark.json   │
                └──────────────────────────────────┘
```

**Current truth:** the SDK side of this picture is anemic (`skillsImport()` is the only verb). The web Studio, CLI, and chat each re-implement their slice and silently drift. See **Open gaps** below.

---

## Data model

### SKILL.md — the canonical shape

```yaml
---
agentmd: "0.1"           # optional — marks fleet format
name: brand-voice-check  # slug, lowercase + hyphens, matches directory name
title: Brand Voice Check # human-readable display name
version: 1.0.0           # semver
summary: One line (≤200 chars) describing what the skill does
description: |           # routing trigger (≤1024 chars) — what & when to use
  Use this skill when...
price: 0.03              # USD per call; 0 = free
license: Apache-2.0
tags: [marketing, copy, qa]
trigger: semantic        # optional; "semantic" | "explicit"
compatibility: |         # tools / runtime requirements (non-default only)
  Requires...
inputSchema:  {}         # optional JSON schema for structured input
outputSchema: {}         # optional JSON schema for structured output
scripts:  []             # script files bundled in scripts/
references: []           # reference docs in references/
assets: []               # static assets in assets/
evals: []                # inline eval list (small skills only)
ref:                     # optional source URL for `Refresh`
---

# Body

Instructions. Plain markdown. Imperative voice. Explain why, not just what.
Keep under 500 lines / ~5000 tokens.
```

### Directory layout

```
skill-name/
├── SKILL.md              required
├── evals/
│   └── evals.json        test case definitions (required for eval)
├── scripts/              deterministic code bundled with the skill
├── references/           docs loaded on demand; one per domain variant
└── assets/               templates, icons, fonts
```

### Progressive disclosure

| Tier | Content | Always loaded |
|------|---------|---------------|
| 1 | `name` + `description` | Yes — ~100 tokens per skill |
| 2 | Full `SKILL.md` body | On activation |
| 3 | `references/`, `scripts/`, `assets/` | Only when body references them |

---

## Three skill layers

| Layer | Location | Purpose |
|-------|----------|---------|
| **Fleet catalog** | `one.ie/agents/skills/*/SKILL.md` | 48 bundled skills glob'd at build time via `import.meta.glob` |
| **Legacy web skills** | `one.ie/web/skills/*.md` | 7 flat files (brand-voice-check, draft-email, etc.) — pending migration |
| **Workspace skills** | R2: `<slug>/skills/<name>/SKILL.md` | User-installed or user-authored skills |

Fleet + legacy served by `GET /api/skills` (no caching today; KV cache was planned in C14 but the premise was invalid — no cache exists to bust).
Workspace skills served by `GET /api/skills/workspace?slug=<slug>` (auth required).

---

## Routes

| Route | What |
|-------|------|
| `/skills` | Catalog browser — all 55 fleet + legacy skills |
| `/u/[slug]/skills` | Dashboard: installed workspace skills + catalog browser below |
| `/u/[slug]/skills/new` | Create a new skill — SkillStudio with blank template |
| `/u/[slug]/skills/[name]` | View skill detail (read-only) + Eval section + Fork link |
| `/u/[slug]/skills/[name]/edit` | Edit skill — SkillStudio (Properties + Body + Chat) |
| `/features/skills` | Marketing landing page |

---

## API endpoints

| Method | Path | Purpose | Auth |
|--------|------|---------|------|
| `GET` | `/api/skills` | Fleet + legacy catalog. `?q=` filters | public |
| `GET` | `/api/skills/[name]` | Read one workspace skill | Bearer |
| `PUT` | `/api/skills/[name]/save` | Write skill content to R2 | session |
| `DELETE` | `/api/skills/[name]/save` | Remove from R2 | session |
| `POST` | `/api/skills/[name]/fork` | Copy skill to a new name | session |
| `POST` | `/api/skills/[name]/refresh` | Re-fetch from frontmatter `ref:` URL | session |
| `POST` | `/api/skills/[name]/enable` | Enable/disable skill for an agent in D1 | dual: Bearer **or** session |
| `GET` | `/api/skills/workspace` | List workspace-installed skills | session |
| `POST` | `/api/eval` | Run grader; accepts optional `draftContent` and `draftEvals` for unsaved iterations | public (worth gating) |

`save`/`fork`/`refresh` all use the same `requireAuth('update_group')` + slug-binding pattern. Cross-workspace writes return 403.

---

## Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `SkillsView` | `components/skills/SkillsView.tsx` | Catalog grid + search + import URL. Two modes: `page` and `section` |
| `SkillsList` | `components/skills/SkillsList.tsx` | Maps `SkillsListEntry[]` → `<SkillRow>` rows. Hydrated as one `client:idle` island |
| `SkillRow` | `components/skills/SkillRow.tsx` | Single capability row: mastery chip + `[Edit] [Add to agent ▾] [Evaluate] [⋯]` cluster + OverflowMenu (Fork · Refresh · View source · Delete) |
| `AddToAgentMenu` | `components/skills/AddToAgentMenu.tsx` | Popover listing user's agents with checkbox toggles → `/api/skills/[name]/enable` |
| `SkillStudio` | `components/skills/SkillStudio.tsx` | Authoring surface for `/new` + `/edit`. Three regions: Properties (top) + OneEditor body + ChatDock |
| `PropertiesBlock` | `components/skills/PropertiesBlock.tsx` | Notion-style frontmatter editor — key/value rows with type-aware widgets, `+ Add property`, X-to-remove for unknown keys |
| `SkillEvalPanel` | `components/skills/SkillEvalPanel.tsx` | Detail page eval section: mastery chip + sparkline curve + latest `<EvalCard>` + iteration history + `Run eval now` |
| `SkillProposalCard` | `components/skills/SkillProposalCard.tsx` | Rendered in chat when the assistant emits a fenced SKILL.md proposal. Apply → `studioStore.init(parsed)` replaces editor contents |

---

## Astro server actions (`actions/skills.ts`)

| Action | What | Status |
|--------|------|--------|
| `skill.list` | List workspace skills from R2 | ok |
| `skill.import` | Import from URL → R2 | ok |
| `skill.fork` | Duplicate an existing skill under a new name | ok (HTTP route also at `/api/skills/[name]/fork`) |
| `skill.refresh` | Re-fetch from `ref:` URL | ok (HTTP route also at `/api/skills/[name]/refresh`) |
| `skill.emit` | Return raw skill content | ok |
| `skill.delete` | Remove from R2 | ok |
| ~~`skill.eval`~~ | — | **removed** (C18, 2026-05-24); chat routes through `/api/eval` directly |

---

## Skill creation workflows

### 1. Chat-led: propose-then-apply (C11-simple — current primary)

When `surface === 'skills'`, `chat.ts` adds a system-prompt addendum teaching the model to output complete skills as fenced markdown blocks (` ```md\n---\n...\n--- ` + body + ` ``` `). `ChatDock` detects these on assistant messages and renders a `SkillProposalCard` instead of the plain text bubble:

```
┌────────────────────────────────┐
│ 📝 Proposed skill              │
│   title       Email Summarizer │
│   description Use when…        │
│   tags        email, summary   │
│   ── body — 1,240 chars ──     │
│   [ Apply to editor ] [Discard]│
└────────────────────────────────┘
```

Apply → `studioStore.init({ meta, body })` → Properties block + body editor populate → human reviews → clicks Save in the Studio header → `PUT /api/skills/[name]/save` → R2.

No new endpoints, no client-side tools, no AI SDK `onToolCall` integration. The model uses its native output (markdown); the human owns Save.

### 2. Direct authoring in the Studio

```
/u/[slug]/skills/new        → blank template → SkillStudio
/u/[slug]/skills/[name]/edit → load from R2  → SkillStudio
```

**Layout (top-to-bottom on mobile, properties-then-row on desktop):**
- **Header bar:** `name` (display-only) · Saved badge · Delete · Save (label shifts to "Save with warnings (N)" when diagnostics > 0)
- **Diagnostics banner** (when parser warnings present)
- **Properties block** — collapsible Notion-style key/value editor; known keys (title/description/price/tags/version/ref/license) get typed widgets; unknown keys render as text with X-to-remove
- **Body** (OneEditor — Novel/Tiptap) + **Chat** (ChatDock with `surface="skills"`)

Save flow: read meta + body from `studioStore` → `emitSkill()` → `PUT /api/skills/[name]/save`.

### 3. Import from URL / github ref

```
/skills or /u/[slug]/skills → "Import URL" form → POST /api/skill/import
```

Resolves `github:owner/repo/path` or direct URL. Calls `lib/skill/import.ts:importSkill()`.
Writes to `<slug>/skills/<name>/SKILL.md` (named copy) + `<slug>/skills/_remote/<hash>/SKILL.md` (cache).

### 4. CLI

```
oneie skill new <name>            # scaffold a SKILL.md (no tests yet — see Open gaps)
oneie skill validate <path>       # offline diagnostics
oneie skill eval <path>           # ⚠️ stub — returns {passed:0}; see Open gaps
oneie skill import <ref>          # via @oneie/sdk skillsImport()
oneie skill list / unimport / refresh / publish / emit
```

---

## Profile page action buttons

Each installed skill on `/u/[slug]/skills` shows three primary actions plus an overflow menu:

| Button | Action |
|--------|--------|
| **Edit** | → `/u/[slug]/skills/[name]/edit` (primary fill) |
| **Add to agent ▾** | Opens `<AddToAgentMenu>` popover; checkbox-toggles call `POST /api/skills/[name]/enable` per agent. Label flips to "On N agents" |
| **Evaluate** | → `/u/[slug]/skills/[name]#eval` (outline — links to the `SkillEvalPanel`) |
| **⋯** | Overflow: Fork · Refresh (only when `meta.ref` set) · View source · Delete |

Vocabulary note: "Add to agent" replaced "Wire" per `feedback_marketing_copy.md` — substrate verbs (mark/warn/wire) stay out of user-facing prose. The D1 column `agent_skills` is unchanged (substrate, not user copy).

---

## Skill lib (`lib/skill/`)

| File | What |
|------|------|
| `parser.ts` | YAML frontmatter parser. `parse(md) → { meta, body, diagnostics }` |
| `loader.ts` | R2 skill loader. Handles flat `.md` and dir `SKILL.md` forms. `loadSkill(key, r2) → Skill` |
| `import.ts` | Import from URL/github. `importSkill(ref, slug, r2, opts)` |
| `emit.ts` | Serialise `Skill` → SKILL.md files map. `emitSkill(skill) → Map<path, content>` |
| `discovery.ts` | Scan R2 prefix → list of Skills. `discoverSkills(slug, r2)` |
| `studio-store.ts` | `useSyncExternalStore` over `{ meta, body, dirty, savedAt, diagnostics }` — shared between Properties block, body editor, and (future) chat tools |
| `proposal.ts` | `extractProposal(text) → { meta, body } \| null` — detects assistant-emitted SKILL.md proposals in chat messages |
| ~~`auto-import.ts`~~ | **removed in C18 (2026-05-24)** — orphan code; skill-creator inlines into `chat.ts` system prompt as a build asset (C20, planned) |

---

## Eval system

```
SKILL.md + evals/evals.json
  ↓
POST /api/eval { slug, skillPath, iteration, draftContent?, draftEvals? }
  ↓
runner.ts → grader.ts → aggregate.ts → mastery.ts (BKT curve)
  ↓
R2: <slug>/skills/_workspace/<name>/iteration-N/benchmark.json
   (or iteration-N.draft/ when draftContent is supplied)
```

`loadHistory(slug, name, r2, { includeDraft? })` reads benchmarks back; the detail page (`SkillEvalPanel`) defaults to `includeDraft: false`; the Studio (when wiring "Run eval on draft" in C12) will pass `true`.

`<EvalCard>` (`components/chat/EvalCard.tsx`) is the inline benchmark widget — used both in chat and inside `SkillEvalPanel`.

Detailed lifecycle, TestCase shape, and worked example: see [`evaluate.md`](evaluate.md).

---

## What is built

- [x] Fleet catalog served by `/api/skills` (48 + 7 skills)
- [x] `SkillsView` — catalog grid with search, import URL. Page + section modes
- [x] `/u/[slug]/skills` — capability dashboard with SSR-loaded rows, mastery chip, `[Edit] [Add to agent ▾] [Evaluate] [⋯]` cluster, three-card empty state, catalog collapses to `<details>` when installed > 0
- [x] `/u/[slug]/skills/[name]` — detail view + `<section id="eval">` rendering `SkillEvalPanel` (mastery chip + sparkline + iteration history + Run eval) + `<section id="fork">` placeholder
- [x] `/u/[slug]/skills/new` + `/[name]/edit` — `SkillStudio` (Properties + Body + Chat). Single `studioStore` source of truth via `useSyncExternalStore`
- [x] `PropertiesBlock` — Notion-style frontmatter editor, type-aware widgets, unknown-key preservation, `+ Add property`
- [x] Parser diagnostics surfaced as a banner above Properties + Save button label flips to "Save with warnings (N)"
- [x] `SkillProposalCard` — chat-led authoring: assistant emits fenced SKILL.md, ChatDock renders it as Apply/Discard card
- [x] `SkillRow` + `AddToAgentMenu` + `SkillsList` — row layout, popover-based agent wiring, single `client:idle` island
- [x] `PUT/DELETE /api/skills/[name]/save` — session-authed R2 write/remove, slug-bound
- [x] `POST /api/skills/[name]/{fork,refresh}` — session-authed, slug-bound
- [x] `POST /api/skills/[name]/enable` — dual auth (Bearer **or** session); session branch verifies agent ownership
- [x] `POST /api/eval` — accepts optional `draftContent` and `draftEvals`; writes to `iteration-N.draft/` path when draft
- [x] `loadHistory(...)` extracted from inline SSR; `includeDraft` filter
- [x] `OneEditor` (Novel/Tiptap) at `components/editor/Editor.tsx`
- [x] All skill actions: list, import, fork, refresh, emit, delete (skill.eval removed in C18 — chat routes through `/api/eval` directly)
- [x] **"Author from anywhere"** collapsible on `/u/[slug]/skills` — surfaces the three non-browser front doors (CLI · MCP · raw HTTP) with copy-pastable command snippets and a link to `plans/skill-format.md`
- [x] **Catalog cards: three primary actions** — `SkillsView` `SkillCard` exposes `[Add] [Edit] [Evaluate]` per skill (matches dashboard verb parity). All three install via `POST /api/skill/import` with bundled content (catalog endpoint now supports `?expand=content`); Edit + Evaluate redirect to `/edit` and `/[name]#eval` respectively after install. Visible error banner replaces silent failures.

---

## Open gaps — the simplified plan (~1.5h to complete)

After the 2026-05-24 simplification pass, the open work collapsed to four trivial cycles. See [`skills-todo.md`](skills-todo.md) Status section for sequencing.

| # | Gap | Fix | Cost |
|---|---|---|---|
| 1 | ~~`autoImportSkillCreator()` orphan code~~ | **DONE (C18 + C20, 2026-05-24)** — file deleted; skill-creator methodology now inlines into `chat.ts` system prompt as a build-time `?raw` import when `body.group === 'skills'` | — |
| 2 | ~~`actions/skills.ts skill.eval` runs `runCase` 2× per case~~ | **DONE (C18, 2026-05-24)** — action removed; chat routes through `/api/eval` directly | — |
| 3 | Separate `evals/evals.json` sidecar file still read by `/api/eval` | **Demote to fallback** — primary path should read `evals:` from skill frontmatter. **Blocked on YAML parser**: `lib/skill/parser.ts` handles only flat `- string` arrays. Needs nested-object support before sidecar can stop being authoritative | ~1h (follow-up after parser upgrade) |
| 4 | ~~CLI `oneie skill eval` is a stub~~ | **DONE (C19, 2026-05-24)** — POSTs to `/api/eval` with `draftContent` + `draftEvals` extracted from frontmatter | — |
| 5 | ~~`oneie skill new` doesn't scaffold tests~~ | **DONE (C19, 2026-05-24)** — template writes 3 example `evals:` entries (representative · edge · negative) | — |
| 6 | ~~MCP has no authoring~~ | **DONE (C21, 2026-05-24)** — `skill_eval` tool added to `packages/mcp/src/tools/lifecycle.ts`. Model writes markdown natively; this measures it | — |
| 7 | ~~`/api/eval` is public~~ | **DONE (C23, 2026-05-24)** — dual-auth gate: Bearer `<slug>:SERVER_SECRET` for CLI/MCP, session for browser; `body.slug === authedSlug` enforced | — |

**Explicitly NOT in the plan** (and explicitly *removed* from earlier drafts):

- ~~Lift markdown contract into `@oneie/sdk`~~ → YAML doesn't drift; the schema is `skill-format.md`, not a package
- ~~Tests tab in SkillStudio~~ → tests live in frontmatter, edited inline
- ~~Live external-writer sync (WsHub DO + SSE)~~ → MCP `skill_eval` + browser refresh = same UX, 5% of the code
- ~~MCP `skill_propose` tool~~ → models write markdown natively; that's not a tool

The architectural rule that drove the simplification (root CLAUDE.md):
> **Power through simplicity — the meta-layer should obey the rule the schema already obeys.**

The TypeDB substrate has a grammar, not an SDK. Skills follow the same pattern: a markdown grammar + one HTTP endpoint. Every surface speaks YAML + HTTP locally; no shared client code, no version coordination, no drift.

---

## See also

- **[`skill-format.md`](skill-format.md) — the substrate** (schema + endpoint, one page, read first)
- [`evaluate.md`](evaluate.md) — eval lifecycle, TestCase shape, mastery curve, BKT details
- [`skills-todo.md`](skills-todo.md) — current cycle status + plan close
- [`skills-implementation-todo.md`](skills-implementation-todo.md) — import system (A–F tasks), shipped
- [`agent-spec.md`](agent-spec.md) — agent runtime, skill tool wiring in `chat.ts`
- [`one.ie/agents/skill-creator/SKILL.md`](../one.ie/agents/skill-creator/SKILL.md) — the methodology prose (inlined into system prompt for `surface=skills`)
- [`lib/skill/`](../one.ie/web/src/lib/skill/) — runtime code
- [`actions/skills.ts`](../one.ie/web/src/actions/skills.ts) — server actions
