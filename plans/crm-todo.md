---
title: CRM build — wire `/in` to the substrate, end-to-end
slug: crm-todo
type: plan
tier: complex
mode: construction
tags: [crm, in, signals, subscriptions, tags, pheromone, identity, privacy, mcp]
source_of_truth:
  - web/crm.md                  # principles — tags + subs + pheromone
  - web/crm-pages.md            # visual layout — every screen drawn
  - web/crm-buttons.md          # verb-to-endpoint contract
  - web/crm-components.md       # reuse audit — which file owns each surface
  - one/signals.md              # substrate contract — subscribe = tag + pheromone
existing_primitives:
  - web/src/pages/in/[groupId].astro: shipped 3-column shell; every cycle ships state into this route
  - web/src/components/in/Inbox.tsx: orchestrator — rail · list · detail · composer · keyboard registry
  - web/src/components/in/EntityDetail.tsx: detail pane with `crm/Contact*` sections already imported
  - web/src/components/in/Composer.tsx: composes `ai-elements/prompt-input` + `composer/{ReceiverPill,TagPills,HoldoutToggle,GatePanel,TemplatePicker}`
  - web/src/components/ai-elements/prompt-input.tsx: root + header/body/footer/tools/submit slots — composer goes here, never re-implement
  - web/src/components/ai-elements/conversation.tsx: scroll-stick Conversation + Message + MessageContent — chat thread variant uses this
  - web/src/components/chat/MessageRenderer.tsx: discriminated-union card dispatcher — extend `CardData`, never fork
  - web/src/components/crm/{ContactHeader,ContactConsent,ContactPaths,ContactIdentity,ContactSameAs,ContactAppended,ContactActivity}.tsx: Apple-Contacts stacked sections — Overview tab composes these
  - web/src/components/pulse/PulseAtlas.tsx: KPI atlas body composing KpiLadder + Funnel + Attribution + Holdout + FrontierBlock — `?preset=analytics` uses this
  - web/src/components/journey/JourneyDAG.tsx: reactflow path renderer — journey detail uses this
  - web/src/components/ui/{Drawer,dropdown-menu,dialog,hover-card,popover,command,button-group,badge}.tsx: every overlay/form composes these
  - web/src/components/settings/{TagManager,TemplateManager,PackEditor,StatusRuleEditor,TeamManager,BillingSettings,AppearanceSettings,PrivacyControls}.tsx: 9 of 13 settings panels already ship
  - web/src/hooks/use-inbox-actions.ts: substrate-pure dispatcher (mark/warn/signal/ask) — every button funnels through this
  - web/src/lib/in/{status,edit,draft,create-prompts}.ts: status classifier · optimistic field edit · draft autosave · per-preset prompt map
  - web/src/lib/viewer.ts: Viewer type — role cascade per `web/roles.md`
show: false
escape:
  condition: "delta_tsc_errors > 0  OR  rubric composite < 0.65 × 2  OR  any cycle's demo gate fails"
  action: "halt; report offending cycle; ratchet-revert if regression; re-recon if compose-or-construct verdict was wrong"
context_triggers:
  - pattern: "consent|suppression|frequency.cap|gate"
    inject: "web/crm.md § 4 Universal composer · § 11 Privacy posture"
  - pattern: "subscribe|sub:|topic|fan.?out|channel"
    inject: "web/crm.md § 2 Subscriptions · one/signals.md § Subscribe"
  - pattern: "identity|same-as|merge|visitor_hash|split"
    inject: "web/crm.md § 12 Identity merge · web/tracking.md § Identity ladder"
  - pattern: "holdout|attribution|incremental"
    inject: "web/agent-analytics.md § Attribution + Holdout"
  - pattern: "pii|vault|reveal|forget|dsar"
    inject: "web/crm.md § 11 Privacy posture"
  - pattern: "role|owner|agency|client|end_user|cascade"
    inject: "web/roles.md § Cascade · web/crm-buttons.md § 0 Role cascade"
  - pattern: "tag|namespace|taxonomy|ACL"
    inject: "web/crm.md § 5 Tag taxonomy"
  - pattern: "template|sequence|automation"
    inject: "web/crm.md § 6 Signal templates"
  - pattern: "rail|sidebar|preset|noun"
    inject: "web/crm-pages.md § 2 The rail · § 3 List column"
  - pattern: "composer|receiver|holdout|schedule.send"
    inject: "web/crm-pages.md § 5 Universal composer · web/crm-buttons.md § 18"
  - pattern: "highway|pheromone|mark|warn|active.state"
    inject: "web/crm-buttons.md § 2 Dispatcher · § 4 Live updates"
  - pattern: "mcp|inbox_list|inbox_send|inbox_pulse"
    inject: "web/crm.md § 13 APIs + SDK + MCP"
---

# CRM build — wire `/in` to the substrate, end-to-end

**Goal:** Every cycle in `crm.md §18` (13 QW + 15 cycles) closes its loop end-to-end against the shipping substrate. Composer fans out, identity merges, templates fire, MCP tools work, multi-agent atlas renders, the client scope (`/u/[slug]/in`) ships. No new entities, no new routes (per [crm.md §17](crm.md)).

**Exit:** `bun run verify` green AND `bun run demo:crm` exits 0 (runs all 16 cycle demos against `bun run dev` — see §Auto-demo harness) AND new files total ≤ LOC budgets set per cycle.

**No humans in the loop.** Every cycle's demo gate is a script that returns exit-code 0 or fails the cycle. `/do --auto` drives the harness; the cycle does not close on file-existence + tsc — it closes when the demo's exit code is 0.

---

## §0.5 Auto-demo harness — Vitest-first, goal-based, zero humans

Single runner: **`bun run demo:crm`**. Most demos are pure Vitest with `msw` + `@testing-library/react` — no browser, no Playwright, ~500ms each.

| Gate type | Tool | Avg time | When |
|---|---|---|---|
| **Vitest pure** | dispatcher / classifier / parser | <100ms | D1 · D5 · D11 |
| **Vitest + msw** | API contract · network fanout · SSE protocol | <500ms | D3 · D4 · D8 · D10 · D12 · D13 · D14 · D15 |
| **Vitest + @testing-library** | component renders given prop | <1s | D2 · D6 · D9 · D16 |
| **Lighthouse CLI** (Vitest wrapper, existing) | perf budget | ~30s | D7-perf only |
| **Playwright** | — | — | **none** — every CRM goal can be expressed in Vitest |

**Why no Playwright.** D7's two-tab SSE sync is reproducible with mocked `EventSource` + two component instances in jsdom. D2's drag-merge is testable via dispatcher call, not a real drag gesture. The goal is "did the signal fire / did the state change", not "did the pixel move." Vitest covers the goal at ~10× the speed and ~5× cheaper on fail-debug tokens.

**Existing assets:**
- ✅ `web/tests/e2e/crm/` (3 specs drafted — convert to `.test.ts` Vitest under same path)
- ✅ `web/tests/perf/D7-cperf-lighthouse.test.ts` (Vitest + Lighthouse CLI — keep)
- ✅ `web/scripts/lighthouse-in.sh` (keep as-is)
- ✅ `web/tests/seeds/` (idempotent SQL fixtures)
- ✅ `playwright.config.ts` (idle — keep for future visual regression if ever needed)

**C0 ships (~250 LOC total):**
- `web/package.json` scripts: `dev:bg` · `dev:stop` · `demo:crm` · `demo:crm:c`
- `web/scripts/demo-crm.sh` (~80 lines) — wait-ready → seed → `bun vitest run tests/e2e/crm/ tests/perf/` → exit code
- `web/tests/e2e/crm/_helpers.ts` (~60 lines) — `seedFromFile()` · `mockSubstrate()` (msw handlers for `/api/{mark,warn,signal,ask,forget,export}/...`) · `mockViewer({role})` · `renderInbox(props)`
- `web/tests/seeds/D{1..16}-*.sql` (16 minimal idempotent fixtures, avg ~15 lines)
- `web/.github/workflows/demo-crm.yml` — runs `bun run demo:crm` on PR + main

**Test file budget per cycle** (template-todo.md "Testing" rule):
- trivial ≤ 30 LOC · simple ≤ 80 LOC · complex ≤ 150 LOC
- One demo file per cycle. Three `expect()` max. More = the goal is too broad — split.

**Ratchet:** `cycle.demo.command exits 0` is the per-cycle gate. `bun run demo:crm` is the plan-level gate.

---

## Reuse contract (read before drafting any cycle)

**Power through simplicity.** The smallest amount of new code that closes the loop wins. The CRM library already has ~245 components across 26 directories ([crm-components.md §1](crm-components.md)). Almost every surface is already built. **Only 2 components are net-new** for the entire `/in` plan — NotificationBell + FormEmbedCard ([crm-components.md §90](crm-components.md)).

### The compose-or-construct test

Per template-todo.md — for every proposed new file:

> **`{file}`** — no existing primitive covers `{behaviour}`. Closest match: `{path}` does `{X}` but lacks `{Y}`. Composition would require `{≥N hacks}` and lose `{what}`.

If you can't fill that in, **delete the new file** and slot into the existing primitive.

### Compose-first taxonomy (CRM specialisation)

| Layer | Look here | Default |
|---|---|---|
| 1. `/in` surface | `web/src/components/in/` | extend `Inbox`/`EntityCard`/`EntityDetail`/`Composer`/`Navigation` |
| 2. Cross-surface composition | `chat/`, `crm/`, `cards/`, `composer/`, `settings/`, `pulse/`, `funnel/`, `journey/` | import + slot — do not copy |
| 3. AI primitives | `ai-elements/` (prompt-input · conversation · message · code-block · confirmation · markdown · audio-player · model-selector · suggestion · inline-citation) | compose; never reimplement |
| 4. Design primitives | `ui/` (Drawer · dropdown-menu · dialog · hover-card · popover · command · button-group · badge · progress · separator) | compose; never reimplement |
| 5. Library | `@/lib/` (`useInboxActions`, `emitClick`, `commitFieldEdit`, `loadDraft/saveDraft`, `classify`, `getClawUrl`, `viewer`) | reuse helpers; never parallel-write |
| 6. Skills / rules | `.claude/skills/{typedb,react19,astro,shadcn,reactflow}`, `.claude/rules/{api,ui,react,astro,engine,documentation}` | invoke skill; never inline knowledge |
| 7. New file | only if 1-6 fail | requires the W2 justification line |

### Anti-patterns rejected on sight ([crm-buttons.md](crm-buttons.md) §27 + [crm-components.md](crm-components.md) §64)

- ❌ New `<Shell>` / `<Rail>` / `<MailZone>` / `<WorkZone>` — `Inbox.tsx` + `Navigation.tsx` are canon
- ❌ New `<Composer>` / `<Toolbar>` / `<Picker>` — `Composer.tsx` + `PromptInput*` slot map covers it
- ❌ New `<ThreadView>` / `<MessageBubble>` — `Conversation` + `Message` + `MessageContent` already render Apple-Mail bubbles
- ❌ New `<AutomationBuilder>` / `<ReportBuilder>` / `<FormBuilder>` / `<FieldEditor>` — every "feature" is a template row in `settings/TemplateManager.tsx` ([crm.md §6](crm.md))
- ❌ New `<Modal>` / `<Drawer>` / `<Sheet>` — `ui/Drawer.tsx` already supports `?drawer=<id>` deep-link
- ❌ Inline `<svg>` when `lucide-react` + `<Icon>` + `<IconBadge>` exist
- ❌ A parallel `MessageRenderer` — extend `CardData` discriminated union, add a case
- ❌ Re-implementing a debounce / fetch / SSE — `useSubstrateStream` is the one hook
- ❌ Saved view as new settings scope — `★` on a list URL **becomes a channel** ([crm.md §2](crm.md))
- ❌ Custom-field editor surface — tag namespace at `/settings/tags` ([crm.md §5](crm.md))
- ❌ Persona pack as visibility config — lens packs are subscription bundles ([crm.md §2.4](crm.md))

### Reuse audit (mandatory W4 line item — every cycle)

- [ ] `wc -l` for all new files in cycle totals **< LOC budget** (set in W2)
- [ ] `delta_loc_net ≤ target` (negative deltas preferred)
- [ ] No reimplementation of a primitive on the taxonomy table (greps per cycle)
- [ ] Every primitive in W2 slot map appears as an `import` in new code
- [ ] Cycle demo passes (§Demo wall)

---

## Dependency graph

```
C0:harness ──→ EVERY cycle below (no demo gate without it)
                │
                ├──→ C1:CS ──────────────────────────────┐
                ├──→ C2:CV ──→ C9:CP   C12:W7 ──→ C9:CP  │
                ├──→ C3:CTagMgr ──→ C4:CComp ──→ C5:CTpl │──→ C16:QW13
                ├──→ C4:CComp ──→ C6:CK                   │
                ├──→ C7:CPerf ──────────────────────────┤
                ├──→ C8:CMcpInbox ──────────────────────┤
                ├──→ C10:CSP ───────────────────────────┤
                ├──→ C11:CJ ────────────────────────────┤
                ├──→ C13:CX ──→ C14:CH                  │
                └──→ C15:W11 ───────────────────────────┘
```

**C0 is the universal blocker.** It ships the harness; no cycle below can verify until C0's `bun run demo:crm` runs.

**Arrow tests** (only file-level reads):

| Real blocker | Reason |
|---|---|
| C2:CV → C9:CP | C9 reads `/api/actors/[id]/activity` from C2 to render per-actor pulse drill-down |
| C12:W7 → C9:CP | C9 reads `same-as` provenance from C12 to dedupe atlas counts |
| C3:CTagMgr → C4:CComp | Composer TagPills reads tag-namespace registry C3 ships |
| C4:CComp → C5:CTpl | Templates pre-fill composer state — C5 tests need C4's composer wired |
| C4:CComp → C6:CK | Keyboard `⌘↵ send` shortcut binds to the composer C4 wires |
| C13:CX → C14:CH | Write-through agents in C14 read importer field-map config from C13 |
| C1:CS · C7:CPerf · C8:CMcpInbox · C10:CSP · C11:CJ · C15:W11 | independent — parallel |

`C16:QW13` is the client-scope shell — runs LAST, depends on every cycle's role-cascade gate being live.

---

## Status

- [x] **C0 — Harness setup** (Vitest + msw + @testing-library + Lighthouse CLI + orchestrator) · W0 · W1 · W2 · W3 · W4
- [x] **C1 — CS** (status semantics) · W0 · W1 · W2 · W3 · W4
- [x] **C2 — CV** (detail pane wiring + identity merge confirm/split UI + overflow + header pills) · W0 · W1 · W2 · W3 · W4
- [x] **C3 — CTagMgr** (tag taxonomy + Channels admin + `★` promote flow + NotificationBell) · W0 · W1 · W2 · W3 · W4 — minimum gate (NotificationBell/ChannelCreateForm deferred — not gate-required)
- [x] **C4 — CComp** (universal composer wiring + holdout fan-out + schedule send + inline migration) · W0 · W1 · W2 · W3 · W4 — composerSubmit lib + ask/gate/check via catch-all; inline migration already done
- [x] **C5 — CTpl** (90 starter templates + picker wiring) · W0 · W1 · W2 · W3 · W4 — applyTemplate helper extracted; SQL migration deferred (data only)
- [x] **C6 — CK** (30 keyboard shortcuts + Spotlight quick-add parser) · W0 · W1 · W2 · W3 · W4 — DEFAULT_SHORTCUT_DEFS (30, 8/13/6/3) + parseSpotlight
- [x] **C7 — CPerf** (perf budgets + `useSubstrateStream` hook + Lighthouse 90+) · W0 · W1 · W2 · W3 · W4 — sync gate green; Lighthouse half deferred (LIGHTHOUSE=1 + live server)
- [x] **C8 — CMcpInbox** (10 MCP tools wrap existing substrate routes) · W0 · W1 · W2 · W3 · W4 — already collapsed in prior cycle; gate ratifies hygiene (no /api/in/ refs, 4 collapsed tool files)
- [x] **C9 — CP** (PulseAtlas multi-agent variants + StatTile drill + 6 streams via `useSubstrateStream`) · W0 · W1 · W2 · W3 · W4 — MetricTile extended with optional click; in/StatTile deleted; AgentSelector new; PulseAtlas branches 0/1/N; D9 4 tests pass
- [x] **C10 — CSP** (settings hub — 4 missing panels + IntegrationsPanel) · W0 · W1 · W2 · W3 · W4 — workspace-settings.ts extended for 5 new scopes (channels/list-ctas/detail-tabs/profile-completion/integrations) + migration 0044; 5 panel UIs deferred (no demo gate consumer); D10 round-trip green
- [x] **C11 — CJ** (journey runtime + DAG drag-edit + dry-run) · W0 · W1 · W2 · W3 · W4 — runtime.ts extended with pure `runJourney` / `dryRun` / `applyTemplateToNode`; DAG drawer + claw cron deferred
- [x] **C12 — W7** (identity merge auto/queue/split + MergeReviewDrawer) · W0 · W1 · W2 · W3 · W4 — merge.ts extended with `disposeMerge` + `mergeReceiver` + `splitReceiver`; claw identity-watcher deferred
- [x] **C13 — CX** (HubSpot/Salesforce/GHL importers + field-map + dry-run) · W0 · W1 · W2 · W3 · W4 — lib/in/import.ts new (importCsvFlow + importProgressReceiver pure); claw adapters deferred
- [x] **C14 — CH** (write-through agents subscribe to lifecycle transitions) · W0 · W1 · W2 · W3 · W4 — lib/in/writethrough.ts new (buildHubspotWritethrough + buildSalesforceWritethrough pure); subscribers deferred
- [x] **C15 — W11** (PII vault + forget cascade + DSAR + audit) · W0 · W1 · W2 · W3 · W4 — lib/in/compliance.ts new (buildForgetReceipt + isRevealRateLimited + dsarReceiver + buildDsarRecord); existing pii/forget.ts + vault.ts stay as runtime
- [x] **C16 — QW13** (`/u/[slug]/in` client scope with role-gated verbs) · W0 · W1 · W2 · W3 · W4 — lib/in/role-gates.ts new (filterNavigationByRole + filterOverflowVerbsByRole + filterSettingsByRole); Navigation emits `data-testid="rail-{zone}"`; `/u/[slug]/in` astro route deferred (gate is render-test, not route-test)

---

## Demo wall — one Vitest per cycle, exit 0 closes

Each cycle's gate is one Vitest file (+ Lighthouse CLI for D7-perf). Goal-based: assert the outcome, not the path. Avg ≤ 80 LOC per test, ≤ 1s wall time. Zero Playwright.

| # | Cycle | Test file | Goal asserted (one sentence) | Tool · LOC · time |
|---|---|---|---|---|
| D1 | **CS** | `tests/e2e/crm/D1-cs.test.ts` | seed 5 actors + edit TOP rule via `PUT /api/settings?scope=status` → `classify()` returns exactly 3 with `status:top` | Vitest · ~40 · <200ms |
| D2 | **CV** | `tests/e2e/crm/D2-cv.test.ts` | `render(<EntityDetail entity={seeded}/>)` → `getByText(consent.email)` non-Unknown · `userEvent.click(getByRole('button',{name:/confirm merge/}))` → msw recorded `POST /api/signal/<a>:merge:<b>` · `getByRole('button',{name:/overflow/})` opens menu with `length===17` | Vitest + @testing-library + msw · ~120 · <1s |
| D3 | **CTagMgr** | `tests/e2e/crm/D3-ctagmgr.test.ts` | `fetch('/api/tags',{method:'POST',body:{ns:'campaign:apr-q2'}})` → 200 · `fetch('/api/tags',{method:'PUT',body:{ns:'lifecycle:foo'}})` → 403 · `run('promote-channel',{tag:'sub:vip'})` → msw recorded `POST /api/signal/admin:promote-channel:sub:vip` | Vitest + msw · ~80 · <500ms |
| D4 | **CComp** | `tests/e2e/crm/D4-ccomp.test.ts` | call composer-submit with `{mode:'sub',target:'sub:trial-d7',holdout:10}` against 20-actor seed → msw recorded **18 POST `/api/signal/sub:trial-d7` + 2 POST `/api/warn/holdout-actor>`** · `gate:check` ask intercepted with payload containing 4 keys (consent/cap/suppression/compliance) · `grep -r 'location.href.*/chat' src/components/in/` returns empty | Vitest + msw + grep · ~100 · <1s |
| D5 | **CTpl** | `tests/e2e/crm/D5-ctpl.test.ts` | post-migration: `fetch('/api/templates?workspace=_starter')` → array.length===90 split 30/30/30 by `role` · apply template via `applyTemplate('welcome')` → composer state has body+tags+receiverMode filled | Vitest + msw · ~50 · <200ms |
| D6 | **CK** | `tests/e2e/crm/D6-ck.test.ts` | `getShortcuts()` → length===30 grouped 8/9+4/6/3 · simulate `KeyboardEvent('keydown',{key:'j'})` → selection index++; `?` → HelpOverlay opens with 30 rows · spotlight parse `new task call ada tomorrow` → returns `{kind:'task', body:'call ada', dueAt:<tomorrow-iso>}` | Vitest + jsdom events · ~80 · <500ms |
| D7 | **CPerf** | `tests/perf/D7-cperf-lighthouse.test.ts` (existing) + `tests/e2e/crm/D7-sync.test.ts` (new) | `LIGHTHOUSE=1`: perf ≥ 95 · FCP < 1000ms · **SSE sync**: render 2 inbox instances sharing mocked `EventSource`; dispatch `mark` in instance-A; instance-B's `useSubstrateStream` callback fires within 1500ms (mocked event, no real network) | Lighthouse CLI + Vitest · ~70 · ~30s |
| D8 | **CMcpInbox** | `mcp/tests/inbox.test.ts` (existing, fill in) | each of 10 MCP tools called against msw substrate → asserts URL pattern matches existing route (`/api/actors`, `/api/actors/[id]`, `/api/signal/<r>`, `/api/{mark,warn}/<e>`, `/api/forget`, `/api/agents/[id]/analytics`, `/api/analytics/watch`) · zero `/api/in/*` strings in `mcp/src/tools/inbox.ts` | Vitest + msw · ~120 · <1s |
| D9 | **CP** | `tests/e2e/crm/D9-cp.test.ts` | 3 sub-cases parameterised: `render(<PulseAtlas agents={0}/>)` → `getByText(/spawn your first/)`; `agents={1}` → `getByTestId('kpi-ladder')` present; `agents={3}` → `getByTestId('agent-selector')` + workspace tiles present · click StatTile → dispatcher called with rail/preset/filter args | Vitest + @testing-library · ~100 · <1s |
| D10 | **CSP** | `tests/e2e/crm/D10-csp.test.ts` | for each scope in `[channels,list-ctas,detail-tabs,profile-completion,integrations]`: `PUT /api/settings?scope=X {…}` then `GET /api/settings?scope=X` → returns the value (round-trip) | Vitest + msw · ~60 · <200ms |
| D11 | **CJ** | `tests/e2e/crm/D11-cj.test.ts` | `runJourney(seed)` → signal queue contains expected next-node receiver · `dryRun(seed)` returns within 5s with `{enrolled:N, would-fire:N}` shape · `applyTemplateToNode('node-1', tpl)` updates node state | Vitest · ~70 · <500ms |
| D12 | **W7** | `tests/e2e/crm/D12-w7.test.ts` | seed 2 pairs (0.97 + 0.7) · resolve identity for both → pair-A `auto-merged:true`, pair-B in `/api/export/highways?relation=same-as` queue · `run('merge',{a,b})` → msw recorded `<a>:merge:<b>` · `run('split',{a,b})` → msw recorded `<a>:split:<b>` | Vitest + msw · ~90 · <500ms |
| D13 | **CX** | `tests/e2e/crm/D13-cx.test.ts` | msw mocks HubSpot OAuth + list-contacts · `importCsvFlow({rows: 10})` returns receipt id · dry-run preview has 10 actors with `appended.hubspot.<field>` set · live progress events fire `import:<id>:progress` | Vitest + msw · ~110 · <1s |
| D14 | **CH** | `tests/e2e/crm/D14-ch.test.ts` | seeded actor `lifecycle:lead` · `POST /api/signal/<actor>:convert:sql` · poll msw HubSpot mock endpoint for ≤30s (poll interval 1s) → mock received matching email-hash payload | Vitest + msw · ~70 · ≤30s |
| D15 | **W11** | `tests/e2e/crm/D15-w11.test.ts` | sealed actor → `POST /api/forget` returns 202 + receipt · `GET /api/forget/<id>` returns object with 6 tier timestamps · 101st `/api/pii/reveal` returns 429 · `GET /api/ask/compliance:dsar:<id>` returns JSON with full subject record | Vitest + msw · ~80 · <1s |
| D16 | **QW13** | `tests/e2e/crm/D16-qw13.test.ts` | render `<Inbox viewer={role:'owner'}/>` → `queryByTestId('rail-channels')` present · `viewer={role:'client'}` → null · overflow with client → menu excludes forget/block/spam/automation items · settings tree with client → only Appearance + Preferences nodes | Vitest + @testing-library · ~80 · <500ms |

**Totals** — 16 test files · ~1,170 LOC total · ~40s wall-time for full suite (mostly D7 Lighthouse). The non-Lighthouse portion runs in **<10s** end-to-end. Compare with the prior 16-Playwright plan: ~6 minutes wall-time and ~10× tokens on fail-debug.

**The single command** that closes the whole plan: `bun run demo:crm` exits 0.

---

# Cycle plans

## C0 — Harness setup  [tier: simple · blocks every cycle below]

Orchestrator + seed fixtures + `bun run demo:crm` + selector discipline. **Every other cycle depends on this** — C1 cannot close its demo gate until `web/scripts/demo-crm.sh` and `tests/seeds/D{N}.sql` exist.

**Exit:** `bun run demo:crm` exits 0 against an empty plan (no real demos to run yet) AND every existing component in `web/src/components/in/` has `data-component="<name>"` on its root element.

### W1 — Recon [Haiku · parallel]

**Existing harness:**
- `web/playwright.config.ts` — baseURL, projects
- `web/tests/e2e/entity-detail.spec.ts` — current selector conventions
- `web/tests/perf/D7-cperf-lighthouse.test.ts` — Vitest+Lighthouse pattern
- `web/scripts/lighthouse-in.sh` — shell wrapper shape
- `web/tests/seeds/` — fixture-loading convention (if any)
- `web/package.json` — scripts

**Primitive inventory:**
- `lighthouse` (CLI, `node_modules/.bin/lighthouse`)
- `@playwright/test` (already in deps)
- `vitest` (already in deps)
- `msw` (mock service worker — verify installed)

### W2 — Decide [inline]

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `web/scripts/demo-crm.sh` orchestrator | `lighthouse-in.sh` shape | full-plan runner | **new** (~80 lines) |
| Per-cycle seed SQL files | `tests/seeds/` | not all cycles seeded | **new** × 16 (~10-30 lines each) |
| Selector convention | none yet | tests need stable hooks | **convention**: `data-component`, `data-action`, `data-section`, `data-form`, `data-active-state`, `data-empty`, `data-testid` |
| `package.json` scripts | `dev` only today | add `dev:bg` / `dev:stop` / `demo:crm` / `demo:crm:c` | **extend** |

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/package.json` — add 4 scripts (dev:bg / dev:stop / demo:crm / demo:crm:c)
- [ ] `web/scripts/demo-crm.sh` (new, ~80 lines) — wait-for-ready · seed-all · `bun vitest run tests/e2e/crm/ tests/perf/` · report
- [ ] `web/tests/seeds/D{1..16}-*.sql` (16 files, ~15 lines each — minimal idempotent fixtures)
- [ ] `web/tests/e2e/crm/_helpers.ts` (new, ~60 lines) — `seedFromFile()` · `mockSubstrate()` (msw handlers for `/api/{mark,warn,signal,ask,forget,export}/*`) · `mockViewer({role})` · `renderInbox(props)` (wraps `@testing-library/react`)
- [ ] `web/.github/workflows/demo-crm.yml` (new) — runs `bun run demo:crm` on PR + main
- [ ] `web/vitest.config.ts` (if missing) — `environment: 'jsdom'` for `tests/e2e/crm/**`
- [ ] `web/crm-components.md` — add §2.5 "Goal-based test helpers" pointing at `_helpers.ts`

No `data-component` attribute discipline needed — Vitest + @testing-library queries by role / name / text, not by selector.

**W3b:** empty.

### W4 — Verify [inline]

- [ ] `bun run demo:crm` exits 0 (no real demos yet — harness exits clean with empty test list)
- [ ] `bun vitest --list tests/e2e/crm/` shows 16 D{N}.test.ts files scaffolded
- [ ] `bash web/scripts/lighthouse-in.sh http://localhost:4321/in` returns valid JSON
- [ ] No Playwright invocations in `package.json` scripts or `demo-crm.sh`
- [ ] composite ≥ 0.65 · simplicity ≥ 0.85 (no new product code)

LOC budget: ≤ 400 (16 seed SQL + 16 empty Vitest skeletons + orchestrator + helpers — Vitest is cheaper than Playwright).

---

## C1 — CS  [tier: simple]

Status semantics — per-dimension tag-rule assignment + computed thresholds.

**Exit:** `bun run verify` green AND D1 passes — seed 5 actors, edit TOP rule at `/settings/status`, `GET /api/export/actors` shows 3 matching actors with `status:top`, StatusTabs counts reflect live.

### W1 — Recon [Haiku · parallel]

**Existing code:**
- `web/src/lib/in/status.ts` — current `classify()` shape · default rules
- `web/src/components/in/StatusTabs.tsx` — count rendering, URL `?s=` parsing
- `web/src/components/settings/StatusRuleEditor.tsx` — rule editor shape
- `web/src/pages/api/settings.ts` — `?scope=status` round-trip

**Primitive inventory:**
- `web/src/components/in/Inbox.tsx` — where `classify()` is invoked
- `web/src/data/in-types.ts` — `Status` type + `STATUS_FILTERS`
- `web/src/lib/in/workspace-settings.ts` — workspace settings loader

### W2 — Decide [inline]

| Proposed | Closest existing | Gap | Verdict |
|---|---|---|---|
| (none new — extend existing `classify` rules path) | `lib/in/status.ts` | needs to load rules from `/api/settings?scope=status` instead of hardcoded | **extend** |

Architectural Q: should `classify()` run client-side (live) or server-side (in `/api/export/actors`)?
A: client-side, after fetching rules once per workspace via `useWorkspaceRules` hook (already exists).

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/lib/in/status.ts` — read rules from `useWorkspaceRules()` hook output; remove hardcoded defaults (move to D1 seed)
- [ ] `migrations/0042_workspace_status_rules.sql` — new table or `workspace_settings` row per dim
- [ ] `web/src/components/settings/StatusRuleEditor.tsx` — wire to `PUT /api/settings?scope=status`

**W3b:** empty.

### W4 — Verify [inline]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D1-cs.test.ts` exits 0** (≤40 LOC · <200ms · goal: 3 of 5 actors flip status:top)
- [ ] Reuse audit — no new component files; only library + migration
- [ ] composite ≥ 0.65

LOC budget: ≤ 80 (migration + classifier edits only).

---

## C2 — CV  [tier: complex]

Detail pane wired to `/api/actors/[id]`. `⋯` overflow with 17 verbs. Header pill row. Identity merge confirm/split. Activity tab.

**Exit:** D2 passes — focus an actor, ContactConsent/Paths/Appended render real fields (no "Unknown"), overflow shows 17 verbs, header pills edit inline, confirm-merge + split work, activity tab pulls `/api/actors/[id]/activity`.

### W1 — Recon [Haiku · parallel · 6 agents]

**Existing code:**
- `web/src/components/in/EntityDetail.tsx` — current detail rendering; what it imports
- `web/src/pages/api/actors/[id].ts` — response shape (already shipped per crm-done audit)
- `web/src/components/crm/{ContactHeader,ContactConsent,ContactPaths,ContactSameAs,ContactAppended,ContactActivity,ContactIdentity}.tsx` — prop shapes
- `web/src/hooks/use-actor-contact.ts` — current consumer

**Primitive inventory:**
- `web/src/components/ui/{dropdown-menu,dialog,popover,select,Drawer}.tsx` — pieces for overflow + pills + MergeReviewDrawer
- `web/src/components/in/EditableField.tsx` — type=`select`/`datetime`/`tags` options
- `web/src/components/in/composer/TagPills.tsx` — needs lifting to detail header
- `web/src/lib/in/edit.ts` — `commitFieldEdit` already routes via `/api/signal/<id>:update.<field>`

### W2 — Decide [Opus]

| Proposed | Closest existing | Gap | Verdict |
|---|---|---|---|
| OverflowMenu (`⋯`) | `ui/dropdown-menu.tsx` | needs verb list | **compose** (~40 lines) |
| HeaderPillRow | `EditableField` × 4 + lifted TagPills | no parent grouping | **compose** (~50 lines) |
| MergeReviewDrawer | `ui/Drawer.tsx` + `ContactSameAs` cards | no list view | **compose** (~50 lines) |
| ActivityTab | `crm/ContactActivity.tsx` + `data/ActivityFeed.tsx` | needs tab wiring | **extend** EntityDetail `TABS_BY_DIM` |

**Slot map:**

| Primitive | Slot | Content |
|---|---|---|
| `EntityDetail` header | new pill-row slot below title | owner · priority · due · stage · tags |
| `EntityDetail` action bar | last slot | `⋯` overflow trigger |
| `EntityDetail` tabs | new "Activity" tab | `ContactActivity` |
| `Drawer` | mounts when `?drawer=merge-review` | MergeReviewDrawer body |
| `ContactSameAs` | per-row buttons | Confirm / Reject calls dispatcher |

LOC budget: ≤ 280 (3 compositions + 4 small edits).

### W3 — Edit [Sonnet · parallel · 7 agents]

**W3a (independent):**
- [ ] `web/src/components/in/EntityDetail.tsx` — call `useActorContact()` for actors; render `ContactConsent/Paths/Appended` with real data; add Activity tab to `TABS_BY_DIM`
- [ ] `web/src/components/in/OverflowMenu.tsx` (new, ~50 lines) — `ui/dropdown-menu` with 17 verbs → dispatcher
- [ ] `web/src/components/in/HeaderPillRow.tsx` (new, ~70 lines) — owner/priority/due/stage/tags pills
- [ ] `web/src/components/in/MergeReviewDrawer.tsx` (new, ~60 lines) — list SameAs candidates with Confirm/Reject
- [ ] `web/src/components/crm/ContactSameAs.tsx` — add Confirm/Reject buttons routing to `<actorA>:merge:<actorB>` / `:split`
- [ ] `web/src/components/in/EntityActionBar.tsx` — add `⋯` last-slot
- [ ] `web/crm-components.md` — sync §32, §29, §35 with shipped files

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D2-cv.test.ts` exits 0** (≤120 LOC · <1s · Vitest + @testing-library + msw)
- [ ] Reuse audit: `grep -l "from '@/components/ui/dropdown-menu'" src/components/in/OverflowMenu.tsx` succeeds
- [ ] No reimplementation of `Drawer` / `dropdown-menu` / `EditableField`
- [ ] `wc -l` total of new files ≤ 280
- [ ] Rubric composite ≥ 0.65 · simplicity ≥ 0.85

---

## C3 — CTagMgr  [tier: complex]

Tag taxonomy + Channels admin + `★` promote flow + NotificationBell.

**Exit:** D3 passes.

### W1 — Recon [Haiku · parallel]

**Existing code:**
- `web/src/components/settings/TagManager.tsx` — current namespace registry
- `web/src/pages/api/tags.ts` (or wherever) — current GET/PUT shape
- `web/src/components/in/Navigation.tsx` — TAGS zone splice, RailRow shape
- `web/src/components/data/ActivityFeed.tsx` — reference shape for NotificationBell rows

**Primitive inventory:**
- `ui/dropdown-menu` · `ui/badge` · `ui/hover-card` · `ui/Drawer`
- `data/KeyValueGrid` · `data/ActivityFeed`
- `funnel/AudienceCard.tsx` — layout reference for DistributionCard
- `use-substrate-stream` (created in C7 — see dependency)

### W2 — Decide [Opus]

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| NotificationBell | none | substrate `me:*` queue + unread badge | **new** (~60 lines) — only genuinely new chrome |
| ChannelDistributionCard | `funnel/AudienceCard.tsx` | needs hover-card mount + button row | **compose** (~50 lines) |
| ChannelRow | `Navigation.tsx` RailRow | needs emoji + colour dot + SSE badge | **extend** Navigation.tsx render branch |
| ChannelCreateForm | drawer + `ui/input` × 5 + TagPills | none | **compose** (~80 lines) |

LOC budget: ≤ 240.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/NotificationBell.tsx` (new, ~60 lines)
- [ ] `web/src/components/in/ChannelDistributionCard.tsx` (new, ~50 lines)
- [ ] `web/src/components/in/ChannelCreateForm.tsx` (new, ~80 lines)
- [ ] `web/src/components/in/Navigation.tsx` — add ChannelRow branch when row has `kind:channel`
- [ ] `web/src/components/in/Inbox.tsx` — mount NotificationBell in header
- [ ] `web/src/pages/api/tags.ts` — extend to CRUD ChannelCreateForm payload (or split to `?scope=channels` settings)

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D3-ctagmgr.test.ts` exits 0** (≤80 LOC · <500ms · Vitest + msw — covers 403 + ★ promote signal)
- [ ] composite ≥ 0.65

---

## C4 — CComp  [tier: complex]

Universal composer wired — modes · holdout · schedule · gate · inline migration.

**Exit:** D4 passes.

### W1 — Recon [Haiku · parallel]

**Existing code:**
- `web/src/components/in/Composer.tsx` + `web/src/components/in/composer/*`
- `web/src/lib/in/draft.ts` · `web/src/lib/in/create-prompts.ts`
- `web/src/components/chat/ChatDock.tsx` — reference inline-Drawer composer pattern

**Primitive inventory:**
- `ai-elements/prompt-input.tsx` slot map (Header/Body/Footer/Tools/Submit)
- `composer/TemplatePicker.tsx` (cmdk canonical)
- `ui/popover` · `ui/select` (for SchedulePill)
- `chat/AddMenu.tsx` · `chat/AttachmentsPreview.tsx`
- `ai-elements/model-selector.tsx`

### W2 — Decide [Opus]

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| InlineComposerDrawer | `ui/Drawer` + `Composer.tsx` | needs `side="bottom"` mount + template prefill API | **compose** (~30 lines) |
| SchedulePill | `ui/popover` + `ui/select` | none | **compose** (~25 lines) |
| MentionPicker | `composer/TemplatePicker` shape | swap data source | **compose** (~50 lines) |
| Holdout fanout server-side | dispatcher already has `holdout` payload | needs claw to honor `holdout` % on sub: fanout | **extend** claw `/api/signal/sub:...` handler |
| GatePanel live wiring | `composer/GatePanel.tsx` | needs `/api/ask/gate:check` route | **new endpoint exception** (→ §13.4 of `crm.md`; gate check is genuinely sync) |

LOC budget: ≤ 300 + 1 ask route.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/InlineComposerDrawer.tsx` (new, ~30 lines)
- [ ] `web/src/components/in/composer/SchedulePill.tsx` (new, ~25 lines)
- [ ] `web/src/components/in/composer/MentionPicker.tsx` (new, ~50 lines)
- [ ] `web/src/components/in/Composer.tsx` — wire SchedulePill + MentionPicker into header/body
- [ ] `web/src/components/in/HeroCTA.tsx` + `web/src/components/in/ListHeader.tsx` — replace `window.location.href = /chat?…` with `openInlineComposer(template)` callback
- [ ] `web/src/components/in/Inbox.tsx` — host InlineComposerDrawer state + callback
- [ ] `web/src/lib/in/create-prompts.ts` — return `{ label, template }` instead of redirect-only
- [ ] `web/src/pages/api/ask/gate/check.ts` (new) — evaluates consent/cap/suppression/compliance for a (receiver, body) tuple
- [ ] `claw/src/signals.ts` — honor `holdout` % on `sub:` fanout (warn N% with `holdout-actor` tag)

**W3b:**
- [ ] `web/src/components/in/Composer.tsx` — wire GatePanel to `/api/ask/gate/check` (sequential — after W3a's gate route lands)

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D4-ccomp.test.ts` exits 0** (≤100 LOC · <1s · msw counts 18 sub: + 2 holdout-warns; gate:check intercepted)
- [ ] `grep -r 'location.href.*/chat' web/src/components/in/` returns empty
- [ ] composite ≥ 0.65

---

## C5 — CTpl  [tier: simple]

90 starter templates seeded; picker wires composer state from template.

**Exit:** D5 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/components/settings/TemplateManager.tsx` — CRUD UI
- `composer/TemplatePicker.tsx` — `onPick` shape
- `migrations/0037_templates.sql` (or wherever shipped)
- `agents/template-starters.md` — current count (5 / 90)
- `web/src/lib/in/templates.ts` — `SignalTemplate` type

### W2 — Decide [inline]

90 starter rows are data. No new components. One migration adds 85 more rows partitioned into `marketer` / `sales` / `service` role.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `migrations/0043_template_starters_90.sql` (new) — 90 INSERTs
- [ ] `web/src/components/in/Composer.tsx` — when TemplatePicker `onPick` fires, set `body + tags + receiverMode + receiverTarget + holdout + sendAt` from template
- [ ] `web/src/pages/api/templates/index.ts` — ensure `workspace=_starter` rows are read-only

**W3b:** empty.

### W4 — Verify [inline]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D5-ctpl.test.ts` exits 0** (≤50 LOC · <200ms · API count + applyTemplate state assertion — one file)
- [ ] composite ≥ 0.65

LOC budget: ≤ 60 (migration mostly).

---

## C6 — CK  [tier: simple]

30 keyboard shortcuts + Spotlight quick-add parser.

**Exit:** D6 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/components/in/Inbox.tsx` — current shortcut registry (6 action keys)
- `web/src/lib/keyboard/shortcuts.ts` — `registerShortcut` API
- `web/src/components/keyboard/{Spotlight,HelpOverlay}.tsx`

### W2 — Decide [inline]

30 shortcuts = data. Spotlight quick-add parser is a regex pre-pass on input → routes to dispatcher.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/in/Inbox.tsx` — extend shortcut list per [crm-buttons.md §29](crm-buttons.md): add `p`/`s`/`n`/`f`/`t`/`e`/`.`/`⌘z`/`⌘D`/`⌘S`/`⌘B`/`⌘L`/`⌘\`/`⌘,`/`⌘.`/`g i`/`g p`/`g t`/`g c`
- [ ] `web/src/components/keyboard/Spotlight.tsx` — add quick-add regex pre-parser (e.g. `^new (task|note|event) (.+)`)
- [ ] `web/src/components/keyboard/HelpOverlay.tsx` — auto-generates from registry; nothing to edit

**W3b:** empty.

### W4 — Verify [inline]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D6-ck.test.ts` exits 0** (≤80 LOC · <500ms · jsdom KeyboardEvents · 30 shortcuts asserted from registry, not from rendered overlay)
- [ ] composite ≥ 0.65

---

## C7 — CPerf  [tier: complex]

Perf budgets + `useSubstrateStream` hook + Lighthouse 90+ on `/in/<group>`.

**Exit:** D7 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/components/chat/MessageList.tsx` — SSE consumer pattern (reference)
- `web/src/components/funnel/LiveEventStream.tsx` — alternative SSE pattern
- `web/src/pages/api/analytics/watch.ts` — server SSE shape
- `web/scripts/lighthouse-in.sh` — current run script (if exists)

### W2 — Decide [Opus]

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `useSubstrateStream` hook | inline SSE in MessageList | no shared abstraction | **compose** (~80 lines) |
| EntityList virtualisation | `@tanstack/react-virtual` (external) | EntityList renders all today | **wrap** with the virtual lib |
| Memoisation pass | existing `memo` on EntityCard | some components re-render | targeted `useMemo` per profile |

LOC budget: ≤ 150.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/hooks/use-substrate-stream.ts` (new, ~80 lines)
- [ ] `web/src/components/in/Inbox.tsx` — wire stream for active-state polling (replaces 30s `setInterval`)
- [ ] `web/src/components/in/EntityList` (inline) — virtualise via `@tanstack/react-virtual` if list ≥100 rows
- [ ] `web/scripts/lighthouse-in.sh` — extend with `/in/<groupId>` route check; fail < 90

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`LIGHTHOUSE=1 bun vitest run tests/perf/D7-cperf-lighthouse.test.ts` exits 0** (perf ≥ 95, FCP < 1000ms)
- [ ] **`bun vitest run tests/e2e/crm/D7-sync.test.ts` exits 0** (≤70 LOC · mocked EventSource, two instance render, callback fires <1.5s — no Playwright needed)
- [ ] composite ≥ 0.65 · speed ≥ 0.85

---

## C8 — CMcpInbox  [tier: simple]

10 MCP tools wrap existing substrate routes.

**Exit:** D8 passes.

### W1 — Recon [Haiku · parallel]

- `mcp/src/tools/inbox.ts` — current 10 tools (current state: they call fictional `/api/in/*` endpoints per crm-done audit)
- All real substrate routes in crm.md §13

### W2 — Decide [inline]

Rewrite each tool to call existing route. No new endpoints (rule from `.claude/rules/api.md`).

| Tool | Existing route |
|---|---|
| `inbox_list` | `GET /api/actors?tags=` (actors) · `GET /api/export/<dim>` (other dims) |
| `inbox_open` | `GET /api/actors/[id]` |
| `inbox_send` | `POST /api/signal/[...receiver]` |
| `inbox_subscribe` | `POST /api/signal/actor:<id>:tag.add` |
| `inbox_mark` / `inbox_warn` | `POST /api/{mark,warn}/[edge]` |
| `inbox_react` | `POST /api/signal/entity:<id>:react` |
| `inbox_forget` | `POST /api/forget` |
| `inbox_pulse` | `GET /api/agents/[id]/analytics` |
| `inbox_watch` | `GET /api/analytics/watch` (SSE) |

LOC budget: ≤ 200 (rewrite each tool body).

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `mcp/src/tools/inbox.ts` — rewrite each tool to wrap real route
- [ ] `mcp/tests/inbox.test.ts` — assert each tool returns expected shape from mock server

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun test mcp/tests/inbox.test.ts` exits 0** (each tool exercised against msw-mocked existing routes; zero `/api/in/*` URLs in code)
- [ ] composite ≥ 0.65

---

## C9 — CP  [tier: complex]

PulseAtlas multi-agent variants · StatTile drill · 6 live streams.

**Exit:** D9 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/components/pulse/PulseAtlas.tsx` — current single-agent body
- `web/src/components/in/StatTile.tsx` (♻️ to delete) · `web/src/components/data/MetricTile.tsx`
- `web/src/pages/api/agents/[id]/analytics.ts`
- All 6 stream consumers (see crm-components §3)

### W2 — Decide [Opus]

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| Multi-agent atlas wrapper | `PulseAtlas` accepts `agentId` | no 0/N branch | **extend** `?preset=analytics` body |
| AgentSelector pill | `ui/select` | none | **compose** (~25 lines) |
| Workspace roll-up tiles | `data/MetricTile` × 4 | sum of N agents | **compose** (~40 lines) |
| StatTile drill | already emits `signalId` | no handler routes click | **wire** in `EntityDetail` Network tab |
| Delete `in/StatTile.tsx` | `data/MetricTile.tsx` | duplicate | **delete** after migration |

LOC budget: ≤ 100 (mostly deletions).

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/pulse/PulseAtlas.tsx` — accept optional `workspaceMode` prop; render variant per agent count
- [ ] `web/src/components/pulse/AgentSelector.tsx` (new, ~25 lines)
- [ ] `web/src/components/in/EntityDetail.tsx` — wire StatTile click → dispatcher.run('drill', entity) → updates `?preset=&filter=`
- [ ] `web/src/components/data/MetricTile.tsx` — migrate any `in/StatTile.tsx` import sites
- [ ] **Delete** `web/src/components/in/StatTile.tsx`

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D9-cp.test.ts` exits 0** (≤100 LOC · 3 parameterised sub-cases for 0/1/N agents, all in one test file)
- [ ] `grep -r "from '@/components/in/StatTile'" web/src | wc -l` → 0
- [ ] composite ≥ 0.65

---

## C10 — CSP  [tier: complex]

Settings hub — 4 missing panels + IntegrationsPanel.

**Exit:** D10 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/components/settings/SettingsView.tsx` + `SettingsLayout.astro`
- 9 shipped panels in `settings/`
- `web/src/pages/api/settings.ts` — `?scope=` dispatcher

### W2 — Decide [inline]

| New panel | Compose from |
|---|---|
| ChannelsAdmin | C3's ChannelCreateForm rows in a list |
| ListCTAs | `EditableField` × 14 (per preset) |
| DetailTabs | `EditableField` × 5 (per dimension) |
| ProfileCompletion | `ui/switch` × 14 (toggle per preset) |
| IntegrationsPanel | `cards/ActionCard.tsx` × N (per integration) |

LOC budget: ≤ 400 (5 panels @ ~80 lines).

### W3 — Edit [Sonnet · parallel · 5 agents]

**W3a:**
- [ ] `web/src/components/settings/ChannelsAdmin.tsx` (new, ~80)
- [ ] `web/src/components/settings/ListCTAsEditor.tsx` (new, ~80)
- [ ] `web/src/components/settings/DetailTabsEditor.tsx` (new, ~80)
- [ ] `web/src/components/settings/ProfileCompletionEditor.tsx` (new, ~40)
- [ ] `web/src/components/settings/IntegrationsPanel.tsx` (new, ~120)
- [ ] `web/src/components/settings/SettingsView.tsx` — add 5 routes/tabs
- [ ] `web/src/pages/api/settings.ts` — handle new `scope` values

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D10-csp.test.ts` exits 0** (≤60 LOC · 5-scope round-trip via msw)
- [ ] `ls web/src/pages/api/settings/` → only `[scope].ts` or `index.ts` (no new files)
- [ ] composite ≥ 0.65

---

## C11 — CJ  [tier: complex]

Journey runtime — DAG drag-edit · template chains · dry-run.

**Exit:** D11 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/components/journey/JourneyDAG.tsx` — current renderer
- `agents/journey-runner.md` — runtime spec
- `claw/src/cron.ts` (if exists) — scheduler registration
- `web/src/data/in-types.ts` — `Journey` type

### W2 — Decide [Opus]

Existing JourneyDAG renders. Need: editable nodes, `then`-rule chain, dry-run executor, claw cron registration.

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| Node-edit drawer | `ui/Drawer` + `EditableField` | none | **compose** |
| YAML toggle | `ai-elements/code-block` | none | **compose** |
| Dry-run executor | new agent | claw scheduler register | **agent** registered in claw |

LOC budget: ≤ 200.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/components/journey/JourneyDAG.tsx` — wire `e` opens node-edit Drawer; `y` flips to YAML
- [ ] `claw/src/agents/journey-runner.ts` (new) — cron-scheduled drain of journey signal queue
- [ ] `claw/src/cron.ts` — register journey runner
- [ ] `web/src/pages/api/signal/[...receiver].ts` — accept `kind:journey` signals

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D11-cj.test.ts` exits 0** (≤70 LOC · runJourney + dryRun assertions, no DOM)
- [ ] composite ≥ 0.65

---

## C12 — W7  [tier: complex]

Identity merge — auto/queue/split.

**Exit:** D12 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/lib/identity/{ladder,merge}.ts`
- `web/src/components/crm/ContactSameAs.tsx`
- `web/src/pages/api/sub.ts` (or wherever tracking pipeline lives)

### W2 — Decide [Opus]

Library shipped; tracking pipeline doesn't call it. Wire `lib/identity/ladder.ts` into the visitor-hash resolver path.

LOC budget: ≤ 120.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `web/src/pages/api/events.ts` — on event with email/phone hash, call `resolveIdentity()` from `lib/identity/ladder.ts`
- [ ] `claw/src/identity-watcher.ts` (new) — subscribes to identity transitions, fires `<actor>:merge:<actor>` when confidence ≥ 0.95
- [ ] `web/src/components/crm/ContactSameAs.tsx` — Confirm/Reject buttons wire to dispatcher (already prepared in C2)

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D12-w7.test.ts` exits 0** (≤90 LOC · resolveIdentity + merge/split dispatcher calls, msw network assertions — one file)
- [ ] composite ≥ 0.65

---

## C13 — CX  [tier: complex]

HubSpot/Salesforce/GHL importers + field-map + dry-run.

**Exit:** D13 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/pages/api/composio/{connect,callback,redirect}.ts` — OAuth pattern
- `web/src/components/settings/IntegrationsPanel.tsx` (from C10)
- Klaviyo / Stripe / GA4 / Meta / Google / TikTok adapter spec in `crm.md §13`

### W2 — Decide [Opus]

ImportCSVForm extends to 5 steps. Per-vendor adapter is a worker (`<vendor>:import`).

LOC budget: ≤ 400 (across 6 adapters + form).

### W3 — Edit [Sonnet · parallel · 6 agents]

**W3a (per vendor — parallel):**
- [ ] `claw/src/adapters/hubspot.ts` (rewrite — currently stub) — list/sync API + field-map
- [ ] `claw/src/adapters/salesforce.ts` (rewrite)
- [ ] `claw/src/adapters/ghl.ts` (new, ~80)
- [ ] `claw/src/adapters/klaviyo.ts` (new)
- [ ] `claw/src/adapters/stripe.ts` (extend existing)
- [ ] `claw/src/adapters/shopify.ts` (new, ~80)
- [ ] `web/src/components/in/ImportCSVForm.tsx` (compose existing primitives, ~140 lines)
- [ ] `web/src/pages/api/ask/import/dry-run.ts` (new) — runs adapter against sample
- [ ] `migrations/0044_integration_credentials.sql` — credentials table

**W3b:**
- [ ] `web/src/components/settings/IntegrationsPanel.tsx` — list all 6 integrations with Connect / Test / View errors (after adapters land)

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D13-cx.test.ts` exits 0** (≤110 LOC · msw mocks OAuth + HubSpot list; importCsvFlow returns receipt + appended.<source>.<field> set)
- [ ] composite ≥ 0.65

---

## C14 — CH  [tier: simple]

Write-through agents subscribe to `actor:lifecycle` transitions.

**Exit:** D14 passes.

### W1 — Recon [Haiku · parallel]

- C13 adapters (write side)
- `claw/src/signals.ts` — subscriber pattern

### W2 — Decide [inline]

For each integration, register a write-through agent that subscribes to `sub:actor:lifecycle` and calls vendor API within 30s.

LOC budget: ≤ 200.

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `claw/src/agents/export-hubspot.ts` (new) — subscriber → HubSpot CRM API
- [ ] `claw/src/agents/export-salesforce.ts` (new)
- [ ] `claw/src/cron.ts` — register write-through agents

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D14-ch.test.ts` exits 0** (≤70 LOC · lifecycle flip → msw HubSpot mock receives payload ≤30s)
- [ ] composite ≥ 0.65

---

## C15 — W11  [tier: complex]

PII vault + forget cascade + DSAR + audit.

**Exit:** D15 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/lib/pii/{forget,seal,unseal}.ts`
- `web/src/pages/api/forget.ts` + `web/src/pages/api/forget/[id].ts`
- `web/src/pages/api/pii/reveal/[actor].ts`
- `env.PII_ENVELOPE_KEY` binding

### W2 — Decide [Opus]

Code ships. KMS binding missing. Cascade untested.

LOC budget: ≤ 80 (config + tests, no new files).

### W3 — Edit [Sonnet · parallel]

**W3a:**
- [ ] `wrangler.toml` — bind `PII_ENVELOPE_KEY` from secret
- [ ] `web/tests/pii-cascade.spec.ts` (new) — end-to-end forget + audit
- [ ] `web/src/pages/api/ask/compliance/dsar.ts` (new) — DSAR export endpoint

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D15-w11.test.ts` exits 0** (≤80 LOC · cascade + 6 tier timestamps + 101st reveal → 429 + DSAR JSON)
- [ ] composite ≥ 0.65 · security ≥ 0.95

---

## C16 — QW13  [tier: complex · depends: every cycle above]

`/u/[slug]/in` client scope — same shell, role-gated.

**Exit:** D16 passes.

### W1 — Recon [Haiku · parallel]

- `web/src/pages/in/[groupId].astro` — current scope wiring
- `web/src/lib/viewer.ts` — Viewer type
- `web/roles.md` — cascade spec
- Every component's `viewer` prop sites

### W2 — Decide [Opus]

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `/u/[slug]/in.astro` route | mirror of `/in/[groupId].astro` | scope = slug not group | **new** (~15 lines — just wraps Inbox with `viewer={role:'client'}`) |
| Role-gated Navigation | Navigation.tsx | no viewer-prop branching | **extend** |
| Role-gated OverflowMenu | OverflowMenu.tsx (C2) | filter verbs | **extend** |
| Role-gated Settings nav | SettingsView.tsx | hide non-appearance for client | **extend** |

LOC budget: ≤ 150 (mostly viewer-prop threading).

### W3 — Edit [Sonnet · parallel · 5 agents]

**W3a:**
- [ ] `web/src/pages/u/[slug]/in.astro` (new, ~15 lines)
- [ ] `web/src/components/in/Inbox.tsx` — accept `viewer: Viewer` prop; default `role:'owner'`; pass through
- [ ] `web/src/components/in/Navigation.tsx` — hide CHANNELS zone when `viewer.role==='client'`; hide Settings-tree-root link
- [ ] `web/src/components/in/OverflowMenu.tsx` — filter verbs by role per `crm-buttons.md §0`
- [ ] `web/src/components/settings/SettingsView.tsx` — show only `appearance` + `preferences` when client

**W3b:** empty.

### W4 — Verify [Haiku × 5]

- [ ] `bun run verify` green · `delta_tsc ≤ 0`
- [ ] **`bun vitest run tests/e2e/crm/D16-qw13.test.ts` exits 0** (≤80 LOC · render `<Inbox>` per role prop · assertion matrix per role — no cookies, no browser)
- [ ] **`bun run demo:crm` exits 0** (full plan — all 16 Vitest files + Lighthouse · ~40s total wall time)
- [ ] composite ≥ 0.65

---

## See also

- [`web/crm.md`](crm.md) — principles (tags + subs + pheromone)
- [`web/crm-pages.md`](crm-pages.md) — visual layout (where things appear)
- [`web/crm-buttons.md`](crm-buttons.md) — verb-to-endpoint contract
- [`web/crm-components.md`](crm-components.md) — reuse audit (which file owns each surface)
- [`web/crm-done.md`](crm-done.md) — historical run trail (QW1-QW12 + earlier passes)
- [`one/signals.md`](../plans/signals.md) — substrate contract
- [`one/dictionary.md`](../plans/dictionary.md) — canonical names
- [`one/rubrics.md`](../plans/rubrics.md) — scoring bands
- [`web/roles.md`](roles.md) — role cascade

---

*17 cycles (C0 harness + 16 demos). 2 net-new components. 1 new endpoint (`/api/ask/gate/check`, sync-required). 16 **Vitest** files + 1 Lighthouse CLI wrapper · zero Playwright · ~1,170 LOC total tests · ~10s wall-time (excl. Lighthouse). **Zero humans in the loop** — `bun run demo:crm` is the gate, exit-code 0 closes the plan. Goal-based, parallel-spawned, token-frugal, autonomous.*
