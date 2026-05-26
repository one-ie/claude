# Merge `one-ie/one/web/` → `one.ie/`, strip OSS to substrate + dev kit

> **Tooling available (2026-05-13):** the `/merge` loop is live at `one.ie/scripts/merge-loop/`. Phase 2 (steps 4–11) can be driven by `/merge one-ie-web` instead of manual copying — add `~/.merge-loop/sources/one-ie-web.yml` pointing to `~/Server/one-ie/one/web/`, run with `--dry-run` first to review the G0 scope frame, then live. The ratchet gate enforces delta_loc ≤ 0 automatically. Phase 3 (verify) maps to the G1 gate. Phases 4–6 (OSS strip + commit) remain manual.

**Date:** 2026-05-12
**Owner:** Tony (one-day focused session)
**Goal:** End the divergence. One production codebase at `one.ie/`. Public OSS slimmed to substrate + SDK + MCP + CLI + dev examples.

---

## Why

The OSS repo at `github.com/one-ie/one` has accumulated the full productized agency-chatbot platform — 4-tier cascade UI, full billing system (6 crons + credit ledger), workspace dashboard scaffolding, Composio toolkits OAuth UI, element-edit pipeline. Anyone with the OSS could clone the BOQ product and become a competitor. That's giving the moat away.

The right separation, decided today:

- **`one.ie/` (private):** all productized features — cascade UI, billing, dashboard, niche packs, element-edit, audit. This is what NewCo licenses; this is BOQ's moat.
- **`one-ie/one/` (public OSS):** substrate primitives + SDK + MCP + CLI + minimal chat widget + minimal provisioning + niche-pack format spec. Enough for devs to build their own thing on top; not enough to clone BOQ.

Brad-side pitch becomes stronger: *"Substrate is open for your continuity; product is closed and exclusive to BOQ."* NewCo gets real IP to license.

**Merge direction:** OSS web → production (`one.ie/`). The OSS has been the active development surface; production lagged behind. Today flips that: production becomes canonical, OSS becomes the curated subset.

---

## Scope: what moves, what stays, what gets cut

### Moves into `one.ie/` (from `one-ie/one/web/`)

| Layer | Source | Target |
|---|---|---|
| Migrations 0007–0020 | `one-ie/one/web/migrations/` | `one.ie/migrations/` (renumber if conflicts) |
| Cascade + agency components | `one-ie/one/web/src/components/{cascade,settings,sidebar}/` etc. | `one.ie/src/components/agency/`, etc. |
| Workspace dashboard scaffolding | `one-ie/one/web/src/components/cards/`, dashboard pieces | `one.ie/src/components/dashboard/` |
| Billing UI | `one-ie/one/web/src/components/{billing,payments,pay}/` | `one.ie/src/components/billing/` |
| Skill marketplace UI | `one-ie/one/web/src/components/skills/` | `one.ie/src/components/marketplace/` |
| Themes | `one-ie/one/web/src/components/themes/` etc. | `one.ie/src/components/design/` |
| Composio toolkits UI | `one-ie/one/web/src/pages/u/[slug]/tools/`, `pages/api/composio/` | `one.ie/src/pages/u/[slug]/tools/`, `pages/api/composio/` |
| Billing API endpoints | `one-ie/one/web/src/pages/api/{billing,payments,pay,revenue,x402,pricing}.ts` + dirs | `one.ie/src/pages/api/` mirror |
| Billing crons (all 6) | `one-ie/one/web/src/workers/billing-*-cron.ts` | `one.ie/src/workers/` or `one.ie/workers/` (match existing) |
| Domain + provisioning APIs | `one-ie/one/web/src/pages/api/{domain,provision,onboarding,recover,notifications,eval,webhook,settings,branding,report,commit,commit-media,agent-write}.ts` | `one.ie/src/pages/api/` |
| Lib | `one-ie/one/web/src/lib/{billing-config,slug,passkey,viewer,starters,x402,types}.ts` | `one.ie/src/lib/` (merge into existing) |
| Middleware | `one-ie/one/web/src/middleware.ts` | diff and merge cascade/role logic into `one.ie/src/middleware.ts` |
| Spec docs (private) | `one-ie/one/web/{cascade,billing,roles,features,agents-lifecycle,groups,ui,runbook,authentication,emails}.md` | `one.ie/docs/` (private) |

### Stays in OSS `one-ie/one/`

- `agents/` — example agent templates (skill-creator, travel) and `agents/templates/`
- `sdk/` — `@oneie/sdk` TypeScript SDK
- `mcp/` — `@oneie/mcp` MCP server
- `cli/` — `@oneie/cli` CLI
- `python/` — `oneie` Python package
- `claw/` — substrate-level channel bot runtime (Telegram/Discord/HTTP basics, classifier, substrate, composio basics)
- `one/` — canonical docs (dictionary, ontology, patterns, rubrics, lifecycle, dsl, metaphors)
- `web/` — replaced with minimal substrate demo (see "OSS replacement web" below)

### Cut from OSS `one-ie/one/web/` (after merge)

Everything in the "Moves into one.ie" table gets deleted from the OSS web. Specifically:

- All cascade-related UI/middleware (`parent_slug` lives in spec form only, not as agency admin UI)
- All billing crons + billing API endpoints + billing-config + credit ledger schemas
- Settings/agency admin, role admin
- Workspace dashboard scaffolding (3-column layout, KPI cards, agency selector)
- Element-edit pipeline (chat-driven site mutation flow)
- Audit timeline UI
- Stripe-specific integrations beyond a single-token example
- Webhook routing for paid clients
- Email templates for production flows
- Migrations 0007–0020 (keep 0001–0006 as substrate-essential schema or replace with a single minimal example migration)
- The `composio-todo.md` mid-build spec moves to `one.ie/docs/` since the connect cycle is BOQ-relevant

### OSS replacement `web/` (minimal example after strip)

Goal: enough for a dev to wire a chat widget to the substrate and see it work locally. Not enough to deploy a productized agency chatbot.

- `src/components/Chat.tsx` — simple chat widget (no rich messaging, no payment, no edit-mode)
- `src/components/Hero.tsx` — landing page
- `src/pages/index.astro` — single-page demo
- `src/pages/api/chat.ts` — wires to substrate, returns chat responses
- `src/pages/api/provision.ts` — passkey hello-world (single user, no cascade)
- `src/pages/api/logo/[slug].ts` — basic logo gen (already there)
- `src/middleware.ts` — minimal auth, no cascade
- `migrations/0001_owners.sql` only — single owners table, no parent_slug
- `README.md` — rewrite as "minimal substrate demo; for richer agency features, see [one.ie](https://one.ie) (managed product) or contact [one.ie/contact](https://one.ie)"

---

## Execution order

### Phase 1 — audit + safety net (45 min)

1. **Branch backups in both repos:**
   ```
   cd /Users/toc/Server/one-ie/one
   git checkout -b pre-strip-snapshot && git push origin pre-strip-snapshot

   cd /Users/toc/Server/one.ie
   git checkout -b pre-merge-snapshot && git push origin pre-merge-snapshot
   ```
2. **Diff inventory:**
   ```
   diff -rq /Users/toc/Server/one-ie/one/web/src /Users/toc/Server/one.ie/src > /tmp/web-divergence.txt
   diff -rq /Users/toc/Server/one-ie/one/web/migrations /Users/toc/Server/one.ie/migrations > /tmp/migrations-divergence.txt
   ```
   Open both files. Tag each diff line: `MOVE`, `ALREADY-IN-ONE.IE`, `OSS-EXAMPLE-ONLY`, `CUT`.
3. **Check OSS impact:**
   ```
   gh api repos/one-ie/one --jq '{stars: .stargazers_count, forks: .forks_count, watchers: .watchers_count}'
   gh api repos/one-ie/one/forks --jq '.[].full_name'
   ```
   If significant forks of the agency cascade exist, document case-by-case migration support.

### Phase 2 — merge into `one.ie/` (2–3 hours)

Order matters. Schema first, then code that depends on it.

4. **Migrations:** copy missing migrations into `one.ie/migrations/`. Verify numbering doesn't conflict — `one.ie/` has its own migration history. Renumber if needed. Run them locally against a dev D1 to confirm clean apply.
5. **Lib + types:** copy `billing-config.ts` and any missing `lib/*.ts` files. Resolve type conflicts in `one.ie/`'s favor where they exist; merge new fields rather than overwriting.
6. **API endpoints:** copy missing endpoints into `one.ie/src/pages/api/`. Priority order: billing, payments, pay, composio (connect/callback/redirect), domain, eval, notifications, recover, webhook, x402, settings, branding, revenue.
7. **Workers:** copy all 6 billing crons. Update `wrangler.toml` cron triggers in `one.ie/`.
8. **Components:** copy missing component dirs. Watch for naming collisions; prefer `one.ie/` versions when they exist.
9. **Pages:** copy `src/pages/u/[slug]/` workspace routes — `tools/`, `settings/`, `chat/`, `kind/`, `name/` dynamic routes.
10. **Middleware:** diff `web/src/middleware.ts` with `one.ie/src/middleware.ts`. Merge cascade/role/viewer logic into `one.ie/`'s middleware, keeping `one.ie/`'s existing auth flow as the base.
11. **Private spec docs:** move into `one.ie/docs/` (cascade, billing, roles, features, etc.).

### Phase 3 — verify `one.ie/` (45 min)

12. `cd /Users/toc/Server/one.ie && bun run build` → must pass
13. `bun run typecheck` (or `tsc --noEmit`) → must pass
14. `vitest run` (or `bun test`) → all existing 209 tests must still pass. Document any new failures introduced by the merge separately.
15. `bun run dev` → smoke-test cascade provisioning + billing endpoints + workspace dashboard locally
16. Deploy to `dev.one.ie` → confirm `dev.one.ie/u/demo` still 200, `api.one.ie/health` still OK, `nanoclaw` still serving `@onedotbot` + `donal-claw`

### Phase 4 — strip OSS `one-ie/one/web/` (1–2 hours)

17. Delete everything in `web/src/components/` except: `Chat.tsx`, `Hero.tsx`, `Layout.astro`, basic UI primitives
18. Delete everything in `web/src/pages/api/` except: `chat.ts`, `provision.ts`, `logo/[slug].ts`. Cut all `billing/`, `payments/`, `pay/`, `composio/`, `domain.ts`, `eval.ts`, `notifications.ts`, `pay/`, `recover.ts`, `settings.ts`, `themes/`, `webhook/`, `x402.ts`, `revenue.ts`, `report.ts`, `agent-write.ts`, `branding.ts`, `commit.ts`, `commit-media.ts`, `onboarding.ts`, `tools/`, `skill/`, `skills/`, `pricing/`, `_platform/`
19. Replace `web/src/pages/u/[slug]/` with single `index.astro` showing the chat widget. Delete `tools/`, `settings/`, `chat/`, `kind/`, `name/`
20. Delete `web/src/workers/` (all billing crons gone)
21. Cut migrations: keep `0001`–`0006` as substrate-essential. Delete `0007`–`0020`. Or replace migrations dir with a single example migration.
22. Delete spec docs already moved: `cascade.md`, `billing.md`, `features.md`, `roles.md`, `agents-lifecycle.md`, `groups.md`, `ui.md`, `runbook.md`, `authentication.md`, `emails.md`, `composio-todo.md`, all `*-todo.md` files
23. Update `web/README.md`:
    ```
    Minimal substrate demo. Wires a chat widget to the ONE substrate over the SDK.

    What's here:
    - Single-page chat widget example
    - Passkey provisioning hello-world
    - Basic substrate-backed chat API

    What's not here anymore:
    - Agency 4-tier cascade UI
    - Billing system (credit ledger, 6 crons, subscriptions, x402)
    - Workspace dashboard
    - Composio toolkit OAuth UI
    - Element-edit-by-chat pipeline
    - Audit timeline UI

    Those live in the managed product at https://one.ie. Contact us for access.

    The substrate primitives (signal routing, pheromone learning, channel adapters), SDK, MCP server, CLI, and Python package remain fully open in this repo.
    ```

### Phase 5 — verify OSS (30 min)

24. `cd /Users/toc/Server/one-ie/one && bun run build` across all packages — must pass
25. Smoke-test SDK / MCP / CLI: each package must still build and import cleanly with the slimmed `web/`. If anything has a hard dep on a removed file, fix that file's dep before continuing.
26. Verify example agents (`agents/skill-creator`, `agents/travel`) only reference substrate primitives that still exist
27. Update root `README.md` to reflect the new layout — substrate + SDK + MCP + CLI + Python + minimal web demo. Mention `one.ie` as the managed product for the agency layer.

### Phase 6 — commit + release (30 min)

28. **Commits in `one.ie/`:** structured per-feature, e.g.:
    - `feat: merge cascade UI + middleware from OSS`
    - `feat: billing system (6 crons + credit ledger)`
    - `feat: workspace dashboard scaffolding from BOQ wireframe`
    - `feat: composio toolkits OAuth surface`
    - `feat: element-edit pipeline + audit middleware`
    - `chore: migrate spec docs to /docs (private)`
29. **Commit in `one-ie/one/`:** single commit — `v2: extract product layer to managed service · slim to substrate + dev kit`
30. **`CHANGELOG.md` in OSS:**
    ```
    ## v2.0.0 — 2026-05-12

    BREAKING: agency-product features (cascade UI, billing system, workspace dashboard,
    element-edit, audit timeline, Composio toolkit UI, niche-pack authoring) extracted
    to managed product at one.ie. SDK / MCP / CLI / substrate / channel adapters / Python
    package remain fully open.

    If you were using `web/` for the agency cascade or billing, contact us at <support>
    for migration to the managed product.

    What's still here: substrate primitives, SDK, MCP server, CLI, Python package,
    minimal chat widget example, minimal provisioning example, example agents, channel
    adapters, niche-pack format spec.
    ```
31. Tag v2: `git tag v2.0.0 && git push --tags` in `one-ie/one/`
32. Push both repos to remote

### Phase 7 — doc sync (15 min)

33. Update `/Users/toc/Server/boq.md` Q13 + "what else is in the substrate" + relevant sections to reference the new IP separation (`one.ie/` private, OSS public)
34. Update root `/Users/toc/Server/CLAUDE.md` if path conventions changed
35. Update `one.ie/CLAUDE.md` to reflect the absorbed features (cascade, billing, dashboard now production-canonical)

---

## Verification checklist (end of day)

- [ ] `one.ie/` builds clean
- [ ] `one.ie/` tests pass (209+ tests; new tests for merged features can come later)
- [ ] `one.ie/` deploys to `dev.one.ie` cleanly
- [ ] `dev.one.ie/u/demo` still 200
- [ ] `api.one.ie/health` still OK
- [ ] `nanoclaw.oneie.workers.dev` still serving `@onedotbot` + `donal-claw`
- [ ] `one-ie/one/` builds clean across all packages
- [ ] `@oneie/sdk`, `@oneie/mcp`, `@oneie/cli`, `oneie` Python import cleanly with slimmed web
- [ ] OSS README reflects v2 reality
- [ ] CHANGELOG explains the change
- [ ] `boq.md` updated to reference new IP separation

---

## Risks + rollback

- **`one.ie/` build breaks after merge:** revert merge commits, isolate the problematic file, re-merge with conflict resolution. Snapshot branch preserves rollback.
- **Migrations conflict numerically:** renumber the new migrations to land after `one.ie/`'s existing tail. Test on local D1 before production apply.
- **`dev.one.ie` deployment breaks:** snapshot branch can be redeployed instantly. Wrangler rollback is one command.
- **SDK/MCP/CLI hidden dependencies on the rich web:** isolate, fix the dep in the package itself (not by keeping the dep in `web/`), retry strip.
- **Anyone has forked the OSS agency cascade:** open a GitHub issue/discussion inviting them to contact us for managed-product migration. Address case-by-case.
- **`composio-todo.md` cycle still active when this lands:** that's fine — the active build moves into `one.ie/` with everything else; the OSS replacement web doesn't need Composio anyway.

---

## After today

- BOQ doc Q13 + adjacent sections updated to reflect open-substrate + private-product separation
- `one.ie/` becomes the canonical production codebase — all Pilot 1 work happens here
- OSS gets curated updates only (substrate evolution, SDK fixes); rich product features don't leak back
- NewCo IP licensing conversation gains a concrete asset: the private product layer
- Brad-side pitch sharpens: open substrate for safety, exclusive product for moat
