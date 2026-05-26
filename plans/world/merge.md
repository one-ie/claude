# merge.md — integrate `one-ie/` UI into `one.ie/` trunk

> **Tooling available (2026-05-13):** the `/merge` loop is now live at `one.ie/scripts/merge-loop/`. Register `one-ie/one/web/` as a source alias (`~/.merge-loop/sources/one-ie-web.yml`) and run `/merge one-ie-web` to get DECLARE → CLASSIFY → TRANSLATE → RATCHET → COMPRESS → GATES in one command. Stream A (UI port) maps directly to TRANSLATE mode; Stream B (packages) is manual (no translate.md equivalent). Register `translate: ~/.merge-loop/translations/one-ie-web.md` pointing to a translate.md that maps `@mui/*` → `@/components/ui/`, etc.

**Principle:** `one.ie/` is the trunk — wallets, workers, schema, 220+ API routes, live deploy. `one-ie/one/` is the newer surface — fresh UI patterns, AI SDK v6, design tokens, opensource SDK/CLI/MCP. **Direction: port UI from `one-ie/one/web/` into `one.ie/src/`. Adopt opensource packages from `one-ie/one/` as canonical. Retire duplicates.** Wallets, schema, and engine never move.

This plan was authored against recon performed 2026-05-06 by four parallel Haiku agents. Real paths cited throughout.

---

## 1. Why this exists

Two trees grew in parallel:

| Tree | Last touched | What it has | What it lacks |
| --- | --- | --- | --- |
| `one.ie/` | 2026-05-02 | 95+ pages, 220+ API routes, 4 workers, TypeDB schema (10 `.tql` files), full wallet (vault + BIP39 + scoped-wallet + signer abstraction), Better Auth + `ensureHumanUnit`, sponsor, signal/pheromone, growth loop, Stripe, deploy pipeline | Latest UI patterns; AI SDK v6 wiring; locked design tokens; AI Elements library |
| `one-ie/one/` | 2026-05-06 | `web/` (Astro 6 + React 19 + AI SDK v6 + 50+ AI Elements + radix-nova design), `sdk/` (with new `compile.ts`, `skills.ts`), `cli/`, `mcp/`, `python/`, `.claude/rules/design.md` | Wallets, workers, TypeDB schema, 220 API routes, real agent corpus, deploy pipeline |

Drift will only get worse. One trunk, one set of opensource packages, one canonical `.claude/`.

---

## 2. The recon (load-bearing facts)

### one.ie/ — the trunk (don't move)

- **Workers (4 live):** `one-substrate` (`one.ie/wrangler.toml`), `one-gateway` (`one.ie/gateway/wrangler.toml`), `one-sync` (`one.ie/workers/sync/wrangler.toml`), `nanoclaw` (`one.ie/nanoclaw/wrangler.toml`).
- **TypeDB schema (immutable):** `one.ie/src/schema/one.tql` (6 dimensions, 100 lines), `world.tql` (852), `agents.tql`, `sui.tql`, `skins.tql`, plus 8 pattern files under `src/schema/patterns/`.
- **Engine (10 files):** `one.ie/src/engine/{world,persist,loop,boot,llm,agent-md,bridge,durable-ask,federation,index}.ts` — `persist.ts` is 1038 lines.
- **Auth (locked):** `one.ie/src/lib/auth.ts`, `typedb-auth-adapter.ts`, `human-unit.ts` (`ensureHumanUnit`), `api-auth.ts`, `role-check.ts`, plugins under `src/lib/auth-plugins/` (`passkey-webauthn`, `sui-wallet`, `wallet-link`).
- **Wallet code (deterministic crypto):** `one.ie/src/components/u/lib/vault/{vault,passkey,passkey-cloud,crypto,storage,recovery,sync}.ts` + `bip39.ts` + `scoped-wallet.ts` + `signer/{vault-signer,resolve}.ts` + `src/lib/owner-key.ts`.
- **API surface:** 220+ routes under `one.ie/src/pages/api/` — auth, signal, sponsor, pay, billing, agents, memory, query, identity, federation, etc.
- **Deploy:** `bun run deploy` → `one.ie/scripts/deploy.ts` (W0 gate → build → 4 workers parallel → health). `.github/workflows/deploy.yml` gates `main`.

### one-ie/one/web/ — the new UI (port in)

- **Stack:** Astro 6.2.2, React 19.1.0, Tailwind 4, AI SDK v6, `@simplewebauthn/{browser,server}`, motion v12, Rive, XYFlow, Shiki v4, Embla, Stripe.
- **Pages (~12):** `index`, `chat`, `agents`, `skills`, `settings`, `payments`, `design`, `motion`, `showcase`, `get-yours`, `recovery-codes`, `u/[slug]/index`.
- **Components of interest:**
  - `web/src/components/ai-elements/` — 50+ AI Elements (attachments, reasoning, citations, code blocks, tool display, voice menu, web preview, sandbox).
  - `web/src/components/Chat.tsx` (22 KB) — AI SDK v6 orchestrator with React 19 Actions + `useChat`.
  - `web/src/components/ui/` — 29 shadcn primitives (radix-nova preset).
  - `web/src/components/{motion,cards,sidebar,settings,showcase}/`.
- **Design system (load-bearing pattern):** Tailwind 4 with **6 editable tokens** in `Layout.astro` (`--color-{background,foreground,font,primary,secondary,tertiary}`); palette classes (`bg-zinc-*`) banned via `--color-*: initial` in `@theme`. Documented in `one-ie/one/.claude/rules/design.md` — **does not exist in `one.ie/.claude/rules/`**.
- **Auth in this tree:** WebAuthn-only (`provision.ts`, `commit.ts`, `PasskeyKeepThis.tsx`, `recovery-codes.astro`). No wallet UI, no Sui, no BIP39. Stripe is the only payment.

### Opensource packages — `one-ie/one/` is canonical

| Package | `one.ie/packages/` | `one-ie/one/` | Decision |
| --- | --- | --- | --- |
| `sdk/` | Apr 21 | **May 6** — adds `compile.ts` (25 KB), `skills.ts`, updated `client.ts` / `types.ts` / `telemetry.ts` | **Adopt `one-ie/one/sdk/`** |
| `mcp/` | Apr 21 | **Apr 23** — has CLAUDE.md + LICENSE + bun.lock | **Adopt `one-ie/one/mcp/`** |
| `cli/` | Apr 21 (sprawl: admin/, utils/, commands/) | **May 6** — clean: `agent.ts`, `auth.ts`, `dev.ts`, `skill.ts` | **Adopt `one-ie/one/cli/`** |
| `python/` | legacy `one/` package | `oneie/` package | **Adopt `one-ie/one/python/`** |

### Agents — `one.ie/agents/` is canonical

`one.ie/agents/` has 20+ real agent markdowns + `core/`, `dave/`, `debby/`. `one-ie/one/agents/` has only `skill-creator/`. **Keep `one.ie/agents/`. Sync subset outward, not inward.**

### `one.ie/one/` — the mystery subfolder

294 markdowns of design notes / lessons / archive (Apr 21). Not code. **Audit, extract anything still load-bearing into the root plan cluster, archive the rest.**

### `.claude/` — adopt `one-ie/one/.claude/` as canonical

Same `agents/` (W1-W4), same `commands/` (see/create/do/close/sync), same skill set. `one-ie/one/.claude/rules/design.md` is **new** — must come over. `one.ie/.claude/skills/` has `deploy/`, `shadcn/`, `reactflow/`, `zklogin/` extras — must come over. **Merge, don't replace.**

---

## 3. Direction (the call)

**Trunk = `one.ie/`. UI surface upgrades come in. Opensource packages move out to `one-ie/one/` as the publishing surface.**

Why this and not the inverse:
- Wallets, schema, engine, 4 workers, 220 API routes, deploy pipeline, `ensureHumanUnit` are all in one.ie. Moving them is rewriting production.
- UI is replaceable. AI Elements library is portable. Design tokens are 6 CSS vars + a banned-class rule.
- Cleared-cache → Touch ID → same wallet flow was verified end-to-end on 2026-04-27 (memory `wallet_flow_verified.md`). Don't disturb the canary.
- The opensource repo (`github.com/one-ie/one`) has its own deploy + audience — it stays in `one-ie/one/` and we publish from there.

**What this is NOT:** a one-shot copy. It's three streams running in parallel, each with its own gate.

---

## 4. The fence (do-not-disturb)

Anything in this list breaks production if touched without a paired schema/test change:

| Layer | Path | Rule |
| --- | --- | --- |
| TypeDB schema | `one.ie/src/schema/*.tql` (10 files) | Immutable; query only |
| Engine | `one.ie/src/engine/*.ts` (10 files) | Don't modify |
| Wallet crypto | `one.ie/src/components/u/lib/{vault,signer}/*.ts`, `bip39.ts`, `scoped-wallet.ts`, `src/lib/owner-key.ts` | Deterministic — UI calls, never rewrites |
| Auth | `one.ie/src/lib/{auth,typedb-auth-adapter,human-unit,api-auth,role-check}.ts` + `auth-plugins/*` | Every sign-in funnels here |
| API routes | `one.ie/src/pages/api/**` (220+) | Don't break HTTP contract |
| Workers | `one.ie/wrangler.toml`, `gateway/`, `workers/sync/`, `nanoclaw/` | Don't redeploy without testing |
| Deploy | `one.ie/scripts/deploy.ts`, `.github/workflows/deploy.yml` | W0 gate is non-negotiable |

UI work touches `one.ie/src/components/**`, `one.ie/src/pages/*.astro` (non-`api`), `one.ie/src/styles/**`, `one.ie/astro.config.mjs` — and stops at the fence.

---

## 5. The merge map

Three streams. They're independent — can run in parallel after Wave 0.

### Stream A — UI port (`one-ie/one/web/` → `one.ie/src/`)

| Source | Destination | Action |
| --- | --- | --- |
| `one-ie/one/web/src/components/ai-elements/` (50+ files) | `one.ie/src/components/ai-elements/` | Copy verbatim; rewire imports |
| `one-ie/one/web/src/components/Chat.tsx` | `one.ie/src/components/chat/Chat.tsx` | Replace one.ie's chat orchestrator; keep one.ie's `/chat/api` route shape |
| `one-ie/one/web/src/components/chat/{MessageList,VoiceMenu,AddMenu,PaymentCard,ChatDock}.tsx` | `one.ie/src/components/chat/` | Merge with existing `chat/` dir; resolve PaymentCard against one.ie's payment system |
| `one-ie/one/web/src/components/ui/*` (29 shadcn primitives) | `one.ie/src/components/ui/` | Diff and adopt newer variants; `components.json` switches to radix-nova preset |
| `one-ie/one/web/src/components/{motion,cards,settings,sidebar,showcase}/` | `one.ie/src/components/` | Copy as new dirs |
| `one-ie/one/web/src/styles/globals.css` + `Layout.astro` 6-token block | `one.ie/src/styles/global.css` + `one.ie/src/layouts/` | Adopt 6-token design system; ban palette classes in `@theme` |
| `one-ie/one/web/src/pages/{design,motion,showcase,get-yours}.astro` | `one.ie/src/pages/` | Copy as showcase routes |
| `one-ie/one/web/package.json` deps | `one.ie/package.json` | Bump astro to 6.2.2, react 19.1.0; add `motion@12`, `@xyflow/react`, `@rive-app/react-canvas`, AI SDK v6 packages, simplewebauthn pair |

**Do not port:** `web/src/components/auth/PasskeyKeepThis.tsx`, `web/src/pages/api/{provision,commit}.ts`, `web/src/pages/recovery-codes.astro` — one.ie's wallet + passkey stack is fuller. These would replace BIP39/scoped-wallet flows. Skip.

**Do not port:** `web/src/components/pay/` Stripe panel without reconciling with `one.ie/src/pages/api/pay/stripe/*` (4 endpoints already wired to billing).

### Stream B — opensource packages (`one.ie/packages/` → `one-ie/one/`)

| Action | Detail |
| --- | --- |
| Retire `one.ie/packages/sdk/` | Adopt `one-ie/one/sdk/` (newer; has `compile.ts`, `skills.ts`). Update workspace alias `@oneie/sdk` to point at `../../one-ie/one/sdk` (or relocate one-ie/ inside one.ie/ workspaces) |
| Retire `one.ie/packages/cli/` | Adopt `one-ie/one/cli/` (clean 4-command surface). Update `npx oneie` publish path |
| Retire `one.ie/packages/mcp/` | Adopt `one-ie/one/mcp/` |
| Retire `one.ie/python/` | Adopt `one-ie/one/python/oneie/` |
| Resolve `one.ie/packages/templates/` + `typedb-inference-patterns/` | Decide: stay in one.ie, or move to `one-ie/one/`. Default: stay (used by deploy) |

**Open question:** workspace topology. Either (a) `one-ie/` becomes a top-level workspace member of `one.ie/`'s monorepo, or (b) `one-ie/one/` stays a separate repo and `one.ie/` consumes published `@oneie/*` packages from npm. Default to (a) for tighter integration; revisit at Wave 2.

### Stream C — `.claude/` + agents + docs

| Action | Detail |
| --- | --- |
| Backport `one-ie/one/.claude/rules/design.md` → `one.ie/.claude/rules/design.md` | Required for Stream A token system |
| Forward-port `one.ie/.claude/skills/{deploy,shadcn,reactflow,zklogin}/` → `one-ie/one/.claude/skills/` | Keep both `.claude/` trees in sync |
| Sync agent subset `one.ie/agents/` → `one-ie/one/agents/templates/` | Pick which agents are public-template material |
| Audit `one.ie/one/` (294 markdowns) | Extract anything load-bearing into root plan cluster; archive the rest under `transcripts/archive/2026-05/` |
| Update `CLAUDE.md` Geography table | Reflect new package locations after Stream B lands |

---

## 6. Waves

```
W0 — recon + spec lock        (this doc + verification queries)
W1 — UI port (Stream A)       parallel with W2
W2 — packages (Stream B)      parallel with W1
W3 — .claude + agents + docs (Stream C) — depends on W1/W2 paths
W4 — close: deploy, verify, archive one.ie/one/
```

### W0 — recon + spec lock

- [x] Map one.ie UI surface
- [x] Map one-ie/one/web UI surface
- [x] Fence one.ie backend/wallet/workers
- [x] Diff duplicates
- [ ] User confirms direction (this doc)
- [ ] Resolve workspace topology question (Stream B open question above)
- [ ] Resolve `one.ie/one/` audit scope (delete vs archive vs extract)

### W1 — UI port

Spec slice: each ai-element + each chat component + each shadcn primitive gets one Sonnet, one file at a time. Speed budget: dev server first paint must stay <500ms (per `website.md`). Verify gate: `bun run verify` + visual diff on `/chat`, `/u`, `/agents`. Threat-model row: design system change must not touch wallet UI semantics — Touch ID flow stays identical.

**Hard gates:**
1. `/u/save`, `/u/restore`, `/u/send`, `/u/swap`, `/u/receive/*` render and function with new design tokens.
2. Cleared-cache → Touch ID → same wallet canary still passes.
3. No regressions in `bun run verify` (biome + tsc + vitest).

### W2 — packages

Spec slice: one package at a time. For each: (1) move/symlink, (2) update root `package.json` workspaces, (3) re-run `bun install`, (4) run package's own tests, (5) verify consumers (`one.ie/src/lib/*` imports of `@oneie/sdk`).

### W3 — .claude + agents + docs

Spec slice: `.claude/rules/design.md` first (W1 needs it). Then skill cross-port. Then agent subset sync. Then `one.ie/one/` audit. Then root `CLAUDE.md` Geography table refresh.

### W4 — close

- `bun run deploy` from `one.ie/` ships clean.
- `npx oneie` from `one-ie/one/cli/` publishes clean.
- `one.ie/one/` either deleted or archived.
- Memory updates: replace `refs.md` paths, refresh `MEMORY.md` index.
- Pheromone: `mode:full` `lifecycle:evolution` close-tag with rubric score.

---

## 7. Open questions

1. **Workspace topology** (Stream B). Submodule? Monorepo absorption? Published-via-npm? Default proposal: pull `one-ie/` under `one.ie/workspaces/` and keep its own `.git` — single dev experience, two publish targets.
2. **`one.ie/one/` (294 markdowns).** User-driven audit, or single sweep? Anything in there that's referenced by the root plan cluster?
3. **Stripe duplication.** `one-ie/one/web/src/components/pay/` vs `one.ie/src/pages/api/pay/stripe/*` — are we porting the Stripe UI or keeping one.ie's? Default: port the UI shell, keep one.ie's API contract.
4. **Auth UI in `one-ie/one/web/auth/`** — passkey-only with WebAuthn recovery codes. Worth grafting onto one.ie's richer auth flows, or skip? Default: skip (one.ie's `src/components/auth/` is fuller).
5. **Astro 6.2.2 bump.** one.ie is on 6.1.7. Diff is patch-level for our purposes but verify CF adapter v13 is fully compatible.

---

## 8. Classifier (per `one.ie/one/template-plan.md` §0)

| Prior | State | Note |
| --- | --- | --- |
| Spec locked | **No** | This doc IS the spec; locks on user sign-off |
| Variance known | Mostly yes | Three streams identified; topology open |
| Exit scalar | Per-wave | W1: verify pass + canary green; W2: package tests pass; W3: docs in sync; W4: deploy clean |
| Files known | Yes | Recon enumerated paths |

→ `mode: full`, `lifecycle: evolution`. W1 cycles inside it can run lean once the design-token spec is in place.

---

## 9. Threat model row

What this defends:
- Wallet stack identity (no key-derivation rewrite).
- Production deploy continuity (one trunk, one deploy script, one set of workers).
- Opensource publishing surface (one canonical `@oneie/*`).

What it accepts:
- Brief surface inconsistency between `one.ie` and `one-ie/one/web/` while W1 is in flight (web demo will diverge until repointed at substrate).
- One round of dependency churn (astro 6.1 → 6.2, plus AI SDK v6 + motion + xyflow + rive additions).
- `.claude/` skill list churn (a few new skills, paths shift).

What it does NOT accept:
- Any change to `src/schema/*.tql`, `src/engine/*.ts`, `src/components/u/lib/{vault,signer}/*`, `src/lib/{auth,human-unit,api-auth}.ts`. If a UI port appears to need one, **stop and emit `spec-change`**.

---

*Trunk: `one.ie/`. Surface upgrades from `one-ie/one/web/`. Packages publish from `one-ie/one/`. Wallets never move. Three streams, four waves, one deploy.*
