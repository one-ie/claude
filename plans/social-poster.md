---
title: Social Poster
slug: social-poster
type: plan
tier: complex
mode: construction
tags: [social, composio, agent, in, scheduler, cron]

# ─── GOAL CONTRACT ───────────────────────────────────────────────────
goal: "Operator can connect every Composio social channel, have the agent plan content, then see it on a calendar and a lifecycle kanban — drag to reschedule or approve — with posts auto-publishing on schedule; the same actions are callable by Claude Code over the API."
outcome: "(ls agents/migrations/ one.ie/web/migrations/ 2>/dev/null | grep -q social_posts) && grep -q 'TWITTER' agents/src/composio-toolkits.ts && grep -q 'composio' one.ie/agents/marketing/social-media-manager.md && grep -qE 'publishDuePosts|social_posts' agents/src/cron.ts && test -f 'one.ie/web/src/pages/in/[groupId]/social.astro' && test -f 'one.ie/web/src/pages/in/[groupId]/calendar.astro' && test -f one.ie/web/src/components/in/SocialKanban.tsx && bun vitest run tests/e2e/social-scheduler.test.ts"
outcome_asserts: "The social_posts table exists, social toolkits are wired, the agent declares Composio tools, the cron scheduler publishes due posts, the social + calendar routes and the kanban component are on disk, and the scheduler test proves a due post publishes + emits its signal."

deliverables:
  - migration: social_posts table — content, platforms[], media (url/type/duration), scheduled_at, status, composio_account_ids, source (C2)
  - config: agents/src/composio-toolkits.ts — TWITTER, LINKEDIN, INSTAGRAM, TIKTOK, FACEBOOK auth configs + skill→toolkit map (C1)
  - api: GET /api/social/accounts — connected accounts for a group (C2)
  - api: GET·POST /api/social/posts — list + create/schedule posts (C2)
  - api: PATCH /api/social/posts/:id — approve / edit / reschedule / advance status — the single endpoint every drag + Claude Code action hits (C2)
  - api: POST /api/social/media — upload image/video → R2, per-platform validation (C2)
  - lib: one.ie/web/src/lib/social-validate.ts — per-platform media + char-limit rules (C2)
  - agent: one.ie/agents/marketing/social-media-manager.md + draft_social_post tool — agent drafts a plan into the queue (C3)
  - scheduler: agents/src/cron.ts — publishDuePosts() auto-publishes; generateWeeklyPlan() recurring drafts (C4)
  - route: /in/[groupId]/social — connect, plan, approve, compose, upload media, view queue (C5)
  - component: one.ie/web/src/components/in/SocialPoster.tsx — the social workspace; C5 also adds Social/Calendar/Kanban tabs to Navigation (C5)
  - cli+mcp: `one social {list,draft,approve,reschedule,publish-now}` + matching MCP tools — Claude Code & terminal drive the same lifecycle (C8)
  - route: /in/[groupId]/calendar + ContentCalendar.tsx — react-big-calendar (DnD): drag to reschedule date, resize to change time (C6)
  - component: one.ie/web/src/components/in/SocialKanban.tsx + /in/[groupId]/board route — lifecycle columns; drag a card to approve / advance status (C7)

ux_before: "Operator uses external tools to write, schedule, and publish to each platform separately; no planning, board, or automation exists in /in."
ux_after: "Operator connects accounts once, lets the agent (or weekly cron) draft a plan, drags cards across a kanban to approve them and drags events on a calendar to reschedule; approved posts auto-publish on schedule — and Claude Code can do all of it over the API."
ux_delta: "A multi-tool, manual, per-platform chore becomes: drag to approve / reschedule (or let Claude Code do it) → everything publishes itself on schedule, planned by the agent."

# ─── PARALLELISM ─────────────────────────────────────────────────────
parallel_budget:
  haiku:  20
  sonnet: 10
  opus:   2

batches:
  - [C1]
  - [C2]
  - [C3, C5, C8]
  - [C4, C6, C7]

shared_recon:
  - agents/src/composio-toolkits.ts
  - agents/src/composio.ts
  - agents/src/cron.ts
  - agents/src/agents/export-hubspot.ts
  - one.ie/web/src/pages/api/composio/connect.ts
  - one.ie/web/src/components/in/Navigation.tsx

source_of_truth:
  - agents/src/composio-toolkits.ts
  - agents/src/cron.ts
  - one.ie/agents/marketing/social-media-manager.md

existing_primitives:
  - agents/src/composio.ts: makeComposio + composioFallback — creates client, auto-discovers connected platforms; C2 accounts API + C4 publish reuse this, no new client code
  - agents/src/composio-toolkits.ts: AUTH_CONFIGS + SKILL_TOOLKIT_MAP — C1 extends; everything else reads
  - agents/src/cron.ts: existing scheduled handler — C4 EXTENDS this (adds publishDuePosts + generateWeeklyPlan); do NOT create a new worker
  - agents/src/agents/export-hubspot.ts: the writethrough pattern (D1 queue → POST to platform → mark/warn) — C4 mirrors this exact shape for publishing; do NOT invent a new pattern
  - agents/src/lib/emit-event.ts: signal emission helper — C4 uses for social:<id>:published
  - one.ie/web/src/pages/api/composio/connect.ts: OAuth initiation — C5 calls unchanged; no new auth flow
  - one.ie/web/src/components/in/IntegrationsList.tsx: connected-integrations list — C5 composes / mirrors for accounts panel
  - one.ie/web/src/components/in/Composer.tsx: compose panel — C5 composes for the draft editor
  - one.ie/web/src/components/in/BoardView.tsx + PeopleKanban.tsx: EXISTING kanban/board with drag — C7 reuses this drag primitive for the lifecycle board; do NOT build a new kanban
  - one.ie/web/src/components/in/Navigation.tsx: /in tab nav — C5 adds ALL THREE tabs (Social/Calendar/Kanban) so C6+C7 never touch this file (no same-file conflict)
  - one.ie/agents/marketing/social-media-manager.md: agent with weekly-calendar instruction + 3 human-in-loop checkpoints — C3 wires its drafts to the queue; reuse the prompt, don't rewrite it
  - packages/cli/ + packages/mcp/: @oneie/cli (one/oneie bins) + @oneie/mcp (12 verbs) — C8 adds social verbs/tools here so Claude Code drives the same API; do NOT add a parallel surface
  - react-big-calendar (npm) + shadcn Big Calendar template: Day/Week/Month + withDragAndDrop HOC (onEventDrop = reschedule date, onEventResize = change time) — C6 uses this engine, shadcn-skinned; charlietlamb/calendar dropped (no drag support)

show: false
escape:
  condition: "C2 W1 finds web and agents-worker bind DIFFERENT D1 databases"
  action: "halt C2; switch the scheduler (C4) to call GET/PATCH /api/social/posts over HTTP instead of reading D1 directly, and put the migration in the web worker. Re-confirm before C2 W3."

context_triggers:
  - pattern: "composio-toolkits|AUTH_CONFIGS|SKILL_TOOLKIT_MAP"
    inject: "agents/src/composio-toolkits.ts § full file"
  - pattern: "writethrough|pending_writethroughs|export-(hubspot|salesforce)"
    inject: "agents/src/agents/export-hubspot.ts § publish loop"
  - pattern: "social-media-manager|human-in-the-loop|pending:human-approval"
    inject: "one.ie/agents/marketing/social-media-manager.md § Operating Instructions"
---

# Social Poster

## Goal, outcome, deliverables, UX

### Goal

Operator can connect social accounts, have the agent plan content (on-demand or weekly), approve drafts, and have posts auto-publish to multiple platforms on schedule — all from `/in`.

### Outcome (the kill-switch)

```bash
(ls agents/migrations/ one.ie/web/migrations/ 2>/dev/null | grep -q social_posts) && \
grep -q 'TWITTER' agents/src/composio-toolkits.ts && \
grep -q 'composio' one.ie/agents/marketing/social-media-manager.md && \
grep -qE 'publishDuePosts|social_posts' agents/src/cron.ts && \
test -f 'one.ie/web/src/pages/in/[groupId]/social.astro' && \
bun vitest run tests/e2e/social-scheduler.test.ts
```

**What passing proves:** The persistence layer exists, social platforms are wired into Composio, the agent declares its posting tools, the cron scheduler contains the auto-publish loop, the social route is on disk, **and the scheduler test proves a due post actually publishes and emits `social:<id>:published`** (mocked Composio — behavioral, not just file-existence).

**Contract:** runs after every batch's W4. Plan does not close until it exits 0.

### Deliverables

| Kind | Path / name | What the user sees or can do | Cycle |
|---|---|---|---|
| config | `agents/src/composio-toolkits.ts` | 5 social platforms in AUTH_CONFIGS + SKILL_TOOLKIT_MAP | C1 |
| migration | `social_posts` table | scheduled posts persist with content, platforms, media, status | C2 |
| api | `GET /api/social/accounts` | connected social accounts for the group | C2 |
| api | `GET·POST /api/social/posts` | list + create/schedule posts | C2 |
| api | `PATCH /api/social/posts/:id` | approve / edit / reschedule a draft | C2 |
| api | `POST /api/social/media` | upload image/video → R2, validated per platform | C2 |
| lib | `web/src/lib/social-validate.ts` | per-platform char + media rules | C2 |
| agent | `social-media-manager.md` + `draft_social_post` tool | agent drafts a content plan into the queue | C3 |
| scheduler | `agents/src/cron.ts` | due posts auto-publish; weekly cron drafts next week | C4 |
| route | `/in/[groupId]/social` | connect, plan, approve, compose, upload, queue | C5 |
| component | `in/SocialPoster.tsx` | the social workspace island | C5 |
| route | `/in/[groupId]/calendar` + `in/ContentCalendar.tsx` | month/week/day calendar of posts | C6 |

### User experience: before → after

| | Today | After |
|---|---|---|
| **Who** | Operator running a brand's social | Operator running a brand's social |
| **Goal** | Keep a steady multi-platform posting cadence | Same |
| **Steps** | 1. Brainstorm posts 2. Write per platform 3. Open each app 4. Paste, attach media, set time 5. Repeat ×N daily | 1. Connect once 2. "Plan next week" (or let Monday cron do it) 3. Approve the drafts 4. Done — they publish themselves |
| **Friction** | Per-platform rewriting, manual scheduling, easy to forget, no overview | Agent drafts + adapts per platform; cron publishes; calendar shows the whole week |
| **Feedback** | None until you check each app | Live status per post (scheduled → published/failed) + calendar |

**The improvement (ux_delta):** A manual, per-platform, easy-to-drop chore becomes "approve once → it publishes itself on schedule, planned by the agent."

**The proof a future-you points at:**

```
# tests/e2e/social-scheduler.test.ts (green) proves the automation:
✓ publishDuePosts: a scheduled post past its time → Composio publish called
✓ on success → status='published', social:<id>:published emitted
✓ on failure → status='failed', warn() deposited, error stored
```

---

## Reuse contract

### The two patterns we are NOT allowed to reinvent

1. **Publishing = the export-agent writethrough.** `agents/src/agents/export-hubspot.ts` already does "read D1 queue of pending items → POST to external platform → mark on success / warn on failure." C4's `publishDuePosts` is the same loop with Composio as the target. Copy the shape; do not invent a new queue mechanic.
2. **OAuth = `composio/connect.ts`.** It already initiates OAuth for any Composio toolkit. C5's connect buttons POST to it. No new auth route, no new redirect handler.

### Compose-or-construct — anti-patterns rejected on sight

- ❌ New scheduled worker when `agents/src/cron.ts` exists → **extend cron.ts**
- ❌ New OAuth/redirect route when `composio/connect.ts` covers it
- ❌ New `<Composer>`/`<Toolbar>` when `Composer.tsx` + `in/composer/*` exist
- ❌ New calendar from scratch when charlietlamb/calendar is MIT and shadcn-native
- ❌ Re-fetching connected accounts by hand when `composioFallback` already lists them
- ❌ A bespoke pub/queue table when the `pending_writethroughs` pattern is established

### Reuse audit (mandatory W4 line every cycle)

- [ ] New-file LOC under the cycle's W2 budget (`wc -l`)
- [ ] Each W2 slot-map primitive appears as an import in the new code (grep)
- [ ] Named anti-pattern greps return zero hits in this cycle's new files

---

## Parallel execution plan

```
                 C1 (auth configs, trivial)
                  │
                 C2 (schema + APIs + media + validate)   ← the data backbone
              ╱   │   ╲
            C3    C5    C8        ← agent planning ‖ social UI (+all nav tabs) ‖ CLI/MCP for Claude Code
             │   ╱ ╲
            C4  C6   C7           ← scheduler (needs C3) ‖ calendar+drag (needs C5) ‖ kanban+drag (needs C5)
```

**Arrow proofs:**
- C1→C2: `/api/social/accounts` reads `SKILL_TOOLKIT_MAP` from composio-toolkits.ts (C1 writes it)
- C2→C3: `draft_social_post` tool POSTs to `/api/social/posts` (C2 writes the route + schema)
- C2→C5, C2→C8: the UI and the CLI/MCP both call `/api/social/{accounts,posts,media}` (C2 writes them)
- C3→C4: `generateWeeklyPlan` invokes the agent that C3 wires (the recurring drafter)
- C5→C6, C5→C7: both import `useSocialPosts()` from `web/src/lib/social.ts` (C5 writes it); C5 also owns the Navigation tab edits so C6/C7 never touch that file
- **No C6↔C7 arrow:** disjoint files (ContentCalendar vs SocialKanban), both read social.ts → parallel

| Batch | Cycles | What runs in parallel |
|---|---|---|
| 0 | shared | W0 baseline + 6 shared_recon files in one Haiku spawn |
| 1 | C1 | trivial config edit — inline, no spawn |
| 2 | C2 | full W1–W4; the D1-sharing decision gates W3 |
| 3 | C3, C5, C8 | three cycles W1–W4; agent worker ‖ web UI ‖ cli+mcp packages — all disjoint, W3a merges into one Sonnet message |
| 4 | C4, C6, C7 | three cycles W1–W4; cron.ts ‖ calendar ‖ kanban — all disjoint files |

---

## Status

```
Batch 0 (shared)
  - [ ] W0 baseline
  - [ ] W1 shared recon (6 files)

Batch 1
  - [ ] C1 — Social platform auth configs          state: ready
    - [ ] W1 · W2 · W3 · W4

Batch 2  (fires when C1 closes)
  - [ ] C2 — Schema + APIs + media + validation     state: blocked-on-C1
    - [ ] W1 · W2 · W3 · W4
    - [ ] ⚠ W1 gate: confirm web ⇄ agents-worker share one D1 (escape if not)

Batch 3  (fires when C2 closes)
  - [ ] C3 — Agent content planning + draft tool     state: blocked-on-C2
    - [ ] W1 · W2 · W3 · W4
  - [ ] C5 — Social UI + all nav tabs + social.ts hook  state: blocked-on-C2
    - [ ] W1 · W2 · W3 · W4
  - [ ] C8 — CLI + MCP social verbs (Claude Code)    state: blocked-on-C2
    - [ ] W1 · W2 · W3 · W4
  - [ ] demo batch (vitest run c3.test c5.test c8.test)

Batch 4  (fires when C3+C5 close)
  - [ ] C4 — Auto-publish scheduler + recurring planner   state: blocked-on-C3
    - [ ] W1 · W2 · W3 · W4
  - [ ] C6 — Content calendar + drag-to-reschedule   state: blocked-on-C5
    - [ ] W1 · W2 · W3 · W4
  - [ ] C7 — Lifecycle kanban + drag-to-approve      state: blocked-on-C5
    - [ ] W1 · W2 · W3 · W4
  - [ ] demo batch (vitest run c4.test c6.test c7.test)

Plan close
  - [ ] Plan outcome command exits 0 (incl. scheduler test)
  - [ ] Every deliverables row shipped + reachable
  - [ ] ux_after journey walkable end-to-end (record proof)
  - [ ] Final compress sweep
  - [ ] Final docs/improvements.md append
  - [ ] Plan rubric ≥ 0.65
```

---

## C1 — Social platform auth configs  [tier: trivial · batch: 1]

**Goal delta:** The 5 social platforms exist in `AUTH_CONFIGS` + `SKILL_TOOLKIT_MAP` so every later cycle references them by name.

**Deliverable:** `agents/src/composio-toolkits.ts` extended.

**UX delta:** Internal — unlocks C2+.

**Cycle outcome:** `grep -q 'TWITTER' agents/src/composio-toolkits.ts && grep -q "twitter" agents/src/composio-toolkits.ts`

**Demo gate:**
```yaml
demo:
  command: "grep -q 'TWITTER' agents/src/composio-toolkits.ts && grep -q 'twitter' agents/src/composio-toolkits.ts && echo pass"
  asserts: "social platform IDs + skill mappings defined"
  budget: "<1s · 0 LOC test"
```

### W1 — Recon  [inline]
- [ ] `agents/src/composio-toolkits.ts` — current shape of AUTH_CONFIGS + SKILL_TOOLKIT_MAP

### W2 — Decide  [inline]
- [ ] **Compose-or-construct:** extend the existing file (same pattern) — verdict **extend**
- [ ] Auth-config IDs come from the Composio dashboard (`composio.authConfigs.list()`); `connect.ts` resolves IDs dynamically, so `'ac_PROVISION_IN_DASHBOARD'` placeholders are safe and type-only
- [ ] Platforms: TWITTER, LINKEDIN, INSTAGRAM, TIKTOK, FACEBOOK

### W3 — Edit  [inline]
**W3a:**
- [ ] `agents/src/composio-toolkits.ts` — add 5 entries to `AUTH_CONFIGS`; add `twitter/linkedin/instagram/tiktok/facebook` → toolkit slugs in `SKILL_TOOLKIT_MAP`

### W4 — Verify  [inline]
- [ ] `bun run verify` green
- [ ] both greps in the demo exit 0
- [ ] plan-outcome partial: `grep -q 'TWITTER'` condition now passes
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C2 — Schema + APIs + media + validation  [tier: complex · batch: 2]

**Goal delta:** Posts persist with a full lifecycle; the web exposes accounts, posts CRUD, and validated media upload — the backbone C3/C4/C5/C6 all build on.

**Deliverable:** `social_posts` migration + 4 API routes + `social-validate.ts`.

**UX delta:** Internal — but `GET /api/social/accounts` is independently demoable (returns connected platforms).

**Cycle outcome:** `bun vitest run tests/e2e/social-api.test.ts` (posts CRUD + media validation) **and** the migration applies clean.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-api.test.ts"
  asserts: "POST /api/social/posts persists a draft; PATCH approves+schedules it; social-validate rejects an over-limit/oversized payload"
  budget: "<2s · <150 LOC test"
```

### W1 — Recon  [Haiku · parallel]

1. **Existing-code recon**
   - [ ] ⚠ **D1-sharing gate** — read `agents/wrangler.toml` AND `one.ie/web/wrangler.toml` (or astro D1 binding): do they point to the **same `database_id`**? Report both bindings verbatim. *(escape trigger if different)*
   - [ ] `agents/migrations/` — existing migration naming + latest number; the table-creation style
   - [ ] `one.ie/web/src/pages/api/composio/connect.ts` — how `locals.slug`/userId + bindings are accessed in a web API route
   - [ ] `one.ie/web/src/pages/api/signal/` (or nearest) — the established D1-write API route shape in web
   - [ ] `agents/src/composio.ts` + `composio-toolkits.ts` (post-C1) — `connectedAccounts.list` shape for the accounts route

2. **Primitive-inventory recon**
   - [ ] R2 binding — grep `wrangler.toml` for an R2 bucket usable for media (else note "add binding")
   - [ ] `one.ie/web/src/lib/` — any existing upload / validation / fetch helpers to reuse

### W2 — Decide  [Opus]

- [ ] **D1-sharing resolved** — if shared: migration → `agents/migrations/`, scheduler reads D1 directly (C4). If NOT shared: migration → web worker, scheduler uses HTTP (escape action) — record which.
- [ ] **Compose-or-construct verdict** (new routes are legitimately new surfaces, not reimplementations):

| Proposed file | Closest primitive | Gap | Verdict |
|---|---|---|---|
| `migrations/NNNN_social_posts.sql` | existing migrations | no social table exists | **new** (data foundation) |
| `api/social/accounts.ts` | composio/connect.ts (OAuth only) | no accounts-list route | **new** ≤50 LOC, reuses composioFallback |
| `api/social/posts/index.ts` (GET·POST) | signal API (writes D1) | different entity | **new** ≤90 LOC, follows signal-route shape |
| `api/social/posts/[id].ts` (PATCH) | — | approve/edit/reschedule | **new** ≤60 LOC |
| `api/social/media.ts` (POST) | — | R2 upload + validation | **new** ≤80 LOC |
| `lib/social-validate.ts` | — | per-platform rules | **new** ≤90 LOC (pure fns, fully unit-tested) |

- [ ] **Schema decision** — columns:
  `id, group_id, content (text), platforms (json array), media_url, media_type ('image'|'video'|null), media_duration_s, scheduled_at (int epoch), status ('draft'|'approved'|'scheduled'|'publishing'|'published'|'failed'), composio_account_ids (json), source ('manual'|'agent-ondemand'|'agent-weekly'), created_at, approved_at, published_at, error`
- [ ] **Media transport to Composio** — does the platform tool take a public URL or a file? Default: store in R2, pass public R2 URL. Confirm against a Composio social tool signature; note if base64 needed.
- [ ] **Validation rules** (`social-validate.ts`) — char limits (X 280, LinkedIn 3000, etc.), image max MB, video max duration per platform (TikTok ≤ 600s, X ≤ 140s, etc.). Pure functions, no I/O.
- [ ] **Composio account-type constraints** (verified): Instagram = Business/Creator accounts only (not personal); Facebook = Pages only (not personal profiles). The accounts API tags each account with its type; `social-validate` rejects an Instagram/Facebook target whose connected account is the wrong type, with a clear error the connect UX (C5) surfaces.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**
- [ ] `migrations/NNNN_social_posts.sql` — create table per schema decision
- [ ] `one.ie/web/src/lib/social-validate.ts` — `validatePost({content, platforms, media})` → `{ok, errors[]}`; pure
- [ ] `one.ie/web/src/pages/api/social/accounts.ts` — GET; `composioFallback`-style list filtered to social toolkit slugs; `{accounts:[{platform,status,handle}]}`; `{accounts:[]}` unauthenticated
- [ ] `one.ie/web/src/pages/api/social/posts/index.ts` — GET (list by group, filter status/date) + POST (insert draft; runs `validatePost`; 422 on fail)
- [ ] `one.ie/web/src/pages/api/social/posts/[id].ts` — PATCH (approve→status=scheduled+scheduled_at; edit; reschedule)
- [ ] `one.ie/web/src/pages/api/social/media.ts` — POST multipart → `validatePost` media checks → R2 put → return `{media_url, media_type, media_duration_s}`
- [ ] `tests/e2e/social-api.test.ts` — POST persists draft; PATCH approves+schedules; `social-validate` rejects over-limit text + oversized video (msw + in-memory D1 or mocked binding) ≤150 LOC

**W3b:** *(empty)*

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] `bun vitest run tests/e2e/social-api.test.ts` exits 0
- [ ] **Live D1 check** (deploy-surface cycle) — migration applies on the deployed worker; `GET /api/social/accounts` returns 200/JSON against deploy URL
- [ ] Reuse audit: accounts route imports from `composio.ts` (no hand-rolled account fetch); `wc -l` each new file ≤ budget
- [ ] plan-outcome partial: migration-exists condition now passes
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C3 — Agent content planning + draft tool  [tier: complex · batch: 3]

**Goal delta:** The `social-media-manager` agent turns "plan next week" into a batch of platform-adapted drafts written to `social_posts` (status=draft) — the content-plan capability becomes real.

**Deliverable:** `social-media-manager.md` (composio toolkits) + `draft_social_post` tool in the agents worker.

**UX delta:** Operator can ask the agent for a content plan and see drafts appear in the queue (visible once C5 ships; until then verifiable via `GET /api/social/posts`).

**Cycle outcome:** `bun vitest run tests/e2e/social-agent-tool.test.ts` — `draft_social_post` validates + POSTs a draft; agent frontmatter lists composio social toolkits.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-agent-tool.test.ts"
  asserts: "draft_social_post tool posts a validated draft to /api/social/posts with source='agent-ondemand'"
  budget: "<2s · <100 LOC test"
```

### W1 — Recon  [Haiku · parallel]
1. **Existing-code**
   - [ ] `one.ie/agents/marketing/social-media-manager.md` — the weekly-calendar instruction + the 3 human-in-loop checkpoints + `emits:` (`social:<id>:published`, `pending:human-approval`)
   - [ ] `agents/src/aitools.ts` — how a tool is defined + approval-gate convention (substrate-write tools pause)
   - [ ] `agents/src/agents/builder.ts` — how skills/composio toolkits get injected per agent
   - [ ] `one.ie/web/src/pages/api/social/posts/index.ts` (post-C2) — POST contract the tool will call
2. **Primitive-inventory**
   - [ ] `agents/src/composio-toolkits.ts` (post-C1) — `SKILL_TOOLKIT_MAP` social entries the agent declares
   - [ ] `one.ie/web/src/lib/social-validate.ts` (post-C2) — reuse client-side before POST (don't re-validate logic)

### W2 — Decide  [Opus]
- [ ] **Compose-or-construct:**

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `draft_social_post` in `aitools.ts` | existing tools in aitools.ts | no social-draft tool | **extend** aitools.ts (one tool, same pattern) |
| `social-media-manager.md` frontmatter | existing file | needs `composio:` list | **extend** |

- [ ] Does `draft_social_post` need an approval gate? **No** — it writes a *draft* (status=draft), not a publish. Publishing is gated by human approval (PATCH) + the scheduler. Drafting is safe/cheap.
- [ ] On-demand trigger path: operator message → agent (existing `/message`) → agent calls `draft_social_post` N times → drafts queued. The agent's existing prompt already specifies the per-platform mix; no prompt rewrite.
- [ ] Tool args: `{content, platforms[], scheduled_at?, media_url?, media_type?}` → validates via shared rules → POST `/api/social/posts` with `source='agent-ondemand'`.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `one.ie/agents/marketing/social-media-manager.md` — add `composio: [twitter, linkedin, instagram, tiktok, facebook]`; add one line to Operating Instructions: "When drafting a plan, call `draft_social_post` per post (status stays draft until a human approves)."
- [ ] `agents/src/aitools.ts` — add `draft_social_post` tool (validate → POST /api/social/posts, source agent-ondemand)
- [ ] `tests/e2e/social-agent-tool.test.ts` — calling the tool posts a validated draft; over-limit content is rejected before POST ≤100 LOC

**W3b — dependent:**
- [ ] `agents/src/agents/builder.ts` — IF recon shows composio toolkits aren't auto-injected from frontmatter, wire the `composio:` list → tools (after W3a defines the frontmatter field)

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] demo test exits 0
- [ ] Reuse audit: tool imports shared `social-validate` (no duplicated rules); agent prompt not rewritten (diff is additive)
- [ ] plan-outcome partial: `grep composio ...social-media-manager.md` now passes
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C4 — Auto-publish scheduler + recurring planner  [tier: complex · batch: 4]  ← the automation

**Goal delta:** Due scheduled posts publish themselves; a weekly cron drafts next week's plan. This is the cycle that earns the word "automated."

**Deliverable:** `agents/src/cron.ts` — `publishDuePosts()` + `generateWeeklyPlan()`.

**UX delta:** Operator does nothing at publish time — approved posts go live on schedule; a fresh plan appears each week awaiting approval.

**Cycle outcome:** `bun vitest run tests/e2e/social-scheduler.test.ts` — **the plan-outcome's behavioral test.**

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-scheduler.test.ts"
  asserts: "publishDuePosts: due post → Composio publish called → status=published + social:<id>:published; failure → status=failed + warn"
  budget: "<2s · <150 LOC test"
```

### W1 — Recon  [Haiku · parallel]
1. **Existing-code**
   - [ ] `agents/src/cron.ts` — current scheduled() shape, how it's triggered, what it already does (don't clobber)
   - [ ] `agents/src/agents/export-hubspot.ts` — the writethrough loop (queue read → POST → mark/warn); copy this shape
   - [ ] `agents/src/lib/emit-event.ts` — signal emission for `social:<id>:published`
   - [ ] `agents/src/composio.ts` — invoking a Composio tool to publish (session.tools() → execute)
   - [ ] `agents/wrangler.toml` — the `[triggers] crons` block; add the schedules
2. **Primitive-inventory**
   - [ ] `social_posts` schema (post-C2) — `status` transitions + the columns the publisher updates
   - [ ] C3's `draft_social_post` / agent invocation — how `generateWeeklyPlan` triggers the agent

### W2 — Decide  [Opus]
- [ ] **Compose-or-construct:** EXTEND `cron.ts` (the scheduled handler exists) — verdict **extend**, no new worker
- [ ] `publishDuePosts()`: `SELECT * FROM social_posts WHERE status='scheduled' AND scheduled_at <= now` → set `publishing` → for each: resolve Composio tool for platform + account → execute publish (with media URL) → success: `status='published', published_at`, `mark`, emit `social:<id>:published`; failure: `status='failed', error`, `warn`. **Exactly the export-hubspot writethrough shape.**
- [ ] `generateWeeklyPlan()`: weekly cron → invoke `social-media-manager` (the C3 path) to draft next week → drafts land `status='draft', source='agent-weekly'` awaiting human approval (NOT auto-published — honors "approve → auto-publish")
- [ ] Cron cadence: `publishDuePosts` every 5 min (`*/5 * * * *`); `generateWeeklyPlan` Monday 09:00 (`0 9 * * 1`). Add both to `wrangler.toml [triggers]`.
- [ ] Idempotency: the `publishing` interim status prevents double-publish if two ticks overlap.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `agents/src/cron.ts` — add `publishDuePosts()` + `generateWeeklyPlan()`; wire both into `scheduled()` switching on cron expression
- [ ] `agents/wrangler.toml` — add the two cron triggers
- [ ] `tests/e2e/social-scheduler.test.ts` — mock Composio + in-memory D1: due post publishes (status+signal); failing publish → failed+warn; not-yet-due post is skipped ≤150 LOC

**W3b:** *(empty)*

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **scheduler test exits 0 — this is the plan outcome's behavioral gate**
- [ ] Reuse audit: `publishDuePosts` mirrors export-hubspot (grep both for the queue→POST→mark/warn shape); `emit-event` used for the signal (not a hand-rolled emit)
- [ ] **Closed-loop check (locked rule 1):** every publish path ends in `mark` or `warn` — no silent return (grep)
- [ ] plan-outcome partial: `grep publishDuePosts cron.ts` now passes
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C5 — Social UI + nav tabs + shared hook  [tier: complex · batch: 3]

**Goal delta:** The whole workflow has a home: connect accounts, request/inspect the content plan, approve drafts, compose + attach media, watch the queue — at `/in/[groupId]/social`. C5 also creates the shared `useSocialPosts()` hook and adds **all three** nav tabs (Social/Calendar/Kanban) so C6+C7 never touch Navigation.

**Deliverable:** `/in/[groupId]/social.astro` + `in/SocialPoster.tsx` + `web/src/lib/social.ts` + all three tabs in Navigation.

**UX delta:** Operator runs the social workflow without leaving `/in`; Calendar + Kanban tabs are present (their views land in C6/C7).

**Cycle outcome:** `test -f 'one.ie/web/src/pages/in/[groupId]/social.astro' && bun vitest run tests/e2e/social-ui.test.ts`

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-ui.test.ts"
  asserts: "SocialPoster renders account cards + connect buttons, a draft list with Approve action, and a compose panel with media upload"
  budget: "<2s · <150 LOC test"
```

### W1 — Recon  [Haiku · parallel]
1. **Existing-code**
   - [ ] `one.ie/web/src/pages/in/[groupId]/settings.astro` + `index.astro` — page shell + island hydration pattern
   - [ ] `one.ie/web/src/components/in/Navigation.tsx` — tab list shape (add Social tab)
   - [ ] `one.ie/web/src/components/in/IntegrationsList.tsx` — connected-integrations rendering to mirror for accounts
   - [ ] `one.ie/web/src/pages/api/composio/connect.ts` — POST body the connect button sends
   - [ ] `/api/social/{accounts,posts,media}` (post-C2) — response shapes to hydrate
2. **Primitive-inventory**
   - [ ] `in/Composer.tsx` + `in/composer/*` (TagPills, TemplatePicker…) — compose-panel parts to reuse
   - [ ] `ui/` — Card, Button, Badge, Dialog, Tabs; `ai-elements/` — any streaming primitive for agent replies

### W2 — Decide  [Opus]
- [ ] **Compose-or-construct:**

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `social.astro` | settings.astro | new tab/island | **new** ≤50 LOC (same pattern) |
| `SocialPoster.tsx` | IntegrationsList + Composer cover parts | no single file covers accounts+plan+approve+compose+queue | **new** ≤260 LOC, composes Card/Button/Badge/Dialog/Composer |
| `lib/social.ts` (`useSocialPosts`) | — | shared fetch+mutate for C5/C6/C7 | **new** ≤80 LOC |
| Navigation.tsx | existing | add 3 tabs | **extend** |

- [ ] Sections of SocialPoster: (a) **Accounts** — cards w/ connect (`POST /api/composio/connect`) + status + account-type warning (IG needs Business/Creator, FB needs a Page); (b) **Plan/Drafts** — list from `GET /api/social/posts?status=draft`, each w/ **Approve** (`PATCH`→scheduled) + edit + "ask agent to plan" button (→ `/message`); (c) **Compose** — Composer + platform checkboxes + media upload (`POST /api/social/media`) + schedule picker; (d) **Queue** — scheduled/published/failed with status badges.
- [ ] Approval gate UX: drafts from the agent (incl. `pending:human-approval`) surface in (b); Approve is the single human action that flips draft→scheduled.
- [ ] Data hook: `useSocialPosts()` in `web/src/lib/social.ts` — **shared by C5, C6, C7**; exposes `list/create/approve/reschedule/advance/upload`, each mapping to the C2 API. C5 owns it so the calendar drag (C6) and kanban drag (C7) call the same mutations.
- [ ] **Nav ownership:** C5 adds Social + Calendar + Kanban tabs in one edit; C6/C7 add only their route+component (no Navigation edit) → no same-file conflict, full B4 parallelism.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `one.ie/web/src/lib/social.ts` — `useSocialPosts()` → `{posts, accounts, create, approve, reschedule, advance, upload}` (reschedule/advance are PATCH calls C6/C7 reuse) ≤80 LOC
- [ ] `one.ie/web/src/components/in/SocialPoster.tsx` — the 4-section workspace, composing ui/* + Composer ≤260 LOC
- [ ] `one.ie/web/src/pages/in/[groupId]/social.astro` — shell + island ≤50 LOC
- [ ] `one.ie/web/src/components/in/Navigation.tsx` — add three tabs: `{social,Share2}`, `{calendar,CalendarDays}`, `{board,Kanban}`
- [ ] `tests/e2e/social-ui.test.ts` — render w/ mocked hook: account cards + connect button; draft list w/ Approve calling PATCH; compose panel + media input present ≤150 LOC

**W3b:** *(empty — social.astro imports SocialPoster, written same pass)*

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] demo test exits 0
- [ ] **Live check** (touches pages/api-adjacent + route): `GET /in/<group>/social` returns 200/302 on deploy URL (cache-busted)
- [ ] Reuse audit: imports from `ui/` + `Composer`; no inline `<svg>` (lucide only); no new OAuth code (calls connect.ts); `useSocialPosts` is the only fetch path
- [ ] plan-outcome partial: `test -f social.astro` now passes
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C6 — Content calendar + drag-to-reschedule  [tier: complex · batch: 4]

**Goal delta:** All posts appear on a Month/Week/Day calendar at `/in/[groupId]/calendar`, color-coded by platform; the operator **drags an event to a new day to reschedule it, or resizes it to change the time** — the new time persists via PATCH.

**Deliverable:** `in/ContentCalendar.tsx` + `/in/[groupId]/calendar.astro` (Calendar tab already added by C5).

**UX delta:** Rescheduling goes from "open the post, edit a datetime field" to "grab the card and drop it on Thursday."

**Cycle outcome:** `test -f 'one.ie/web/src/pages/in/[groupId]/calendar.astro' && bun vitest run tests/e2e/social-calendar.test.ts`

**Source:** [react-big-calendar](https://www.npmjs.com/package/react-big-calendar) + its `withDragAndDrop` HOC (`onEventDrop` = reschedule date, `onEventResize` = change time/duration), shadcn-skinned via the [shadcn Big Calendar template](https://www.shadcn.io/template/list-jonas-shadcn-ui-big-calendar). Chosen over charlietlamb/calendar because that has **no drag support** and drag is now a hard requirement.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-calendar.test.ts"
  asserts: "ContentCalendar renders posts as platform-colored events; firing onEventDrop calls reschedule(id, newStart) → PATCH scheduled_at"
  budget: "<2s · <150 LOC test"
```

### W1 — Recon  [Haiku · parallel]
1. **Existing-code**
   - [ ] `one.ie/web/src/pages/in/[groupId]/social.astro` (post-C5) — shell pattern to mirror
   - [ ] `one.ie/web/src/lib/social.ts` (post-C5) — `useSocialPosts().reschedule(id, newStart)` — the mutation the drop handler calls (don't write a new one)
   - [ ] `one.ie/web/package.json` — is `react-big-calendar` already a dep? else add it + `@types/react-big-calendar`
2. **Primitive-inventory**
   - [ ] `ui/` — Badge (platform chip), Dialog (event detail), Tabs (view switch); confirm a date lib (date-fns / dayjs) is present for the rbc localizer

### W2 — Decide  [Opus]
- [ ] **Compose-or-construct:**

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `ContentCalendar.tsx` | react-big-calendar (npm) | wrap with DnD + shadcn skin + social event mapping | **wrap** ≤220 LOC (engine is the dep, we own the skin + handlers) |
| `calendar.astro` | social.astro | different island | **new** ≤50 LOC |

- [ ] Event mapping: `social_posts` → `{id,title:content[0..60],start:scheduled_at,end:+5min,resource:{platform,status,content_preview}}`; platform→color via `eventPropGetter`: X→sky, LinkedIn→blue, Instagram→pink, TikTok→violet, Facebook→indigo.
- [ ] **Drag handlers:** `onEventDrop({event,start})` → `reschedule(event.id, start)`; `onEventResize({event,start,end})` → `reschedule(event.id, start)`. **Guard:** only `draft/approved/scheduled` posts are draggable; `published/failed` are `draggableAccessor=() => false` (can't reschedule what already went out).
- [ ] Click (not drag) → Dialog: content preview + platform Badge + status + "open in workspace" link. Default Month view; Week/Day via rbc's view prop + Tabs.
- [ ] rbc cross-month drag limitation is acceptable (operators reschedule within the visible range); note it.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `one.ie/web/src/components/in/ContentCalendar.tsx` — rbc + `withDragAndDrop`, shadcn skin, `eventPropGetter` colors, `onEventDrop/onEventResize` → `useSocialPosts().reschedule`, `draggableAccessor` guard ≤220 LOC
- [ ] `one.ie/web/src/pages/in/[groupId]/calendar.astro` — shell + island (`client:load`) ≤50 LOC
- [ ] `one.ie/web/package.json` — add `react-big-calendar` (+ types) if absent
- [ ] `tests/e2e/social-calendar.test.ts` — 3 mock posts: platform-colored events render; invoking the `onEventDrop` handler calls `reschedule` with new start; a `published` post is not draggable ≤150 LOC

**W3b:** *(empty)*

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] demo test exits 0 (drag handler → reschedule asserted)
- [ ] **Live check**: `GET /in/<group>/calendar` returns 200/302 on deploy URL (cache-busted)
- [ ] Reuse audit: reschedule goes through `useSocialPosts` (grep — no inline PATCH); calendar grid is rbc, not hand-rolled
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C7 — Lifecycle kanban + drag-to-approve  [tier: complex · batch: 4]

**Goal delta:** A board at `/in/[groupId]/board` shows posts in columns by status (**Draft · Approved · Scheduled · Published · Failed**); the operator **drags a card from Draft → Approved to approve it** (and Approved → Scheduled to set a time) — the drag IS the lifecycle transition, persisted via PATCH.

**Deliverable:** `in/SocialKanban.tsx` + `/in/[groupId]/board.astro` (Kanban tab already added by C5).

**UX delta:** Approval goes from clicking a button in a list to dragging a card across a board — the whole pipeline is visible at a glance.

**Cycle outcome:** `test -f one.ie/web/src/components/in/SocialKanban.tsx && bun vitest run tests/e2e/social-kanban.test.ts`

**Source/reuse:** the EXISTING `one.ie/web/src/components/in/BoardView.tsx` + `PeopleKanban.tsx` already implement drag columns — C7 reuses that drag mechanism, not a new lib.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-kanban.test.ts"
  asserts: "dragging a card Draft→Approved calls approve(id); Published/Failed columns are drop-disabled"
  budget: "<2s · <150 LOC test"
```

### W1 — Recon  [Haiku · parallel]
1. **Existing-code**
   - [ ] `one.ie/web/src/components/in/BoardView.tsx` — its column/card model + drag handler API (what fires on drop, how columns are declared)
   - [ ] `one.ie/web/src/components/in/PeopleKanban.tsx` — the drag lib in use (dnd-kit? native?) + how a drop maps to a mutation
   - [ ] `one.ie/web/src/lib/social.ts` (post-C5) — `approve(id)` + `advance(id, status)` mutations the drop handler calls
   - [ ] `one.ie/web/src/pages/in/[groupId]/board.astro` — does C5/index already define a board route? (reuse vs new file)
2. **Primitive-inventory**
   - [ ] `ui/` — Badge (status/platform chips), Card (kanban card body)

### W2 — Decide  [Opus]
- [ ] **Compose-or-construct:**

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `SocialKanban.tsx` | BoardView.tsx / PeopleKanban.tsx | columns = post status; card = post; drop = status transition | **compose** BoardView's drag (≤180 LOC) — reuse the drag engine, feed social columns |
| `board.astro` | social.astro | different island (skip if a board route already exists) | **new** ≤50 LOC |

- [ ] Columns = `['draft','approved','scheduled','published','failed']`. Cards = posts grouped by `status`. Card body: content preview + platform Badge(s) + scheduled time.
- [ ] **Drop → transition rules** (each → a `useSocialPosts` mutation, all PATCH):
  - draft → approved = `approve(id)` (sets approved_at)
  - approved → scheduled = needs a time → open a small time popover, then `advance(id,'scheduled',scheduledAt)`
  - any → draft = `advance(id,'draft')` (pull back for edits)
  - **published / failed columns are drop-disabled** — those are scheduler-owned outcomes, not human-draggable.
- [ ] No new mutation surface — `approve`/`advance` already live in `social.ts` (C5). C7 is pure UI over the same API.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `one.ie/web/src/components/in/SocialKanban.tsx` — compose BoardView's drag; 5 status columns; drop handler → `approve`/`advance`; drop-disable published/failed ≤180 LOC
- [ ] `one.ie/web/src/pages/in/[groupId]/board.astro` — shell + island (skip if a board route already exists from index) ≤50 LOC
- [ ] `tests/e2e/social-kanban.test.ts` — render w/ mock posts in columns; simulate Draft→Approved drop → `approve` called; assert Published column rejects drops ≤150 LOC

**W3b:** *(empty)*

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] demo test exits 0 (drop → approve asserted; published drop-disabled)
- [ ] **Live check**: `GET /in/<group>/board` returns 200/302 on deploy URL (cache-busted)
- [ ] Reuse audit: imports BoardView/PeopleKanban drag (grep — no new drag lib added to package.json); transitions go through `useSocialPosts`
- [ ] **Plan outcome exits 0** (full command incl. scheduler test + kanban/calendar files) → justify-or-drop on anything unstarted
- [ ] UX delta observable — screenshot: card dragged Draft→Approved
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## C8 — CLI + MCP social verbs (Claude Code parity)  [tier: complex · batch: 3]

**Goal delta:** Everything the UI drag does is callable headless: `one social {list,draft,approve,reschedule,publish-now}` (CLI) + matching `@oneie/mcp` tools, so **Claude Code drives the same lifecycle over the same API** — no UI required.

**Deliverable:** social verbs in `packages/cli/` + social tools in `packages/mcp/`.

**UX delta:** From a Claude Code session (or terminal) you can `one social draft …`, `one social approve <id>`, `one social reschedule <id> "fri 9am"` — the same PATCH calls the calendar/kanban drags make.

**Cycle outcome:** `bun vitest run tests/e2e/social-cli.test.ts` — verbs map to the right API calls; `one social list` parses the posts response.

**Demo gate:**
```yaml
demo:
  command: "bun vitest run tests/e2e/social-cli.test.ts"
  asserts: "one social approve <id> issues PATCH {status:'scheduled'}; one social reschedule issues PATCH {scheduled_at}; one social list parses GET /api/social/posts"
  budget: "<2s · <120 LOC test"
```

### W1 — Recon  [Haiku · parallel]
1. **Existing-code**
   - [ ] `packages/cli/src/` — how an existing verb is registered (command parser, arg shape, how it calls the API + auth)
   - [ ] `packages/mcp/src/` — how an existing MCP tool is declared (the 12 verbs); the input-schema + handler pattern
   - [ ] `one.ie/web/src/pages/api/social/posts/[id].ts` (post-C2) — the PATCH contract the verbs target
2. **Primitive-inventory**
   - [ ] `packages/sdk/src/client.ts` — does the SDK already expose a typed fetch the CLI/MCP reuse for auth? (compose, don't re-auth)

### W2 — Decide  [Opus]
- [ ] **Compose-or-construct:** EXTEND `packages/cli` + `packages/mcp` with a `social` verb group + tools — verdict **extend** (both have an established verb/tool pattern; do not fork a new surface)
- [ ] Verb → API map (identical to the UI mutations, so behavior is uniform):
  - `one social list [--status]` → GET /api/social/posts
  - `one social draft <content> --platforms x,linkedin [--at <when>]` → POST /api/social/posts (source `cli`)
  - `one social approve <id>` → PATCH {status:'scheduled'} (or approved)
  - `one social reschedule <id> <when>` → PATCH {scheduled_at}
  - `one social publish-now <id>` → PATCH {scheduled_at: now} (lets the next scheduler tick pick it up — no separate publish path)
- [ ] MCP tools mirror the verbs 1:1 with JSON-schema inputs, so Claude Code lists them as callable tools.
- [ ] `<when>` parsing: accept ISO or natural ("fri 9am") via the date lib already in the CLI; reject ambiguous input rather than guess.
- [ ] Auth: reuse the SDK client's token handling; do not invent a new auth path.

### W3 — Edit  [Sonnet · parallel]
**W3a:**
- [ ] `packages/cli/src/` — add the `social` verb group (5 subcommands → API calls via SDK client)
- [ ] `packages/mcp/src/` — add 5 social tools mirroring the verbs (schema + handler)
- [ ] `tests/e2e/social-cli.test.ts` — each verb issues the expected method+path+body (msw); `list` parses a posts response; bad `<when>` errors cleanly ≤120 LOC

**W3b:** *(empty)*

### W4 — Verify  [Haiku×5]
- [ ] `bun run verify` green (incl. `cd packages && bun run build`) · `delta_tsc ≤ 0`
- [ ] demo test exits 0
- [ ] Reuse audit: verbs call the SDK client (grep — no hand-rolled fetch/auth); MCP tools follow the existing 12-verb declaration shape
- [ ] **Parity check:** CLI `approve`/`reschedule` hit the SAME PATCH endpoint the calendar/kanban drags use (one endpoint, three clients) — assert the path/body match the UI mutations
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

Report: `delta_tsc=±N delta_loc=±N new_files=N primitives_composed=N`

---

## See also

- `agents/src/cron.ts` — scheduler extended in C4
- `agents/src/agents/export-hubspot.ts` — the writethrough pattern C4 mirrors
- `agents/src/composio.ts` / `composio-toolkits.ts` — Composio client + toolkit map
- `one.ie/web/src/components/in/BoardView.tsx` / `PeopleKanban.tsx` — existing drag board C7 reuses
- `packages/cli/` + `packages/mcp/` — surfaces C8 extends so Claude Code drives the API
- `one.ie/agents/marketing/social-media-manager.md` — agent (human-in-loop checkpoints honored by the approve→publish flow)
- `plans/dev/composio.md` — BYO accounts, multi-tenant OAuth, white-label setup
- `plans/channels.md` — the /in inbox + D1 hot-table pattern (sibling reference)
- `react-big-calendar` + [shadcn Big Calendar template](https://www.shadcn.io/template/list-jonas-shadcn-ui-big-calendar) — calendar engine (C6)
- `plans/dictionary.md` · `plans/rubrics.md` — names + scoring (always)

---

## Pre-flight: Composio dashboard provisioning

Before C1 ships, confirm these toolkits are provisioned (auth-config IDs are optional — `connect.ts` resolves them dynamically):

```bash
# bun/node REPL with COMPOSIO_API_KEY set:
const { Composio } = await import('@composio/core')
const c = new Composio({ apiKey: process.env.COMPOSIO_API_KEY })
console.log((await c.authConfigs.list()).items.map(i => ({ slug: i.toolkit?.slug, id: i.id })))
```

Required: `TWITTER`, `LINKEDIN`, `INSTAGRAM`, `TIKTOK`, `FACEBOOK`. Provision any missing in the Composio dashboard.

**Composio coverage (verified) + account-type constraints:**

| Platform | Posting via Composio | Constraint to surface in connect UX |
|---|---|---|
| Twitter/X | tweets + media | — |
| LinkedIn | post content | — |
| TikTok | photos + video upload/publish | — |
| Instagram | photo + carousel + scheduling | **Business/Creator accounts only** (not personal) |
| Facebook | Page posts | **Pages only** (not personal profiles) |

The accounts API tags each connection's type; `social-validate.ts` blocks an IG/FB target on the wrong account type with a clear message.

## Architecture notes (load-bearing)

- **One endpoint, three clients.** `PATCH /api/social/posts/:id` is the single mutation surface. The calendar drag (C6 `onEventDrop` → reschedule), the kanban drag (C7 drop → approve/advance), and Claude Code/CLI/MCP (C8) all hit it through the same `useSocialPosts`/SDK calls. No client gets its own bespoke path — behavior is uniform whether a human drags or Claude Code calls.
- **D1 sharing is the pivot.** C2 W1 must confirm the web app and agents worker bind the same D1 database. If yes (expected — the agents worker "owns D1"), the migration lives in `agents/migrations/` and C4's scheduler reads `social_posts` directly. If no, the escape fires: scheduler talks to the web API over HTTP and the migration moves to the web worker.
- **Publishing reuses the writethrough.** Don't invent a queue. `export-hubspot.ts` already encodes "queue → POST → mark/warn"; C4 is that loop with Composio as the target. This keeps the locked closed-loop rule intact (every publish ends in mark or warn).
- **Approval is the only human gate.** Both on-demand and weekly-cron drafts land as `status='draft'`. A human Approve (PATCH → `scheduled`) is what authorizes the scheduler to publish. "Fully autonomous" was explicitly not chosen.
- **Media path:** upload → R2 → public URL handed to the Composio tool. Video adds per-platform duration validation in `social-validate.ts`; if a platform's Composio tool needs file/base64 instead of URL, that's a C2 W2 adjustment, not a new cycle.
