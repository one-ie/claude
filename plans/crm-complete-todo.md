---
title: CRM — wire the shell to the substrate (buildable)
slug: crm-complete
type: plan
tier: complex
mode: construction
tags: [crm, in, signals, subscriptions, tags, pheromone, wiring, demo-gated, compose]
source_of_truth:
  - web/crm.md                       # surface spec — § 13 is the existing-endpoint canon
  - text/12-crm.md                   # voice + worked example (the actor view = the CRM)
  - one/signals.md                   # substrate primitive contract
  - one/marketing-ontology.md        # locked attribute / namespace canon
  - web/roles.md                     # owner/agency/client/end_user cascade
existing_primitives:
  - web/src/pages/api/actors/[id]/index.ts        # GET → Contact aggregate (header + identity + groups + paths). Used by C-CV.
  - web/src/pages/api/actors/index.ts             # GET → actors list filtered by tags. Used by C-CMcpInbox + C-CS.
  - web/src/pages/api/agents/[id]/analytics.ts    # GET → KPI ladder + funnel + attribution + holdout. Used by C-CP + C-CMcpInbox.
  - web/src/pages/api/analytics/watch.ts          # SSE — live signal tail. Used by C-CMcpInbox watch.
  - web/src/pages/api/signal/[...receiver].ts     # POST → emit signal. Used by C-CComp + C-CMcpInbox.
  - web/src/pages/api/mark/[edge].ts              # POST → mark path. Used by C-CMcpInbox.
  - web/src/pages/api/warn/[edge].ts              # POST → warn path. Used by C-CMcpInbox.
  - web/src/pages/api/forget.ts                   # POST → privacy cascade. Used by C-CMcpInbox.
  - web/src/pages/api/tags/index.ts               # CRUD over tag_namespace. Used by C-CTagMgr.
  - web/src/pages/api/templates/index.ts          # CRUD over signal_templates. Used by C-CTpl.
  - web/src/pages/api/settings.ts                 # CRUD over workspace_settings (dispatch by ?scope=). Used by C-CSP + C-CS.
  - web/src/lib/in/status.ts                      # classify(entity, rules). Used by C-CS.
  - web/src/lib/keyboard/shortcuts.ts             # registry + chord buffer + useShortcut hook. Used by C-CK.
  - web/src/components/ai-elements/prompt-input.tsx              # composer root. Used by C-CComp (already shipped).
  - web/src/components/ai-elements/prompt-input-layout.tsx       # PromptInputCommand for `/` picker. Used by C-CTpl.
  - mcp/src/tools/inbox.ts                        # 10 MCP tools — 7 currently call fictional endpoints. Edit, don't replace.
show: false
escape:
  condition: "any cycle's demo gate fails twice OR a cycle introduces a new /api/ route"
  action: "halt; re-read crm.md § 13 for the existing primitive that already does it"
context_triggers:
  - pattern: "consent|suppression|frequency.cap"
    inject: "one/marketing-ontology.md § Consent + Suppression"
  - pattern: "subscribe|sub:|topic|fan.out"
    inject: "one/signals.md § Subscribe"
  - pattern: "identity|same-as|merge|visitor_hash"
    inject: "web/tracking.md § Identity ladder"
  - pattern: "pii|vault|reveal|forget"
    inject: "web/crm.md § 11 Privacy posture"
  - pattern: "tag|namespace|taxonomy"
    inject: "web/crm.md § 5 Tag taxonomy"
---

# CRM — wire the shell to the substrate

**Goal.** Make every cycle in the CRM plan close on a passing end-to-end demo
that composes existing substrate primitives. No new `/api/` routes. No new
entities. No new tables beyond seed migrations.

**Exit.** `bun run test:crm` runs 10 Playwright specs under `web/tests/e2e/crm/`
(plus one vitest spec for D8 MCP) — every spec passes against `bun run dev` with
seed fixtures applied. `bunx tsc --noEmit` returns 0.

---

## Reuse contract (read before drafting any cycle)

**Power through simplicity.** The smallest amount of new code that closes the
loop wins. Every cycle answers the **compose-or-construct** question before
W3 spawns any agent.

### The bookkeeping rule

If a cycle's demo requires a new `/api/` route, **the demo is wrong** —
re-read [`crm.md`](crm.md) § 13 for the existing primitive that already does
it. The endpoints under `existing_primitives:` in the frontmatter are the
total set this plan composes.

### Compose-first taxonomy

Walk top-to-bottom. First match wins; only fall through to "new file" if
every layer fails.

| Layer | Where to look | Default verdict |
|---|---|---|
| 1. **Domain composition** | `web/src/components/{in,crm,settings,pulse,journey,composer,keyboard}/` | extend the file that already renders this surface |
| 2. **Cross-surface composition** | sibling component folders (`chat/`, `ai-elements/`, `ui/`) | import + slot — do not copy |
| 3. **Design primitives** | `web/src/components/ai-elements/`, `web/src/components/ui/` | compose; never reimplement |
| 4. **Library primitives** | `@/lib/`, `@/engine/`, existing hooks | reuse the helper; do not parallel-write |
| 5. **Substrate endpoints** | `web/src/pages/api/*` listed in `existing_primitives` | compose the URL; never invent a sibling endpoint |
| 6. **New file** | only if 1-5 all fail | requires the W2 justification line |

### Anti-patterns rejected on sight

- ❌ `/api/in/list`, `/api/in/entity`, `/api/in/watch`, `/api/pulse`, `/api/loop/mark-dims` — **none exist; never invent them.** Compose `/api/actors`, `/api/actors/[id]`, `/api/analytics/watch`, `/api/agents/[id]/analytics`, `/api/mark/[edge]` instead.
- ❌ A new `<Composer>` / `<TemplatePicker>` tree when `PromptInput*` already ships
- ❌ A new contact-fetch endpoint when `/api/actors/[id]` already returns `Contact`
- ❌ A new keyboard event handler when `useShortcut()` + the chord buffer already ship

### Reuse audit (mandatory W4 line item, every cycle)

- [ ] No new file under `web/src/pages/api/` unless explicitly listed in cycle's W2
- [ ] Every primitive named in the cycle's W2 slot map appears as an import in the diff
- [ ] `wc -l` of new files totals **< W2-declared LOC budget**
- [ ] `delta_loc_net ≤ W2 target` (negative preferred)

---

## Honest state (2026-05-16 audit)

| Cycle | Code | Wiring | Demo today | Effort to demo |
| --- | --- | --- | --- | --- |
| C-CS | ✅ ships | ✅ client-side classify | ❌ D1 | 1 new endpoint (settings CRUD) + 1 hook + 1 Inbox edit |
| C-CV | 🟡 ships | ❌ EntityDetail never fetches `/api/actors/[id]` | ❌ D2 | 1 new hook + delete 3 derive() helpers |
| C-CTagMgr | ✅ ships | 🟡 TAGS rail hardcoded | ❌ D3 | 1 Inbox edit (rail reads `/api/tags`) |
| C-CComp | ✅ ships | 🟡 reply works; broadcast no-ops | ❌ D4 | 1 Composer edit (fetch /api/signal/) |
| C-CTpl | ✅ ships | 🟡 5/90 starters | ❌ D5 | 1 seed migration |
| C-CK | ✅ ships | ❌ 0/30 shortcuts | ❌ D6 | 1 useEffect in Inbox |
| C-CPerf | ✅ ships | ❌ Lighthouse unmeasured | ❌ D7 | 1 script + 1 vitest |
| C-CMcpInbox | 🟡 tools | ❌ 7/10 fictional URLs | ❌ D8 | 7 URL rewrites in 1 file |
| C-CP | 🟡 ships | ❌ 5/6 mock | ❌ D10 | 1 new hook + PulseAtlas edit |
| C-CSP | ✅ ships | 🟡 untested | ❌ D11 | 3 edits (Privacy/Pack/Status round-trip) |

**Deferred (infrastructure — separate plan needed):** C-CJ (claw cron),
C-CX (12 OAuth flows), C-CH (write-through), C-W7 (tracker pipeline edit),
C-W11 (KMS binding). Each is documented at the end with a "when reopened"
note.

---

## Dependency graph

```
C-CS    ─┐
C-CV    ─┤                          (all 10 independent — no arrow between
C-CTpl  ─┤                          them; each closes on its own demo)
C-CTagMgr
C-CComp ─┼─→  (no consumer)
C-CK    ─┤
C-CPerf ─┤
C-CMcpInbox
C-CP    ─┤
C-CSP   ─┘
```

**No cycle reads a file another cycle writes**, so all 10 run in parallel
under `/do --auto`. Verified per the arrow test:

- C-CTpl writes a seed; C-CComp reads templates at runtime (not from disk).
- C-CSP writes settings; C-CS reads rules at runtime (not from disk).
- C-CK adds shortcuts in Inbox.tsx; C-CTagMgr also edits Inbox.tsx — **W3b
  inside Inbox.tsx**, see below.

### W3 agent parallelism map

```
C-CS         W3a — agent  →  web/src/pages/api/settings/status.ts (new)
             W3a — agent  →  web/src/hooks/use-workspace-rules.ts (new)
             W3b — agent  →  web/src/components/in/Inbox.tsx       (also touched by C-CK, C-CTagMgr)

C-CV         W3a — agent  →  web/src/hooks/use-actor-contact.ts (new)
             W3b — agent  →  web/src/components/in/EntityDetail.tsx (delete derive*)

C-CTagMgr    W3b — agent  →  web/src/components/in/Inbox.tsx       (also touched by C-CK, C-CS)
             W3a — agent  →  web/src/components/settings/TagManager.tsx (ACL verify)

C-CComp      W3a — agent  →  web/src/components/in/Composer.tsx (handleSubmit)

C-CTpl       W3a — agent  →  web/migrations/0042_template_starters.sql (new)
             W3a — agent  →  web/src/pages/settings/templates.astro (filter check)

C-CK         W3b — agent  →  web/src/components/in/Inbox.tsx       (also touched by C-CTagMgr, C-CS)

C-CPerf      W3a — agent  →  web/scripts/lighthouse-in.sh (new)
             W3a — agent  →  web/tests/perf/D7-cperf-lighthouse.test.ts (new)

C-CMcpInbox  W3a — agent  →  mcp/src/tools/inbox.ts (7 URL rewrites)
             W3a — agent  →  mcp/tests/D8-mcp-inbox-compose.test.ts (new)

C-CP         W3a — agent  →  web/src/hooks/use-pulse-data.ts (new)
             W3a — agent  →  web/src/components/pulse/PulseAtlas.tsx (props → hook)

C-CSP        W3a — agent  →  web/src/components/settings/PrivacyControls.tsx
             W3a — agent  →  web/src/components/settings/PackEditor.tsx
             W3a — agent  →  web/src/components/settings/StatusRuleEditor.tsx
             W3a — agent  →  web/src/pages/api/settings.ts (scope dispatch verify)
```

**W3b queue (Inbox.tsx — three cycles touch it; sequence: C-CTagMgr → C-CK → C-CS):**
Each w3b agent re-reads Inbox.tsx after the prior agent's commit.

---

## Status

- [x] C-CS — Status from workspace rules
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D1)
- [x] C-CV — EntityDetail fetches real Contact
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D2)
- [x] C-CTagMgr — TAGS rail reads from registry
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D3)
- [x] C-CComp — Composer fans out via /api/signal
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D4)
- [x] C-CTpl — Seed 90 starters + picker round-trip
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D5)
- [x] C-CK — Register 30 shortcuts at Inbox mount
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D6)
- [x] C-CPerf — Lighthouse measurement gate
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D7)
- [x] C-CMcpInbox — Rewire 7 handlers to existing endpoints
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D8)
- [x] C-CP — PulseAtlas fetches real analytics
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D10)
- [x] C-CSP — Settings round-trip persistence
  - [x] W0 · [x] W1 · [x] W2 · [x] W3 · [x] W4 (demo D11)

---

## C-CV — EntityDetail fetches real Contact  [tier: simple · demo: D2]

**Exit:** `web/tests/e2e/crm/D2-cv-actor-contact.spec.ts` passes. Network tab on Ada test actor shows real `bob-test` path edge from TypeDB; Personal tab shows 2 Granted + 2 Revoked consent chips (not 4 Unknown).

### W1 — Recon  [direct · ≤5 files]

1. **Existing code**
   - `web/src/components/in/EntityDetail.tsx` — three `derive*` helpers fabricate panel data from `entity.tags` / `entity.related`. Lines locating: `function deriveConsent(entity:...`, `function derivePaths(...)`, `function deriveAppended(...)`.
   - `web/src/pages/api/actors/[id]/index.ts` — `GET` returns full `Contact` via `getContact()`.
   - `web/src/lib/crm/actor.ts` — exports `Contact`, `ConsentMatrix`, `ContactPath`, `ContactAppended` types.

2. **Primitive inventory**
   - `web/src/components/crm/ContactConsent.tsx` ✓ shipped — accepts `ConsentMatrix`.
   - `web/src/components/crm/ContactPaths.tsx` ✓ shipped — accepts `ContactPath[]`.
   - `web/src/components/crm/ContactAppended.tsx` ✓ shipped — accepts `ContactAppended[]`.
   - `@/lib/utils` `cn` ✓ shipped.

### W2 — Decide  [inline · simple]

| Proposed file | Closest existing primitive | Gap | Verdict |
|---|---|---|---|
| `web/src/hooks/use-actor-contact.ts` (new) | `getContact()` is server-side only | client lacks fetch + caching for `Contact` | **new** — closes the fetch hop; ~25 LOC; no comparable hook exists |

**Slot map:**
| Primitive | Slot | Cycle puts in |
|---|---|---|
| `useEffect` + `fetch` | hook body | call `/api/actors/[id]`, set state |
| `EntityDetail` actor branch | tab render | `useActorContact(id).then(c → render panels)` |

**LOC budget:** new hook ≤ 30 LOC. EntityDetail delta_loc ≤ -10 (delete 3 derive* > add hook call).

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**

- [ ] `web/src/hooks/use-actor-contact.ts` — new, content:
  ```ts
  import { useEffect, useState } from 'react'
  import type { Contact } from '@/lib/crm/actor'

  export function useActorContact(actorId: string | null): Contact | null {
    const [contact, setContact] = useState<Contact | null>(null)
    useEffect(() => {
      if (!actorId) { setContact(null); return }
      let cancelled = false
      fetch(`/api/actors/${encodeURIComponent(actorId)}`)
        .then((r) => (r.ok ? r.json() : null))
        .then((c) => { if (!cancelled) setContact(c) })
      return () => { cancelled = true }
    }, [actorId])
    return contact
  }
  ```

**W3b — dependent (touches EntityDetail.tsx already edited in C-CV):**

- [ ] `web/src/components/in/EntityDetail.tsx`:
  - **delete** `deriveConsent`, `derivePaths`, `deriveAppended` functions
  - **delete** the corresponding type imports `ConsentMatrix`, `ContactAppended as ContactAppendedRow`, `ContactPath`
  - **delete** the three `useMemo` derivation calls
  - **add** `import { useActorContact } from '@/hooks/use-actor-contact'`
  - **add** `const contact = useActorContact(entity?.dimension === 'actors' ? entity.id : null)`
  - **edit** panel renders: `ContactConsent consent={contact?.header.consent ?? null}` (handle null), `ContactPaths paths={contact?.paths ?? []}`, `ContactAppended rows={contact?.appended ?? []}`

**Seed** — `web/tests/seeds/D2.tql`:
```typeql
insert
  $a isa actor, has aid "ada-test", has name "Ada Lovelace",
    has email "ada@l.org", has lifecycle "customer",
    has consent-email true, has consent-sms true,
    has consent-push false, has consent-call false,
    has channel "telegram@ada", has channel "web:visitor_hash";
  $b isa actor, has aid "bob-test", has name "Bob Pinto";
  $p (source: $a, target: $b) isa path, has strength 0.74;
```

**Demo spec** — `web/tests/e2e/crm/D2-cv-actor-contact.spec.ts`:
```ts
import { expect, test } from '@playwright/test'
const BASE = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:4321'

test('D2: EntityDetail fetches real Contact from /api/actors/[id]', async ({ page }) => {
  await page.goto(`${BASE}/in?d=actors&focus=ada-test&tab=personal`)
  await expect(page.locator('text=Granted')).toHaveCount(2)
  await expect(page.locator('text=Revoked')).toHaveCount(2)
  await page.getByRole('button', { name: 'Network' }).click()
  await expect(page.locator('text=Strongest paths')).toBeVisible()
  await expect(page.locator('text=bob-test')).toBeVisible()
})
```

### W4 — Verify  [inline composite · simple]

- [ ] `bun run verify` green
- [ ] `delta_tsc_errors ≤ 0`
- [ ] `bunx playwright test web/tests/e2e/crm/D2-cv-actor-contact.spec.ts` passes against `bun run dev`
- [ ] `delta_loc EntityDetail.tsx ≤ -10`
- [ ] `wc -l web/src/hooks/use-actor-contact.ts ≤ 30`
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## C-CMcpInbox — Rewire 7 handlers to existing endpoints  [tier: simple · demo: D8]

**Exit:** `mcp/tests/D8-mcp-inbox-compose.test.ts` passes — zero MCP tool handlers call `/api/in/list`, `/api/in/entity`, `/api/in/watch`, `/api/loop/mark-dims`, `/api/pulse`, or `POST /api/signal` without a receiver path.

### W1 — Recon  [direct · ≤3 files]

- `mcp/src/tools/inbox.ts` — 10 tools defined; 7 call fictional endpoints (see audit table).
- `web/src/pages/api/signal/[...receiver].ts` — POST with receiver in URL path.
- `web/src/pages/api/mark/[edge].ts` / `warn/[edge].ts` — edge in URL path.

**Primitive inventory:**
- `/api/actors` ✓ shipped — list filtered by tags
- `/api/actors/[id]` ✓ shipped — single actor with Contact
- `/api/signal/[...receiver]` ✓ shipped
- `/api/mark/[edge]` ✓ shipped
- `/api/warn/[edge]` ✓ shipped
- `/api/analytics/watch` ✓ shipped (SSE)
- `/api/agents/[id]/analytics` ✓ shipped
- `/api/forget` ✓ shipped

### W2 — Decide  [inline · simple]

| Proposed file | Verdict |
|---|---|
| (no new files) | **compose** — 7 URL rewrites only |
| `mcp/tests/D8-mcp-inbox-compose.test.ts` (new test) | **new** — first MCP test in repo |

**URL mapping:**
| Tool | Old (broken) | New (compose) |
| --- | --- | --- |
| `inbox_list` | `/api/in/list?…` | `/api/actors?tags=…&q=…&limit=…` for `dimension=actors`; `/api/export/{dim}?…` otherwise |
| `inbox_open` | `/api/in/entity?id=` | `/api/actors/${id}` (actors only; document scope) |
| `inbox_send` | `POST /api/signal` (receiver in body) | `POST /api/signal/${encodeURIComponent(receiver)}` body `{sender, data}` |
| `inbox_subscribe` | `POST /api/signal` | `POST /api/signal/actor:${actorId}:tag.add` body `{data:{tag: 'sub:' + topic}}` |
| `inbox_mark` | `/api/loop/mark-dims` | `POST /api/mark/${edge}` body `{strength, source}` |
| `inbox_warn` | `/api/loop/mark-dims` | `POST /api/warn/${edge}` |
| `inbox_react` | `POST /api/signal` | `POST /api/signal/entity:${entityId}:react` body `{data:{reaction}}` |
| `inbox_pulse` | `/api/pulse?…` | `/api/agents/${agentId}/analytics?from=&to=` — **tool input gains required `agentId`** |
| `inbox_watch` | `/api/in/watch?…` | `/api/analytics/watch?dimension=&tags=` |
| `inbox_forget` | `/api/forget` ✅ | unchanged |

**LOC budget:** `mcp/src/tools/inbox.ts` net delta ≤ +10 LOC (URL changes + 1 new required input on `inbox_pulse`).

### W3 — Edit  [Sonnet · parallel]

**W3a — independent (different files):**

- [ ] `mcp/src/tools/inbox.ts` — apply 7 URL rewrites per W2 table. For `inbox_pulse`, add `agentId: { type: "string" }` to required inputSchema; for `inbox_open`, document that non-actor dimensions are deferred.
- [ ] `mcp/tests/D8-mcp-inbox-compose.test.ts` — new:
  ```ts
  import { describe, test, expect, beforeEach, vi } from 'vitest'
  import { inboxTools } from '../src/tools/inbox'

  const env = { baseUrl: 'http://localhost:4321', apiKey: undefined }
  let calls: string[] = []

  beforeEach(() => {
    calls = []
    globalThis.fetch = (async (url: string | URL) => {
      calls.push(String(url))
      return new Response('{}', { status: 200 })
    }) as any
  })

  describe('D8: MCP tools compose existing endpoints', () => {
    const tools = inboxTools()
    for (const t of tools) {
      test(`${t.name}: no fictional endpoints`, async () => {
        try { await t.handler({}, env) } catch {}
        expect(calls.join(' ')).not.toMatch(/\/api\/in\/(list|entity|watch)\b/)
        expect(calls.join(' ')).not.toMatch(/\/api\/loop\/mark-dims/)
        expect(calls.join(' ')).not.toMatch(/\/api\/pulse\b/)
        for (const c of calls) {
          if (c.includes('/api/signal')) expect(c).toMatch(/\/api\/signal\/.+/)
        }
      })
    }
  })
  ```

**W3b:** *(empty — all edits independent)*

### W4 — Verify  [inline composite · simple]

- [ ] `bun run verify` green
- [ ] `bun test mcp/tests/D8-mcp-inbox-compose.test.ts` passes (10 sub-tests, one per tool)
- [ ] `grep -E "/api/(in/(list|entity|watch)|loop/mark-dims|pulse)" mcp/src/tools/inbox.ts` returns zero matches
- [ ] `delta_tsc_errors ≤ 0`
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## C-CK — Register 30 shortcuts at Inbox mount  [tier: simple · demo: D6]

**Exit:** `?` overlay lists 30 registered shortcuts; `⌘K` opens Spotlight; `g i` chord navigates to inbox preset.

### W1 — Recon  [direct · ≤3 files]

- `web/src/components/in/Inbox.tsx` — has `installGlobalListener()` + state setters for dimension/preset/status/spotlight/help.
- `web/src/lib/keyboard/shortcuts.ts` — `registerShortcut(s: Shortcut)` returns unsub fn; chord buffer ships.
- `web/src/components/keyboard/HelpOverlay.tsx` — reads `listShortcuts()` for the `?` overlay.

**Primitive inventory:**
- `useShortcut`, `registerShortcut`, `listShortcuts`, `installGlobalListener` ✓ shipped.
- `cmdk` package ✓ — Spotlight wraps it.

### W2 — Decide  [inline · simple]

| Proposed file | Verdict |
|---|---|
| (no new files) | **compose** — one `useEffect` in Inbox.tsx |

**LOC budget:** `Inbox.tsx` delta_loc ≤ +130 (30 shortcut entries + setRow/moveSelection helpers if absent).

### W3 — Edit  [Sonnet · sequential after C-CTagMgr · C-CS edits to Inbox.tsx]

**W3b only (queued after the other Inbox.tsx edits land):**

- [ ] `web/src/components/in/Inbox.tsx` — add a `useEffect` registering all 30 shortcuts from [`crm-pages.md`](crm-pages.md) § 11. Full list:

  | id | keys | category | description | handler |
  |---|---|---|---|---|
  | nav.next | `j` | nav | Next row | moveSelection(+1) |
  | nav.prev | `k` | nav | Prev row | moveSelection(-1) |
  | nav.peek | `Space` | nav | Peek detail | setSelectedId(selectedId) |
  | nav.open | `Enter` | nav | Open focused | open focused entity |
  | tab.now | `1` | nav | Status NOW | setStatus('now') |
  | tab.top | `2` | nav | Status TOP | setStatus('top') |
  | tab.todo | `3` | nav | Status TODO | setStatus('todo') |
  | tab.done | `4` | nav | Status DONE | setStatus('done') |
  | jump.inbox | `⌘1` | jump | Inbox | setRow('events', null) |
  | jump.drafts | `⌘2` | jump | Drafts | setRow('events', 'drafts') |
  | jump.sent | `⌘3` | jump | Sent | setRow('events', 'sent') |
  | jump.people | `⌘4` | jump | People | setRow('actors', null) |
  | jump.tools | `⌘5` | jump | Tools | setRow('things', null) |
  | jump.groups | `⌘6` | jump | Groups | setRow('groups', null) |
  | jump.journeys | `⌘7` | jump | Journeys | setRow('paths', null) |
  | jump.tasks | `⌘8` | jump | Tasks | setRow('events', 'tasks') |
  | jump.frontier | `⌘9` | jump | Frontier | setRow('learning', 'frontier') |
  | chord.gi | `g i` | jump | Go inbox | setRow('events', null) |
  | chord.gp | `g p` | jump | Go people | setRow('actors', null) |
  | chord.gt | `g t` | jump | Go tasks | setRow('events', 'tasks') |
  | chord.gc | `g c` | jump | Go calendar | setRow('events', 'meetings') |
  | chord.gd | `g d` | jump | Go drafts | setRow('events', 'drafts') |
  | act.reply | `r` | action | Reply | emitClick('ui:in:reply', {id}) |
  | act.compose | `c` | action | Compose | emitClick('ui:in:compose') |
  | act.mark | `m` | action | Mark | emitClick('ui:in:mark', {id}) |
  | act.warn | `w` | action | Warn | emitClick('ui:in:warn', {id}) |
  | act.archive | `a` | action | Archive | emitClick('ui:in:archive', {id}) |
  | act.claim | `C` | action | Claim | emitClick('ui:in:claim', {id}) |
  | meta.spotlight | `⌘k` | meta | Spotlight | setSpotlightOpen(true) |
  | meta.help | `?` | meta | Help | setHelpOpen(true) |
  | meta.search | `/` | meta | Focus search | search input ref.focus() |

  Helpers needed inside Inbox.tsx (add if absent):
  ```ts
  const setRow = (dim: Dimension, preset: string | null) => {
    setDimension(dim); setPreset(preset)
  }
  const moveSelection = (delta: number) => {
    // navigate selectedId within the current filtered entities
  }
  ```

  Register block:
  ```ts
  useEffect(() => {
    const list: Shortcut[] = [/* 30 entries above */]
    const unsubs = list.map((s) => registerShortcut(s))
    return () => unsubs.forEach((u) => u())
  }, [/* deps */])
  ```

**Demo spec** — `web/tests/e2e/crm/D6-ck-shortcuts.spec.ts`:
```ts
test('D6: ⌘K opens Spotlight, all 30 shortcuts registered', async ({ page }) => {
  await page.goto('/in')
  await page.keyboard.press('Meta+K')
  await expect(page.locator('[role="combobox"]')).toBeVisible()
  await page.keyboard.press('Escape')
  await page.keyboard.press('?')
  await expect(page.locator('[data-testid="help-overlay"] li')).toHaveCount(30)
})
test('D6: j/k navigates, g i jumps to inbox', async ({ page }) => {
  await page.goto('/in?d=actors')
  await page.keyboard.press('g'); await page.keyboard.press('i')
  await expect(page).toHaveURL(/d=events/)
})
```

### W4 — Verify  [inline composite · simple]

- [ ] `bun run verify` green
- [ ] `D6-ck-shortcuts.spec.ts` passes
- [ ] `listShortcuts().length === 30` (unit assertion or via HelpOverlay locator count)
- [ ] `delta_loc Inbox.tsx ≤ +130`
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## C-CTpl — Seed 90 starters + verify picker round-trip  [tier: simple · demo: D5]

**Exit:** D1 has 90 starter templates (30 × marketer/sales/service); `/welcome` in composer opens picker; selecting fills body/tags/receiver.

### W1 — Recon  [direct · ≤4 files]

- `web/migrations/0037_signal_templates.sql` — table schema with `workspace_id`, `role`, `receiver_mode`, `receiver_target`, `tags`, `body`, `send_at`, `attach`, `starred`.
- `agents/template-starters.md` — markdown of 5 example templates (NOT a seed).
- `web/src/components/settings/TemplateManager.tsx` — currently lists templates for one workspace; needs to also surface `workspace_id='_starter'` rows as read-only.
- `web/src/components/composer/TemplatePicker.tsx` ✓ shipped — calls `/api/templates?workspace=<x>`.

**Primitive inventory:**
- `PromptInputCommand*` ✓ shipped (TemplatePicker composes it).
- `/api/templates` ✓ shipped (CRUD).

### W2 — Decide  [inline · simple]

| Proposed file | Verdict |
|---|---|
| `web/migrations/0042_template_starters.sql` (new seed) | **new** — pure data; only way to add starters |
| Adjust `TemplateManager.tsx` and `/api/templates` to surface starters | **extend** — single conditional |

**LOC budget:** migration ≤ 200 LOC (90 INSERTs + boilerplate). Code edits ≤ 10 LOC.

### W3 — Edit  [Sonnet · parallel]

**W3a — independent:**

- [ ] `web/migrations/0042_template_starters.sql` — 90 INSERTs. Source content from [`crm.md`](crm.md) § 6 + [`text/12-crm.md`](../text/12-crm.md). Three example rows:
  ```sql
  INSERT INTO signal_templates (id, workspace_id, name, role, receiver_mode, receiver_target, tags, body, send_at, attach, starred, created_at, updated_at) VALUES
    ('tpl-mkt-welcome', '_starter', 'welcome-email', 'marketer', 'sub', 'sub:lifecycle:lead',
     '["campaign:welcome","channel:email"]', 'Hi {name}, welcome aboard — here''s where to start.',
     'now', '[]', 0, strftime('%s','now'), strftime('%s','now')),
    ('tpl-sls-d2-checkin', '_starter', 'trial-d2-checkin', 'sales', 'direct', '{actor}',
     '["seq:trial:step:1","send-at:+24h"]', 'Hi {name}, how''s it going so far?',
     '+24h', '[]', 0, strftime('%s','now'), strftime('%s','now')),
    ('tpl-svc-csat', '_starter', 'csat-after-close', 'service', 'direct', '{actor}',
     '["kind:csat-request","channel:auto"]', 'Quick favor — rate this 1–5.',
     'now', '[]', 0, strftime('%s','now'), strftime('%s','now'));
  -- 87 more rows per role
  ```
- [ ] `web/src/pages/api/templates/index.ts` — accept `workspace=_starter` as readable from any session (read-only filter). Reject PUT/POST when target workspace = `_starter`.

**Demo spec** — `web/tests/e2e/crm/D5-ctpl-picker.spec.ts`:
```ts
test('D5: / opens picker, selecting fills composer', async ({ page }) => {
  await page.goto('/in?d=actors&focus=ada-test')
  const textarea = page.locator('textarea').first()
  await textarea.fill('/welcome')
  await expect(page.locator('text=welcome-email')).toBeVisible()
  await page.locator('text=welcome-email').click()
  await expect(textarea).toHaveValue(/welcome aboard/)
})
test('D5: 90 starters seed (30 per role)', async ({ request }) => {
  const r = await request.get('/api/templates?workspace=_starter')
  const list = await r.json()
  expect(list.filter((t: any) => t.role === 'marketer')).toHaveLength(30)
  expect(list.filter((t: any) => t.role === 'sales')).toHaveLength(30)
  expect(list.filter((t: any) => t.role === 'service')).toHaveLength(30)
})
```

### W4 — Verify

- [ ] `bun run verify` green
- [ ] `wrangler d1 migrations apply` runs `0042_template_starters.sql` cleanly
- [ ] D5 spec passes
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## C-CMcpInbox (above) · C-CV (above) · C-CK (above) · C-CTpl (above)

(Listed first because they're the smallest, highest-leverage compose
cycles. The remaining six follow.)

---

## C-CS — Status from workspace rules  [tier: simple · demo: D1]

**Exit:** Owner edits a status rule via `/settings/status` UI; reload `/in` shows actors reclassified per the new rule (server-side persisted, client-side applied).

### W1 — Recon  [direct]

- `web/src/lib/in/status.ts` — `classify(entity, rules)` accepts rules param; defaults to `DEFAULT_STATUS_RULES`.
- `web/src/components/in/Inbox.tsx` — line ~294 calls `classify(entity)` with no rules.
- `web/src/pages/api/settings.ts` — single dispatcher; check if `?scope=status` is wired.
- `web/migrations/0035_workspace_settings.sql` — table has `workspace_id`, `key`, `value` JSON.

### W2 — Decide

| Proposed file | Verdict |
|---|---|
| `web/src/pages/api/settings/status.ts` | **rejected** — `/api/settings.ts?scope=status` already exists; use it |
| `web/src/hooks/use-workspace-rules.ts` (new) | **new** — closes client fetch + 5-min cache |

### W3 — Edit

**W3a:**
- [ ] `web/src/hooks/use-workspace-rules.ts` — new (~30 LOC). Fetches `/api/settings?scope=status&workspace=…`, returns `StatusRules | null`.
- [ ] `web/src/pages/api/settings.ts` — verify `?scope=status` GET returns `{ rules }`, PUT writes JSON. Add if absent (~15 LOC, no new file).

**W3b** (queued after C-CTagMgr + C-CK Inbox edits):
- [ ] `web/src/components/in/Inbox.tsx`:
  - `import { useWorkspaceRules } from '@/hooks/use-workspace-rules'`
  - `const rules = useWorkspaceRules(groupId)`
  - Replace `classify(entity)` → `classify(entity, rules ?? DEFAULT_STATUS_RULES)` (import default)

**Seed** — `web/tests/seeds/D1.sql`:
```sql
INSERT INTO workspace_settings (workspace_id, key, value) VALUES
  ('test-ws', 'status_rules', json('{"actors":[{"status":"top","anyTag":["industry:dentistry"]}]}'));
```

**Demo spec** — `web/tests/e2e/crm/D1-cs-status-rules.spec.ts`:
```ts
test('D1: workspace rule reclassifies actors', async ({ page }) => {
  // Pre: 5 actors tagged industry:dentistry start as `now`; rule promotes them to `top`
  await page.goto('/in?d=actors&s=top')
  await expect(page.locator('[data-testid="entity-card"]')).toHaveCount(5)
})
```

### W4 — Verify

- [ ] `bun run verify` green
- [ ] D1 spec passes
- [ ] No new file under `web/src/pages/api/`
- [ ] `delta_loc Inbox.tsx ≤ +5`
- [ ] Rubric composite ≥ 0.65

---

## C-CTagMgr — TAGS rail reads from registry  [tier: simple · demo: D3]

**Exit:** Owner-created namespace `campaign:apr-q2` appears in the TAGS rail row; locked `lifecycle:*` PUT returns 403.

### W1 — Recon  [direct]

- `web/src/components/in/Inbox.tsx` — `RAIL_ORDER` is static; LEARNING zone pinned at tail; TAGS zone absent.
- `web/src/pages/api/tags/index.ts` — CRUD over `tag_namespace`; verify locked-name ACL.
- `web/src/lib/in/tags.ts` — `listNamespaces(workspaceId)`.

### W2 — Decide

| Proposed file | Verdict |
|---|---|
| (no new file) | **compose** — extend `RAIL_ORDER` via dynamic fetch |

### W3 — Edit

**W3b** (queued after C-CK Inbox edits; C-CTagMgr runs first in the W3b queue per parallelism map):
- [ ] `web/src/components/in/Inbox.tsx`:
  - `const [tagRail, setTagRail] = useState<NavigationItem[]>([])`
  - On mount: `void listNamespaces(groupId).then((ns) => setTagRail(ns.map(toRailItem)))`
  - Inject `tagRail` items into the rail before LEARNING rows

**W3a (independent):**
- [ ] `web/src/components/settings/TagManager.tsx` — confirm PUT to a locked namespace surfaces 403 to user via toast. Wire if absent (~5 LOC).

**Seed** — `web/tests/seeds/D3.sql`:
```sql
INSERT INTO tag_namespace (workspace_id, name, allowed_values, acl, color, locked) VALUES
  ('test-ws', 'campaign:apr-q2', '[]', '{"write":["owner"]}', 'orange', 0),
  ('test-ws', 'lifecycle:*', '["anonymous","lead","mql","sql","customer","advocate"]', '{"write":["any"]}', 'blue', 1);
```

**Demo spec** — `web/tests/e2e/crm/D3-ctagmgr-rail.spec.ts`:
```ts
test('D3: owner-created namespace appears in TAGS rail', async ({ page }) => {
  await page.goto('/in')
  await expect(page.locator('text=TAGS')).toBeVisible()
  await expect(page.locator('text=campaign:apr-q2')).toBeVisible()
})
test('D3: locked namespace rejects edit', async ({ request }) => {
  const res = await request.put('/api/tags/lifecycle:*', { data: { color: 'pink' } })
  expect(res.status()).toBe(403)
})
```

### W4 — Verify

- [ ] `bun run verify` green
- [ ] D3 spec passes
- [ ] No new file under `web/src/pages/api/`
- [ ] `delta_loc Inbox.tsx ≤ +20`
- [ ] Rubric composite ≥ 0.65

---

## C-CComp — Composer fans out via /api/signal  [tier: simple · demo: D4]

**Exit:** Composer in `sub:` mode with 10% holdout emits 90 signals to `/api/signal/sub:trial-d7` + 10 holdouts logged.

### W1 — Recon

- `web/src/components/in/Composer.tsx` — `handleSubmit` posts to `/conversations/:id/reply` or `/api/in/sessions` only.

### W2 — Decide

| Proposed file | Verdict |
|---|---|
| (no new file) | **compose** — extend `handleSubmit` with a `/api/signal/[receiver]` POST branch |

### W3 — Edit

**W3a:**
- [ ] `web/src/components/in/Composer.tsx`:
  ```diff
  -    onReply?.(entity.id, text, entity.type, entity.sessionId)
  +    if (receiverMode === 'direct' && (entity.type === 'session' || entity.type === 'conversation')) {
  +      onReply?.(entity.id, text, entity.type, entity.sessionId)
  +    } else {
  +      const receiver = receiverMode === 'direct' ? receiverTarget : `${receiverMode}:${receiverTarget}`
  +      void fetch(`/api/signal/${encodeURIComponent(receiver)}`, {
  +        method: 'POST',
  +        headers: { 'Content-Type': 'application/json' },
  +        body: JSON.stringify({
  +          sender: 'composer',
  +          data: { text, tags, holdout: holdout > 0 ? holdout : undefined },
  +        }),
  +      }).catch(() => setStatus('error'))
  +    }
  ```

  Holdout enforcement is server-side: `/api/signal/[...receiver]` already accepts a `holdout` field on `data` and splits `sub:*` fanouts into delivered/control buckets.

**Seed** — `web/tests/seeds/D4.sql`:
```sql
WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM c WHERE n<100)
INSERT INTO actor_tags (actor_id, tag) SELECT 'd4-actor-' || n, 'sub:trial-d7' FROM c;
```

**Demo spec** — `web/tests/e2e/crm/D4-ccomp-broadcast.spec.ts`:
```ts
test('D4: composer broadcasts to sub:trial-d7 with 10% holdout', async ({ page, request }) => {
  await page.goto('/in?d=events&focus=any')
  await page.locator('[data-testid="receiver-pill-sub"]').click()
  await page.locator('[name="receiverTarget"]').fill('trial-d7')
  await page.locator('[data-testid="holdout-10"]').click()
  await page.locator('textarea').first().fill('hello')
  await page.locator('[data-testid="submit"]').click()
  const r = await request.get('/api/analytics/watch?since=now-10s')
  const text = await r.text()
  expect(text).toMatch(/sub:trial-d7/)
  expect((text.match(/holdout:true/g) ?? []).length).toBeGreaterThanOrEqual(9)
})
```

### W4 — Verify

- [ ] `bun run verify` green
- [ ] D4 spec passes
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## C-CPerf — Lighthouse measurement gate  [tier: simple · demo: D7]

**Exit:** Lighthouse `/in` ≥ 95 perf, FCP < 1.0s. No code changes expected unless regression detected.

### W1 — Recon

- `web/dist/_astro/*.js` after `bun run build` — current island sizes.
- `node_modules/.bin/lighthouse` — install if absent.

### W2 — Decide

| Proposed file | Verdict |
|---|---|
| `web/scripts/lighthouse-in.sh` (new) | **new** — shell wrapper for CI |
| `web/tests/perf/D7-cperf-lighthouse.test.ts` (new) | **new** — first perf test |

### W3 — Edit

**W3a:**
- [ ] `web/scripts/lighthouse-in.sh` — see body in `crm-todo.md`; runs lighthouse and parses perf/FCP/INP from JSON.
- [ ] `web/tests/perf/D7-cperf-lighthouse.test.ts` (vitest):
  ```ts
  import { test, expect } from 'vitest'
  import { execSync } from 'node:child_process'
  test('D7: Lighthouse /in ≥ 95 perf', () => {
    const out = execSync('bash web/scripts/lighthouse-in.sh', { encoding: 'utf-8' })
    expect(out).toMatch(/perf=(9[5-9]|100)/)
  })
  ```

### W4 — Verify

- [ ] Lighthouse perf ≥ 95
- [ ] FCP < 1000ms
- [ ] No bundle regression vs W0 baseline
- [ ] Rubric composite ≥ 0.65

---

## C-CP — PulseAtlas fetches real analytics  [tier: simple · demo: D10]

**Exit:** `/in?view=pulse&agent=<id>` renders 4 real KPI tiles + real funnel + non-empty attribution and holdout.

### W1 — Recon

- `web/src/components/pulse/PulseAtlas.tsx` — takes data as props; no fetch.
- `web/src/components/pulse/{KpiLadder,Funnel,Attribution,Holdout,FrontierBlock}.tsx` — display-only.
- `web/src/pages/api/agents/[id]/analytics.ts` ✓ shipped.

### W2 — Decide

| Proposed file | Verdict |
|---|---|
| `web/src/hooks/use-pulse-data.ts` (new) | **new** — fetches `/api/agents/[id]/analytics` |

### W3 — Edit

**W3a:**
- [ ] `web/src/hooks/use-pulse-data.ts` — see body in `crm-todo.md` (~40 LOC).
- [ ] `web/src/components/pulse/PulseAtlas.tsx`:
  - Replace `{ workspaceId, kpis, funnel, attribution, holdout }` props with `{ agentId }`.
  - Internal: `const { kpis, funnel, attribution, holdout } = usePulseData(agentId)`.
  - Render unchanged.

**Demo spec** — `web/tests/e2e/crm/D10-cp-pulse.spec.ts`:
```ts
test('D10: PulseAtlas renders real data from /api/agents/[id]/analytics', async ({ page }) => {
  await page.goto('/in?view=pulse&agent=ada-test')
  await expect(page.locator('[data-testid="kpi-tile"]')).toHaveCount(4)
  await expect(page.locator('svg[data-testid="funnel"]')).toBeVisible()
  await expect(page.locator('text=Loading')).toHaveCount(0)
})
```

### W4 — Verify

- [ ] `bun run verify` green
- [ ] D10 spec passes
- [ ] `grep -E "\\b(123|456|789|999)\\b" web/src/components/pulse/` returns zero (no hardcoded fixtures)
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## C-CSP — Settings round-trip persistence  [tier: simple · demo: D11]

**Exit:** Three settings pages (privacy/packs/status) round-trip through D1: edit → save → reload → values persist. Non-owner gets 403.

### W1 — Recon

- `web/src/components/settings/PrivacyControls.tsx`, `PackEditor.tsx`, `StatusRuleEditor.tsx` — render forms but persistence unverified.
- `web/src/pages/api/settings.ts` — single dispatcher; verify `?scope=privacy|packs|status` switch.

### W2 — Decide

| Proposed file | Verdict |
|---|---|
| (no new file) | **compose** — 3 component edits + 1 dispatcher verify |

### W3 — Edit

**W3a (parallel, 4 files):**
- [ ] `PrivacyControls.tsx` — add load + save against `/api/settings?scope=privacy`.
- [ ] `PackEditor.tsx` — add load + save against `/api/settings?scope=packs`.
- [ ] `StatusRuleEditor.tsx` — add load + save against `/api/settings?scope=status`.
- [ ] `web/src/pages/api/settings.ts` — confirm scope dispatch; enforce owner-role on PUT (existing session middleware).

**Demo spec** — `web/tests/e2e/crm/D11-csp-settings.spec.ts`:
```ts
for (const scope of ['privacy', 'packs', 'status']) {
  test(`D11: ${scope} round-trips through D1`, async ({ page }) => {
    await page.goto(`/settings/${scope}?workspace=test-ws`)
    await page.locator('[data-testid="edit-field"]').first().fill('updated')
    await page.locator('button:has-text("Save")').click()
    await page.reload()
    await expect(page.locator('[data-testid="edit-field"]').first()).toHaveValue('updated')
  })
}
test('D11: non-owner returns 403', async ({ request }) => {
  const res = await request.put('/api/settings?scope=status&workspace=test-ws', {
    headers: { 'x-test-role': 'end_user' }, data: { rules: {} },
  })
  expect(res.status()).toBe(403)
})
```

### W4 — Verify

- [ ] `bun run verify` green
- [ ] D11 spec passes (4 sub-tests)
- [ ] No new file under `web/src/pages/api/`
- [ ] Rubric composite ≥ 0.65

---

## Deferred — infrastructure cycles

These cycles can't ship by composition alone. Each needs its own plan
because the work is infrastructure (cron, OAuth, KMS), not wiring.

### C-CJ — Journey runtime  [needs claw-side cron]
Wire small. Blocker: register `journey-runner` with claw's scheduler.
**When reopened — demo D9:** `POST /api/signal/journey:<id>:enrol` (existing receiver) → step-1 fires within 1s · conversion `mark()`s edge. No new `/api/` route.

### C-CX — Importers + exporters  [12 OAuth flows]
Each integration needs: OAuth flow, encrypted creds in `workspace_settings`,
API client, field-map UI, error handling, rate limiting. 12 sub-cycles —
own plan: `cx-todo.md`.

### C-CH — HubSpot/Salesforce write-through  [needs CX clients]
Blocked on CX integration clients. **When reopened — demo D13:** `lifecycle:sql` transition → HubSpot reflects within 30s via `export-hubspot` agent subscribed to `actor:lifecycle.update`.

### C-W7 — Identity rungs 2–5  [needs tracker pipeline edit]
Wire small (`/api/events.ts` imports `lib/identity/ladder`), but the
tracker pipeline is shared infrastructure — needs its own audit.
**When reopened — demo D14:** Same person across 3 channels resolves to one actor with `same-as` confidence ≥ 0.95.

### C-W11 — PII vault + forget cascade  [needs KMS binding]
Wire small (`wrangler.toml` secret binding), but KMS provisioning is
ops work — needs its own plan: `w11-pii-todo.md`.
**When reopened — demo D15:** `POST /api/forget {actor_id}` → all 6 tiers shred · `GET /api/forget/:id` returns receipt · rate-limit 100/hr enforced.

---

## See also

- [`web/crm.md`](crm.md) § 13 — the existing-endpoint canon (the only `/api/` set this plan composes)
- [`web/crm.md`](crm.md) § 17 — what we explicitly don't build
- [`text/12-crm.md`](../text/12-crm.md) — voice + worked example (the demo wall maps to this)
- [`web/crm-pages.md`](crm-pages.md) § 11 — the 30 keyboard shortcuts
- [`one/template-todo.md`](../plans/template-todo.md) — this file's template; reuse contract canon
- [`one/dictionary.md`](../plans/dictionary.md) — names
- [`one/rubrics.md`](../plans/rubrics.md) — scoring bands
- [`mcp/CLAUDE.md`](../mcp/CLAUDE.md) — "wrap, don't reimplement" — the rule that prevented 10 fictional endpoints

---

*Compose existing primitives. Prove with a demo. No new `/api/` routes.*
