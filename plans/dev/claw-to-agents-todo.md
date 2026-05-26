---
title: Rename claw → agents (worker, folder, URL, references)
slug: claw-to-agents
type: plan
tier: simple
mode: maintenance
tags: [refactor, naming, infra, cf-workers]

parallel_budget:
  haiku:   8
  sonnet:  6
  opus:    1

batches:
  - [C1]          # free the namespace — markdown agents/ → personas/
  - [C2]          # rename worker folder + wrangler name
  - [C3]          # cascade references across web/sdk/mcp/cli/docs
  - [C4]          # deploy + verify + retire old claw URL

shared_recon:
  - claw/wrangler.toml
  - claw/src/index.ts
  - web/src/lib/claw-registry.ts
  - CLAUDE.md
  - one/CLAUDE.md
  - claw-to-agents-todo.md

source_of_truth:
  - claw/wrangler.toml
  - web/src/lib/claw-registry.ts
  - web/src/components/peer/PeerThread.tsx
  - CLAUDE.md

existing_primitives:
  - claw/src/index.ts: Hono app with /health, /signal/:group, /messages/:group, /message, /webhook/:channel — keeps shape, only the worker name changes
  - web/src/lib/claw-registry.ts: per-workspace claw URL resolver — renamed to agents-registry.ts, points to *-agents.oneie.workers.dev
  - claw/src/personas.ts: bot personas keyed by name — proves "personas" is already the internal name for what agents/*.md describes
  - claw/src/agents/builder.ts: ToolLoopAgent factory — already named `agents/` inside claw, validating the rename direction

show: false

escape:
  condition: "C4 W4 fails health check after 2 deploys"
  action: "halt; investigate DNS / route propagation before redeploying; do not delete old claw worker"

context_triggers:
  - pattern: "telegram|discord|webhook"
    inject: "claw/README.md § Webhook setup — new URL format agents.<acct>.workers.dev/webhook/<channel>"
  - pattern: "PII_ENVELOPE_KEY"
    inject: "claw/wrangler.toml comment — shared with web; do not regenerate during rename"
---

# Rename claw → agents

**Goal:** Every "claw" reference becomes "agents" — worker name, folder, URL, code paths, docs — so the runtime layer is named after what it does (runs agents) instead of after a metaphor.

**Exit:**
1. `curl https://agents.oneie.workers.dev/health` returns `{"status":"ok","service":"agents"}`
2. `https://app.one.ie/peer/boq` still sends + receives signals (now via new URL)
3. `grep -rln "claw" one-ie/one --include="*.{ts,tsx,astro,toml,json,md}" | grep -v deprecated | grep -v node_modules | grep -v .dev/` returns ≤ 5 matches (allowed: changelog / migration notes referencing the old name)
4. `cd web && bun run verify` exits 0

---

## Decisions locked before W1

| Question | Answer | Why |
|---|---|---|
| Worker URL | `agents.oneie.workers.dev` (workers.dev) + `agents.one.ie` (custom domain, optional in C4) | Self-describing; matches the public brand the user already picked |
| Worker folder | `one-ie/one/claw/` → `one-ie/one/agents/` | Folder matches worker matches URL — one identifier through the stack |
| Markdown folder collision | `one-ie/one/agents/*.md` → `one-ie/one/personas/*.md` | Frees `agents/` namespace for the worker; matches `claw/src/personas.ts` which already calls them personas internally |
| Old worker | Keep `claw.oneie.workers.dev` alive for 7 days after C4 deploys, then delete | Some inbound webhooks (Telegram, Discord) may still point at the old URL; gives time to rotate without losing messages |
| `clawRegistry` → `agentsRegistry` | Yes, rename export | Caller readability — `getAgentsUrl(workspace)` is clearer |
| D1 / KV bindings | Unchanged | `binding = "DB"`, `binding = "KV"` are inside-worker names; the rename touches the outside only. Migration history stays |
| Pheromone key format `claw:<group>` | Stays as `claw:<group>` in D1 paths | Path identity is data; renaming it would invalidate every existing highway. The label is internal; the URL is external |

---

## Reuse contract

This is a rename, not a build. No new files except:
- `web/src/lib/agents-registry.ts` (replaces `claw-registry.ts`)
- `agents/wrangler.toml` (renamed from `claw/wrangler.toml`)

Everything else is path-rewrite + grep-replace. Any cycle that proposes a new component fails the compose-or-construct test by definition — escalate to a separate plan.

---

## Parallel execution plan

```
   C1 (rename markdown agents/ → personas/)
        │  (folder must be empty before C2 can use the name)
        ▼
   C2 (rename worker folder claw/ → agents/, wrangler name)
        │  (folder exists before C3 references can land)
        ▼
   C3 (cascade references — web, sdk, mcp, cli, docs)
        │  (all callers point to the new URL before deploy)
        ▼
   C4 (deploy agents worker, verify health, keep claw alive 7d)
```

Real arrows — C2 needs the markdown rename done so `agents/` is free; C3 needs the new code in place; C4 needs the references updated so the live URL change actually goes somewhere.

---

## C1 — Free the `agents/` namespace

**Goal:** Move all markdown agent definitions out of `agents/` so the directory can be used for the worker.

**Files to rename** (W1 enumerates exactly):
- `one-ie/one/agents/*.md` → `one-ie/one/personas/*.md`
- `one-ie/one/agents/templates/` → `one-ie/one/personas/templates/`
- `one-ie/one/agents/CLAUDE.md` → `one-ie/one/personas/CLAUDE.md` (update its self-reference)
- `one-ie/one/agents/AGENTS.md` → `one-ie/one/personas/AGENTS.md` or delete if redundant with root `AGENTS.md`
- `one-ie/one/agents/README.md` → `one-ie/one/personas/README.md`

**Code that loads them** (W1 greps):
- `claw/src/personas.ts` — confirm it doesn't import from `agents/*.md` paths (it likely defines personas inline; verify)
- `cli/src/agent.ts` — `oneie agent new/validate/lint/compile/serve/publish/sign/verify/eval/diff` — find any hardcoded `agents/` paths
- `cli/src/templates.ts` — likely reads `agents/templates/`
- `web/src/lib/agent-md.ts`, `agent-loader.ts`, `agents.ts` — check if they parse markdown from `agents/`
- `mcp/src/tools/discovery.ts` — likely lists agents
- Any `.claude/` reference to `agents/`

**W3 actions:**
- `git mv one-ie/one/agents one-ie/one/personas`
- Update every grep hit from C1 W1 to use `personas/` instead of `agents/`
- Update root `AGENTS.md` if it points into the folder

**W4 demo:**
```bash
test -d one-ie/one/personas && \
test ! -d one-ie/one/agents && \
cd one-ie/one/cli && bun run build && \
node dist/index.js agent --help | grep -q "Usage" && \
echo pass
```

---

## C2 — Rename worker folder + wrangler name

**Goal:** `one-ie/one/claw/` → `one-ie/one/agents/`. Wrangler worker `name = "agents"`. Internal D1/KV bindings stay (`DB`, `KV`).

**Files modified:**
- `git mv one-ie/one/claw one-ie/one/agents`
- `one-ie/one/agents/wrangler.toml`:
  - `name = "claw"` → `name = "agents"`
  - All comments mentioning "claw" → "agents" (preserve `claw:<group>` pheromone key comments as historical context)
- `one-ie/one/agents/package.json`:
  - `"name": "claw"` → `"name": "agents"` (or `@oneie/agents` if scoped — match other packages)
- `one-ie/one/agents/src/index.ts`:
  - Route doc comment header (lines 1-10) — "Claw — edge-native AI agents" → "Agents — edge-native AI agent runtime"
  - `service: 'claw'` in `/health` response → `service: 'agents'`
  - Pheromone key `claw:${group}` stays (data identity — see decision table)
- `one-ie/one/agents/src/agents/builder.ts` — path already nested as `agents/agents/builder.ts` after the move; rename to `agents/src/runtime/builder.ts` to avoid `agents/agents/` ugliness
- `one-ie/one/agents/README.md` — title + all references
- `one-ie/one/agents/AGENTS.md` if present

**Internal imports** (mechanical — `from './agents/builder'` → `from './runtime/builder'`):
- `agents/src/index.ts`
- Any file in `agents/src/` that imports from the `agents/` subfolder

**W4 demo:**
```bash
test -d one-ie/one/agents/src && \
test ! -d one-ie/one/claw && \
cd one-ie/one/agents && bunx wrangler deploy --dry-run 2>&1 | grep -q "Total Upload" && \
echo pass
```

---

## C3 — Cascade references across the repo

**Goal:** Every consumer of claw URLs / claw package / clawRegistry now references agents.

**Files to update** (W1 enumerates with the 150-hit grep from this convo):

| Surface | Files | Change |
|---|---|---|
| **web/lib** | `web/src/lib/claw-registry.ts` → `web/src/lib/agents-registry.ts` | Rename file, rename export `clawRegistry` → `agentsRegistry`, `getClawUrl` → `getAgentsUrl`. URLs in the map: `*-claw.oneie.workers.dev` → `*-agents.oneie.workers.dev` |
| **web/components** | `web/src/components/peer/PeerThread.tsx` | `CLAW_URL = 'https://claw.oneie.workers.dev'` → `AGENTS_URL = 'https://agents.oneie.workers.dev'` |
| **web/components** | `web/src/components/in/Inbox.tsx` | `getClawUrl(...)` → `getAgentsUrl(...)` |
| **web/api** | Any `/api/*` that calls claw URLs | grep for `claw.oneie.workers.dev` → `agents.oneie.workers.dev` |
| **web/wrangler.toml** | Webhook URLs in comments | replace |
| **sdk/src** | Any default URLs | grep + replace |
| **mcp/src** | Default URLs in `env.ts` or tool definitions | grep + replace |
| **cli/src** | Default URLs in `agent.ts`, `dev.ts` | grep + replace |
| **CLAUDE.md (root)** | "claw" mentions, slot map table | rewrite the row |
| **one-ie/one/CLAUDE.md** | Same | rewrite |
| **one-ie/one/.claude/CLAUDE.md** | Same | rewrite |
| **one/dictionary.md, one/integration.md** | Architecture diagrams | rewrite |
| **README.md (root + one-ie/one)** | First-mention | rewrite |
| **All other `*-todo.md`** | References to claw | rewrite if active; leave if archived |

**Allowed survivors** (count toward the ≤ 5 grep hits in exit criterion):
- `agents/src/index.ts` pheromone key comment `claw:<group>` (data identity)
- A CHANGELOG / migration note explaining the rename
- Old commit messages (not in working tree, not relevant)

**W4 demo:**
```bash
HITS=$(grep -rln "claw" one-ie/one --include="*.ts" --include="*.tsx" --include="*.astro" --include="*.toml" --include="*.json" --include="*.md" 2>/dev/null | grep -v node_modules | grep -v ".dev/" | grep -v "CHANGELOG" | wc -l)
test "$HITS" -le 5 && \
cd web && bun run build 2>&1 | tail -1 | grep -q "Complete" && \
echo "pass (residual claw hits=$HITS)"
```

---

## C4 — Deploy agents worker; retire old claw URL

**Goal:** `agents.oneie.workers.dev` serves traffic; web app uses new URL end-to-end; claw kept alive 7d as fallback.

**Deploy sequence:**
1. `cd one-ie/one/agents && bunx wrangler deploy` → creates new worker `agents` at `agents.oneie.workers.dev`
2. `bunx wrangler d1 migrations apply DB --remote` (D1 binding `DB` is the same physical DB — `database_id = ac240779…` unchanged. Migrations are idempotent — no-op if already applied)
3. Verify: `curl https://agents.oneie.workers.dev/health` → `{"status":"ok","service":"agents"}`
4. Round-trip test:
   ```bash
   curl -X POST https://agents.oneie.workers.dev/signal/boq -H 'Content-Type: application/json' -d '{"sender":"system","content":"agents rename smoke test"}'
   curl https://agents.oneie.workers.dev/messages/boq | grep -q "agents rename smoke test"
   ```
5. Deploy web: `cd web && bunx wrangler deploy --env production` → `app.one.ie/peer/boq` now hits new URL
6. Visit `https://app.one.ie/peer/boq?as=tony`, send a message, confirm it appears

**Old worker keep-alive:**
- Do NOT delete `claw.oneie.workers.dev` in C4
- Add a calendar reminder / TODO comment: `// CLAW_KEEPALIVE: delete after 2026-05-25` in `agents/wrangler.toml`
- After 7 days, when nothing has hit `claw.oneie.workers.dev/webhook/*` for 24h, delete via `bunx wrangler delete --name claw`

**W4 demo:**
```bash
curl -s https://agents.oneie.workers.dev/health | grep -q '"service":"agents"' && \
curl -s -X POST https://agents.oneie.workers.dev/signal/boq -H 'Content-Type: application/json' -d '{"sender":"verify","content":"c4-demo"}' | grep -q '"ok":true' && \
sleep 1 && \
curl -s https://agents.oneie.workers.dev/messages/boq | grep -q 'c4-demo' && \
curl -s -I https://app.one.ie/peer/boq | head -1 | grep -q "200" && \
echo pass
```

---

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Telegram/Discord webhooks point at old `claw.oneie.workers.dev/webhook/*` | High (bot owners forget to rotate) | Keep claw alive 7d; document rotate command in CHANGELOG |
| `agents:<group>` vs `claw:<group>` pheromone key split | None — we keep `claw:` as the data identifier | Decision locked in table above |
| `git mv` loses file history | Low — `git mv` preserves history; `git log --follow` works | Use `git mv` not `mv` + `git add` |
| Custom domain `agents.one.ie` clashes with another worker | Unknown — depends on DNS | C4 leaves custom domain OUT of initial deploy; add later as a separate cycle if desired |
| Web's `getClawUrl()` callers we didn't grep | Medium | C3 W4 runs `tsc --noEmit` — any missed rename is a compile error |
| `agents/agents/builder.ts` ugly path after `git mv claw agents` | Certain | C2 includes the `agents/builder.ts` → `runtime/builder.ts` rename in the same diff |

---

## What this plan deliberately does NOT touch

- **The 8 substrate overlaps** between web and claw (signal lane, pheromone code, messages table, LLM calls, etc.) — that's a separate consolidation plan (`signal-lane-unify-todo.md` next).
- **The skill `execute()` stub** in `agents/src/skill-tools.ts` — separate `nanoclaw-skills-todo.md`.
- **The custom domain `agents.one.ie`** — DNS work; ship workers.dev URL first, custom domain in a follow-up if needed.
- **The pheromone path key `claw:<group>`** — data identity; renaming would invalidate every highway in D1.

Scope creep that touches any of the above fails the plan; surface it as a new TODO.

---

## Done definition

```
✓ agents.oneie.workers.dev/health → {"status":"ok","service":"agents"}
✓ app.one.ie/peer/boq sends + receives through new URL
✓ ≤ 5 "claw" string hits in the working tree (data identifiers + changelog only)
✓ bun run verify exits 0 across web/, agents/, sdk/, mcp/, cli/
✓ Old claw worker still alive (deletion is a separate dated TODO)
```

When all five tick, close the cycle. Tag pheromone `mode:maintenance lifecycle:evolution`.
