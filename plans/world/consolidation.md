# consolidation.md — three trees → one monorepo, nine packages

**Status:** W0 spec. Authored 2026-05-17. **Supersedes `merge.md` + `merge-one-ie-to-one.ie.md`** — those plans assumed two trees and a non-existent `one.ie/` trunk. Reality is three trees with diverged substrates. This doc locks the new direction.

**Principle:** decompose into packages, *then* relocate. Files don't move until they belong to a named package with a clear boundary. The Convex experiment is archived. The TypeDB substrate wins.

---

## 1. Why this exists

Three trees grew in parallel. Each commits to a different substrate:

| Tree | Touched | Substrate | What it owns | What it lacks |
|---|---|---|---|---|
| `one-ie/dev.one.ie/` | 2026-05-13 | **TypeDB + D1** | 21 `.tql`, 93 engine `.ts`, 236 API routes, 38 migrations, 4 deployed workers (gateway/nanoclaw/sync/backup), full vault/passkey/recovery, `ensureHumanUnit` auth, owner-key, 98 agents | Latest UI, `text/*` marketing, AI SDK v6 wiring |
| `one-ie/one.ie/` | 2026-05-13 | **Convex** | 129 Astro pages, shop ecommerce (126 files), ontology editor UI (399 files), CLI v3.6.40 (published), 856 knowledge-vault md | Different DB — Convex Adapter + Better Auth, no TypeDB |
| `one-ie/one/` (active) | 2026-05-16 | **D1 + KV only** | 58 Astro pages, 152 API endpoints, claw worker (Hono + AI SDK v6), SDK/MCP/CLI/Python packages, `text/*` 16-chapter marketing, AI Elements library (52 components), 48 migrations | **No engine, no `.tql` schema, no vault crypto** — substrate is gone |

**Recon receipts:** per-tree destination maps in `/Users/toc/Server/one-ie/one/.consolidation/` (`map-dev.one.ie.md` — 115 rows · `map-one.ie-convex.md` — 68 rows · `map-one-active.md` — 180+ rows).

**The call:** TypeDB substrate (`dev.one.ie/`'s brain) wins. Convex tree archives, with cherry-picks. Active tree's surface upgrades port in. All three converge into one monorepo with nine packages.

---

## 2. The lock — five decisions, no drift

1. **Substrate: TypeDB.** All 21 `.tql` + 93 engine `.ts` + vault crypto + Better Auth in `dev.one.ie/` is the foundation. Convex is dead.
2. **Cadence: two-pass.** Pass 1 = topology + landing zones, no integration. Pass 2 = wire each `text/*` chapter through `merge-loop` rubric ≥ 0.65.
3. **Topology: 9 packages + 3 apps + 4 publishables** under one mono-root at `one-ie/one.ie/` (renamed from `dev.one.ie/` once the Convex tree is archived).
4. **OSS workflow: export, not maintain.** Public `github.com/one-ie/one` is generated from `packages/{sdk,mcp,cli,python}` + `apps/oss-demo` via a script. One repo to feed; no divergence.
5. **Convex tree: archive whole, cherry-pick 4 things.** Shop ecommerce (126 files → commerce), ontology UI (399 → studio), 37 spec markdowns from knowledge vault → docs/, CLI diff for any features newer than `one/cli/`. Everything else → `.archive/2026-05/convex-experiment/`.

---

## 3. The 9 packages

### Tier 0 — Foundation (no internal deps)

- **`@one/substrate`** — TypeDB engine (10 `.ts`, ~670 LOC) + schema (21 `.tql` across `src/schema/{,seeds,patterns}/`) + Better Auth (auth, plugins/{passkey-webauthn,sui-wallet,wallet-link}, human-unit, role-check, api-auth, typedb-auth-adapter) + vault crypto (vault, signer, bip39, scoped-wallet, owner-key, key-wrap) + D1 migrations (38 from dev.one.ie + 48 from one/web → reconcile to single sequence) + telemetry/trace + storage-cap + rate-limit + idempotency + event-vocabulary. **Private.**

### Tier 1 — Deployable workers (depend on substrate)

- **`@one/gateway`** — `one-gateway` worker. TypeDB proxy + WsHub Durable Object + SSE proxy + origin-allow. Deploys to `api.one.ie`. **Private.**
- **`@one/sync`** — `one-sync` + `one-backup` cron workers + email transport + webhook receivers (Discord, Telegram, Stripe `sub.ts`). **Private.**
- **`@one/nanoclaw`** — nanoclaw worker (Telegram/Discord/web edge agents, classify, sync-personas, donal-claw persona). **Private.**
- **`@one/claw`** — newer claw worker (Hono + AI SDK v6 + D1 + KV + OpenRouter). Substrate-light. Self-contained in `one/claw/`. **Private** (for now; may join public surface once stabilized).

### Tier 2 — Design system (no product deps)

- **`@one/design`** — 6-token CSS, shadcn primitives (29 `ui/`), AI Elements library (52 `ai-elements/`), motion library (10), cards (15), icons (lucide wrappers), pulse (7), pheromone/signal visualisation, keyboard handling, markdown rendering, A/B testing helpers, persona prompts, generative-ui primitives (cherry-picked from Convex tree — 13 files audited for dup), CRO helpers, Tailwind 4 preset + radix-nova tokens. **Mostly public** (subset exported to OSS).

### Tier 3 — Product features (compose substrate + design)

- **`@one/agency`** — 4-tier cascade UI (owner/agency/client/end_user), sidebar (6), settings UI (25), domain routing + branding + logo + OG-image generation, white-label, layout shells, onboarding wizard, viewer/personalization, surface-context, site/menu/sections config, slug routing. The BOQ moat. **Private.**
- **`@one/commerce`** — billing (6 crons + credit ledger, 11 files), payments (1), pay UI (4), x402 send-side SDK (3), Stripe (4), shop ecommerce (cherry-pick 126 from Convex), revenue-split + revenue tracking + unlocks + pricing simulation + sell/buy UI (10 from dev.one.ie). **Private.**
- **`@one/studio`** — `/u/[slug]/*` workspace (8 pages), ontology editor UI (cherry-pick 399 from Convex + 4 from dev.one.ie + 4 from one/), agent editor + composer + agent-md export + analytics (45 files from one/), skill marketplace + skill CRUD + skill refresh, theme editor + theme CRUD + fork + share, eval loop + evaluation service, element-edit pipeline (commit + commit-media), funnel analytics (14 components + 4 routes), journey tracking, discovery feed (`in/`, 23 components), learning index, frontier detection, agent-events stream, agent-write ops, artifacts + templates, world editor, generative-ui editor, Composio integration, PT Corp integration, field-service integration. **Private.**

### Tier 4 — Public publishables (already a clean split)

- **`@oneie/sdk`** — TypeScript SDK (1113 files in `one/sdk/`; plus `compile.ts` + `skills.ts` + updated client/types/telemetry). Substrate types re-exported. **Public.**
- **`@oneie/mcp`** — MCP server (3888 files in `one/mcp/`). 4 tool files: substrate / lifecycle / observability / discovery. Signal + ask reach any nanoclaw receiver. **Public.**
- **`@oneie/cli`** — CLI (389 files in `one/cli/`) — 15 verbs across `agent` (new/validate/lint/compile/serve/publish/sign/verify/eval/diff), `skill` (new/emit/publish/refresh/import/eval), `auth` (login/logout), `dev`. Installs both `one` and `oneie` bins. `--json` on all commands. Audit `one.ie/cli/` (v3.6.40 published) for any newer features to merge. **Public.**
- **`oneie`** (Python) — `python/oneie/` package; uAgents Protocol + Almanac registration + OpenRouterClient. **Public.**

### Three apps that compose packages

- **`apps/web`** — Astro 6 + React 19. Composes substrate + design + agency + commerce + studio + ai-elements + claw client. Deploys to `one.ie` (prod) and `dev.one.ie` (staging). All non-API top-level pages (`index`, `chat`, `create`, `get-yours`, `marketplace`, `skills`, `agents`, `showcase`, `design`, `motion`, `payments`, `tools`, `partners`, `marketing-studio`, `scale`, `in`, `vietnam`, `recovery-codes`, `404`, `500`, `crm/*`, `share/*`, `go/*`).
- **`apps/api`** — gateway worker entrypoint. Deploys to `api.one.ie`. Composes `@one/gateway` + `@one/substrate`.
- **`apps/oss-demo`** — slim public demo. Composes `@oneie/sdk` (read-only) + `@one/design` (subset) + minimal chat widget + passkey-provisioning hello-world. Exported to `github.com/one-ie/one/apps/web/`.

### Top-level (not packages)

- `text/` — 16 marketing chapters (`00-cover` through `16-speed`) + `landing-page-anatomy.md`, `persona-agency-owner.md`, `quotes.md`, `text-plan.md`. Source of truth for product narrative; drives `apps/web` page content.
- `docs/` — private specs (cascade, billing, roles, runbook, authentication, emails, lifecycle, federation) + curated 37 spec/pattern md from Convex knowledge vault.
- `agents/` — curated agent corpus (subset of dev.one.ie's 98 + active tree's 45). Public subset exported to OSS as templates.
- `.claude/` — Claude Code harness (rules, commands, agents, skills, hooks).
- `.archive/2026-05/` — frozen Convex tree + pre-merge snapshots.

---

## 4. Dep graph

```
substrate ←────────────────────────────────────┐
   ↑                                            │
   ├── gateway ────────────────→ apps/api       │
   ├── sync                                     │
   ├── nanoclaw                                 │
   └── claw                                     │
                                                │
design (no deps on substrate at runtime)        │
   ↑                                            │
   ├── agency ←─── substrate (auth, types)      │
   ├── commerce ←─── substrate (payments path)  │
   ├── studio ←─── substrate (entities, events) │
                                                │
sdk ←─── substrate (types only, no runtime)     │
mcp ←─── sdk                                    │
cli ←─── sdk                                    │
python ←── (separate; speaks SDK wire protocol) │
                                                │
apps/web   ← substrate + design + agency + commerce + studio + claw (client)
apps/api   ← gateway + substrate
apps/oss-demo ← sdk + design (subset)
```

**Hard rule:** packages MUST NOT cross-import horizontally (`agency` ↛ `commerce`). All sharing goes through `substrate` (types/auth/data) or `design` (UI primitives). If two product packages need to share, the shared piece moves down to substrate or design.

---

## 5. Move manifest (condensed)

Full row-by-row in `.consolidation/map-{dev.one.ie,one.ie-convex,one-active}.md`. Headline counts here. Every row in those maps is one of: `→ <package>` (move) · `cherry-pick` (move with rewrite) · `ARCHIVE` (freeze) · `DELETE` (cache/build).

### Into `@one/substrate`

From `dev.one.ie/`: `src/schema/`, `src/schema/{seeds,patterns}/`, `src/engine/`, `src/lib/crypto/`, `src/lib/auth-plugins/`, `migrations/typedb/`, `src/lib/peer/`, `src/interfaces/` (signal/ask/mark/warn types only — UI types go to design), `src/lib/sui/` (auth-plugin layer), `src/types/` (core types only).

From `one/`: `web/migrations/` (48 SQL), `web/src/lib/{api-keys,passkey,identity,actor-snapshot,telemetry,trace,tracking-types,use-segment,storage-cap,rate-limit,idempotency,event-vocabulary,types,config,scan,reference,reveal,fade,follow}.ts`, `web/src/pages/api/{auth,signal,identity,actors,admin,tags,threads,paths,visit,things,provision,groups,peer,reveal,pii,forget,abuse,mark,warn,events,health,recover,keys,link,visitor,references,report,notifications,fade,storage-cap}.ts`, `web/src/actions/`, `web/src/data/`, `web/src/types/`.

### Into `@one/gateway`, `@one/sync`, `@one/nanoclaw`, `@one/claw`

- **gateway** — `dev.one.ie/gateway/` (entire). Worker name `one-gateway`. Deploys `api.one.ie`.
- **sync** — `dev.one.ie/workers/{sync,backup}/` + `one/web/src/lib/email.ts` + `one/web/src/pages/api/{webhook,sub}.ts`.
- **nanoclaw** — `dev.one.ie/nanoclaw/` (entire — root + src/{channels,commands,lib,units,workers} + migrations). Worker name `nanoclaw` + `donal-claw` persona.
- **claw** — `one/claw/` (entire 8652 files). Worker name `claw`. Plus `one/web/src/pages/api/{chat,tts,openrouter-models}.ts`, `web/src/lib/{lmm,handler,cf-env,compile,claw-registry}.ts`, `web/src/workers/`, `web/wrangler.toml`.

### Into `@one/design`

From `one/`: `web/src/components/{ui,ai-elements,motion,cards,pulse,keyboard,cro}/` (29+52+10+15+7+2+1 = 116 components), `web/src/lib/{cards,boq-cards,field-service-cards,ptcorp-cards,ptcorp-catalog,motion,ui-icons,cn,pagination,chips,markdown,i18n,utils,personas,persona-prompts,pheromone,ab,use-watch}.ts`, `web/src/styles/`.

From `dev.one.ie/`: `src/components/{design,ui,speed,icons}/`, `src/styles/`.

From Convex tree (cherry-pick, audit for dup): `web/src/components/{generative-ui,ai}/` (13 + 75 files — keep DynamicCard/Table/Chart/Checkout and any non-overlapping ai/ patterns), `web/src/components/ui/` (57 shadcn — de-dup), `web/src/hooks/ai/` (audit).

### Into `@one/agency`

From `one/`: `web/src/components/{settings,sidebar,layout,onboarding}/` (25+6+3+1), `web/src/pages/settings/` (6), `web/src/pages/api/{domains,settings,branding,onboarding,domain,logo}.{ts,/}` , `web/src/pages/api/og/[agentId].png.ts`, `web/src/lib/{cascade,ui-signal,site,menu,sections,shim,slug,surface-context,personalize-map,personalize}.ts`, `web/src/hooks/`, `web/src/layouts/`.

From `dev.one.ie/`: `src/lib/{chat,agents,tools,ai}/`, `src/lib/notify/`, `src/components/{chat,agency,app,dashboard,marketplace,ontology,agents,auth,account,groups,onboard,owner,chairman,security,tasks,legal}/` (cross-cutting product UI → agency).

### Into `@one/commerce`

From `one/`: `web/src/components/{billing,payments,pay}/`, `web/src/pages/api/{billing,payments,pay,unlocks,pricing,_platform/billing}/`, `web/src/pages/api/{x402,revenue}.ts`, `web/src/lib/{billing,billing-state,x402,currency,revenue-split}.ts`.

From `dev.one.ie/`: `src/components/{pay,sell,buy}/`, `src/lib/{pay,sell}/`, `src/pages/{pay,sell,buy}/`, `src/lib/sui/` (payment chain bits — wallet bits go to substrate), `src/move/` (legacy Move contracts; audit for live use).

From Convex tree (cherry-pick): `web/src/components/{shop,ecommerce}/`, `web/src/pages/shop/`, `web/src/templates/shop/`, `web/src/lib/stripe/` (126+46+20+4+2 = 198 files — rewire from Convex to substrate API).

### Into `@one/studio`

From `one/`: `web/src/pages/{studio,u/[slug]}/`, `web/src/components/{chat,agents,skills,tools,in,data,journey,funnel,composer}/` (34+3+1+1+23+3+4+14+1 = 84), `web/src/pages/api/{agents,ask,skills,skill,tools,artifacts,templates,themes,export,analytics,learning,discovery,journey,funnel,in,field-service,ptcorp,composio,select,eval,frontiers,agent-events,agent-write,commit,commit-media}/`, `web/src/lib/{agent,agents,artifact,in,journey,skill,funnel,chat-frames,threads,composio,integrations,analytics-client,plan,problem,eval,viewer,actions-to-tools,agent-md,starters,channels}.{ts,/}`.

From `dev.one.ie/`: `src/pages/u/[slug]/`, `src/components/{u,ontology,world}/`, `src/pages/build/`, `src/pages/agents/`, `src/pages/api/context/`, `src/components/generative-ui/`, `src/worlds/`.

From Convex tree (cherry-pick, rewire): `web/src/components/ontology-ui/` (389), `web/src/pages/ontology/` (~5), `web/src/hooks/ontology/` (3), `web/src/lib/ontology/` (2).

### Into public surface

- **`@oneie/sdk`** — `one/sdk/` (1113) + Convex `cli/src/lib/` after audit + selected types from substrate (re-export).
- **`@oneie/mcp`** — `one/mcp/` (3888).
- **`@oneie/cli`** — `one/cli/` (389) + Convex `cli/src/commands/` after audit + `dev.one.ie/packages/{templates,typedb-inference-patterns}/`.
- **`oneie`** (Python) — `one/python/` (6) + `dev.one.ie/python/` (23, includes oneie pkg + examples).

### Into `apps/web` (non-API pages + app-only routes)

`one/web/src/pages/{index,chat,create,get-yours,marketplace,skills,agents,showcase,design,motion,payments,tools,partners,marketing-studio,scale,in,vietnam,recovery-codes,404,500}.astro`, `web/src/pages/{crm,share,go,in}/`, `web/src/components/{showcase,crm}/`, `web/src/pages/api/{crm,changelog,loadamp,showcase-chat}.{ts,/}`, `web/src/lib/{crm,boq-cards}.ts`, `web/astro.config.mjs`, `web/package.json`, `web/tsconfig.json`.

From `dev.one.ie/`: root-level `src/pages/*.astro` (38) + `src/pages/{account,auth,chat,help,in,settings,groups,[groupId],market}/`, `src/pages/api/{settings,sui,seed,speedtest,domains,av,inbox,tasks,sell,capabilities,.well-known}/`, `src/{contexts,config,entries,layouts,hooks,stores}/`.

### Into `agents/`, `text/`, `docs/`

- **agents/** — `one/agents/` (45) + curated subset of `dev.one.ie/agents/` (36 → keep core/templates/roles/marketing/published-demo, audit donal/debby/dave personas). Total target ~60 files.
- **text/** — `one/text/` (53, entire — 16 chapters + landing-page-anatomy + persona-agency-owner + quotes + text-plan + text-todo + speed.md + build/).
- **docs/** — `one/one/` (127 canonical docs — dictionary, ontology, patterns, rubrics, lifecycle, DSL, education-ontology, integrate, etc.) + `dev.one.ie/docs/` (21 private specs) + 37 keepers from Convex knowledge vault (ontology.md, architecture.md, patterns/, etc.).

### Into `.archive/2026-05/`

- `convex-experiment/` — entire `one-ie/one.ie/` minus the cherry-picks above (~3500 files incl. node_modules).
- `dev.one.ie-snapshot/` — frozen copy of `one-ie/dev.one.ie/` before rename (insurance).
- `one-pre-merge/` — frozen copy of `one-ie/one/` before strip (insurance).
- 730 markdown files from Convex knowledge vault (crypto theses, games docs, padel playbook, etc.).
- `dev.one.ie/{prompts,audits,backups,plans,test,tests,scripts (one-offs)}/`.

### Into `DELETE`

`node_modules/`, `dist/`, `.wrangler/`, `.astro/`, `.dev/`, `build/`, `_platform/` (active tree's experimental dir), Convex `.github/workflows/`, all build outputs.

---

## 6. Target topology

```
one-ie/
├── one.ie/                              ← THE monorepo (renamed from dev.one.ie/)
│   ├── package.json                     (bun workspaces declaration)
│   ├── tsconfig.base.json               (path aliases: @one/* → packages/*)
│   ├── biome.json
│   ├── packages/
│   │   ├── substrate/                   (private)
│   │   ├── gateway/                     (private; deployable)
│   │   ├── sync/                        (private; deployable)
│   │   ├── nanoclaw/                    (private; deployable)
│   │   ├── claw/                        (private; deployable)
│   │   ├── design/                      (public subset exported)
│   │   ├── agency/                      (private)
│   │   ├── commerce/                    (private)
│   │   ├── studio/                      (private)
│   │   ├── sdk/                         (public — @oneie/sdk)
│   │   ├── mcp/                         (public — @oneie/mcp)
│   │   ├── cli/                         (public — @oneie/cli)
│   │   └── python/                      (public — oneie)
│   ├── apps/
│   │   ├── web/                         (Astro app → one.ie + dev.one.ie)
│   │   ├── api/                         (gateway entry → api.one.ie)
│   │   └── oss-demo/                    (public demo, exported)
│   ├── text/                            (16-chapter marketing source of truth)
│   ├── docs/                            (private + curated Convex specs)
│   ├── agents/                          (curated corpus)
│   ├── scripts/
│   │   ├── deploy.ts                    (W0 gate → build → 4 workers → health)
│   │   ├── export-oss.ts                (mono → public github.com/one-ie/one)
│   │   └── merge-loop/                  (existing — keep)
│   ├── .claude/                         (harness)
│   └── .github/workflows/
└── .archive/
    └── 2026-05/
        ├── convex-experiment/
        ├── dev.one.ie-snapshot/
        └── one-pre-merge/
```

**Public OSS at `github.com/one-ie/one`** = `apps/oss-demo` + `packages/{sdk,mcp,cli,python}` + slimmed `packages/design` subset, regenerated by `scripts/export-oss.ts` on each release.

---

## 7. Pass 1 — Topology + landing zones (this doc + scaffolding)

| Step | Action | Verify |
|---|---|---|
| 1a | This doc reviewed + W0 sign-off | User checks all boxes in §10 |
| 1b | `.archive/2026-05/` created; Convex tree (`one-ie/one.ie/`) moved there | `ls .archive/2026-05/convex-experiment/` returns files |
| 1c | Snapshot copies made: `dev.one.ie-snapshot/`, `one-pre-merge/` | sha of each tree matches snapshot |
| 1d | `dev.one.ie/` renamed → `one.ie/` | `git mv` (if same repo) or directory mv + `.git` survival |
| 1e | `one.ie/package.json` workspaces block declared (`packages/*`, `apps/*`) | `bun install` runs without error |
| 1f | Empty `packages/{substrate,gateway,sync,nanoclaw,claw,design,agency,commerce,studio}` with stub `package.json` + `README.md` per package | each `bun run build` is a no-op success |
| 1g | Empty `apps/{web,api,oss-demo}` with stub `package.json` | same |
| 1h | Cherry-pick the 4 public packages from `one/` into `packages/{sdk,mcp,cli,python}` | each builds standalone |
| 1i | Move `text/` and `agents/` (active tree's) into `one.ie/text/` and `one.ie/agents/` (merge with existing) | `text/contents.md` opens; agent md parses |
| 1j | Write `scripts/export-oss.ts` skeleton (dry-run mode only — no push yet) | `bun run scripts/export-oss.ts --dry-run` lists what would publish |

**Pass 1 exit gate:** `cd one.ie && bun install && bun run build` succeeds. All 9 packages + 3 apps build to empty (or trivial) artifacts. Nothing is integrated yet — the monorepo just exists.

---

## 8. Pass 2 — Wire 16 text/* chapters

Each chapter is one merge-loop cycle:

```
DECLARE → CLASSIFY → DEDUPE → FIT → LAND → COMPRESS → GATE (rubric ≥ 0.65)
```

| # | Chapter | Packages it touches | Apps page |
|---|---|---|---|
| 00 | cover | — | `apps/web/src/pages/index.astro` |
| 01 | brand | design, agency | `apps/web/src/pages/brand.astro` |
| 02 | agency | agency, substrate | `apps/web/src/pages/agency.astro` |
| 03 | chatbots | studio, design (ai-elements), claw | `apps/web/src/pages/chatbots.astro` |
| 04 | models | claw, studio | `apps/web/src/pages/models.astro` |
| 05 | agents | studio, substrate, claw | `apps/web/src/pages/agents.astro` |
| 06 | skills | studio | `apps/web/src/pages/skills.astro` |
| 07 | tools | studio (Composio), substrate | `apps/web/src/pages/tools.astro` |
| 08 | memory | substrate, studio | `apps/web/src/pages/memory.astro` |
| 09 | teams | agency, studio | `apps/web/src/pages/teams.astro` |
| 10 | tracking | substrate, studio | `apps/web/src/pages/tracking.astro` |
| 11 | analytics | studio | `apps/web/src/pages/analytics.astro` |
| 12 | crm | studio, agency, apps/web | `apps/web/src/pages/crm.astro` |
| 13 | learning | substrate (L5/L6 loops), studio | `apps/web/src/pages/learning.astro` |
| 14 | development | sdk, mcp, cli, python | `apps/web/src/pages/development.astro` |
| 15 | security | substrate (auth, vault), agency (cascade) | `apps/web/src/pages/security.astro` |
| 16 | speed | substrate (verify gates), design (perf budget) | `apps/web/src/pages/speed.astro` |

**One chapter per cycle.** Cycle exits with rubric numbers (security/stability/simplicity/speed) ≥ 0.65 each. Failed cycles dissolve, don't land.

---

## 9. Classifier + threat model

### Classifier

| Prior | State | Note |
|---|---|---|
| Spec locked | **No → Yes on W0 sign-off** | This doc IS the spec |
| Variance known | **Yes** | Three trees + 9 packages enumerated; 3 cherry-pick zones identified |
| Exit scalar | **Per phase** | Pass 1: green `bun run build`. Pass 2: rubric ≥ 0.65 per chapter |
| Files known | **Yes** | Three destination maps in `.consolidation/` |

→ `mode: full`, `lifecycle: evolution`. Each Pass 2 chapter cycle runs `lean`.

### Threat model — what this defends, what it accepts

**Defends:**
- Substrate identity: zero changes to `.tql` schema, engine logic, vault crypto, auth flow. Only relocation.
- Deploy continuity: `one-gateway`, `one-sync`, `nanoclaw`, `claw` keep their worker names. Wrangler configs move with the worker code. Health endpoints unchanged.
- Public API contract: 220+ API routes keep their paths. Files relocate; URLs don't.
- Wallet canary: cleared-cache → Touch ID → same wallet still passes after Pass 1.
- Marketing source of truth: `text/*` 16 chapters survive intact (active tree → mono).

**Accepts:**
- 4-6 weeks of churn while Pass 2 wires 16 chapters.
- One round of dep bump (Astro 6.1 → 6.2, AI SDK v6, motion v12, xyflow, rive, simplewebauthn).
- Convex shop + ontology-UI need rewrite from Convex Adapter to substrate API (audit during cherry-pick).
- Public OSS at `github.com/one-ie/one` is stale until `scripts/export-oss.ts` runs Pass 1 step 1j.

**Does NOT accept:**
- Any change to `.tql` files, engine `.ts`, `vault/*.ts`, `signer/*.ts`, `owner-key.ts`, `auth/*.ts`, `human-unit.ts`. If a move appears to need one → **stop, emit spec-change, reconcile this doc**.
- A package depending horizontally on another product package (agency ↛ commerce, etc.). Forced sharing → push down to substrate or design.

---

## 10. W0 sign-off

Before Pass 1 execution begins, every box ticked:

- [ ] Substrate decision confirmed (TypeDB; Convex archived)
- [ ] 9-package shape agreed (§3)
- [ ] Dep graph rules accepted — no horizontal cross-imports (§4)
- [ ] Move manifest reviewed — `.consolidation/map-*.md` opened (§5)
- [ ] Target topology agreed — `one-ie/one.ie/` mono + `.archive/` (§6)
- [ ] OSS workflow confirmed — export from mono, not maintain separately
- [ ] Pass 1 steps 1a–1j accepted as the next concrete work (§7)
- [ ] Pass 2 chapter-by-chapter cadence accepted (§8)
- [ ] Threat-model row accepted — what we defend, accept, refuse (§9)

---

## 11. After this

When Pass 1 closes green:
- `merge.md` and `merge-one-ie-to-one.ie.md` move to `.archive/2026-05/superseded-plans/`
- `CLAUDE.md` (root) Geography table updates to reflect the new layout
- `one-ie/one/` becomes the staging name for the slim public OSS demo (until `scripts/export-oss.ts` writes it from the mono — then it can be deleted from `one-ie/`)
- `MEMORY.md` index gains a `[Consolidation 2026-05](memory_consolidation_2026_05.md)` entry pointing at the close receipts

When Pass 2 closes green (all 16 chapters):
- `text/` is the literal source of truth for every product page
- Every chapter has a rubric receipt ≥ 0.65 in `.consolidation/cycles/`
- The mono ships to `one.ie` (prod) with `bun run deploy` exiting green
- OSS exported to `github.com/one-ie/one`; managed product lives at `one.ie`; pitch deck has its own paragraph

---

*Three trees in. Nine packages out. One substrate. Two repos visible (private mono + public export). Zero drift.*
