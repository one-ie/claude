# CLAUDE.md — `one-ie/`

ONE — signal-based substrate for AI agents. Brain in TypeDB. LLM is the only probabilistic step.

## Repo structure

```
one-ie/
├── one.ie/         # Main site — Astro + React (https://one.ie)
│   ├── web/        # Astro + React UI + API routes
│   └── agents/     # Markdown agent definitions
├── packages/       # npm packages — bun workspace → github.com/one-ie/packages
│   ├── sdk/        # @oneie/sdk — core client, signals, types
│   ├── react/      # @oneie/react — React 19 hooks + context
│   ├── mcp/        # @oneie/mcp — MCP server (12 verbs + discovery)
│   └── cli/        # @oneie/cli — oneie / one bins
├── channels/       # Agent runtime worker — Hono + AI SDK → github.com/one-ie/agents
├── api/            # Gateway — TypeDB proxy → github.com/one-ie/api
├── schema/         # TypeDB .tql schema + migrations → github.com/one-ie/schema
├── sync/           # Scheduled Worker — TypeDB ↔ KV ↔ D1 ↔ SUI
├── backup/         # Scheduled Worker — KV snapshots → R2 daily
├── .claude/        # Claude Code harness → github.com/one-ie/claude
├── plans/          # All spec, todo, and architecture docs → github.com/one-ie/plans
└── text/           # Marketing copy — headlines, CTAs, page text → github.com/one-ie/text
```

## Source of truth

| Domain | Lives in |
|--------|----------|
| Web UI + API routes | `one.ie/web/` |
| TypeDB schema | `schema/` — never duplicate .tql elsewhere |
| Architecture + specs | `plans/` — design before code → github.com/one-ie/plans |
| Marketing copy | `text/` — read `.claude/product-marketing.md` voice contract → github.com/one-ie/text |
| Claude Code config | `.claude/` — commands, rules, subagents → github.com/one-ie/claude |

## The 6 dimensions (LOCKED — never rename)

| # | Dimension | What it holds |
|---|-----------|----------------|
| 1 | Groups    | Containers — worlds, teams, orgs |
| 2 | Actors    | Who acts — humans, agents, worlds |
| 3 | Things    | What exists — skills, tasks, tokens |
| 4 | Paths     | Weighted connections — strength/resistance |
| 5 | Events    | What happened — signals, payments |
| 6 | Learning  | What was discovered — hypotheses |

Dead names (never use): *knowledge, connections, people, node, scent, alarm, trail, colony*.

## The 6 verbs (LOCKED)

`signal` · `mark` · `warn` · `fade` · `follow` · `harden`

The verbs are wired across three layers:

| Layer | Where |
|---|---|
| **SDK method** | `packages/sdk/src/client.ts` — `SubstrateClient.signal()`, `.mark()`, `.warn()`, `.fade()`, `.follow()` |
| **HTTP route** | `one.ie/web/src/pages/api/{signal,mark,warn,fade,follow}/` |
| **Persistence** | `schema/one.tql` — `mark` increments `path.strength`; `warn` increments `path.resistance`; `fade` applies group `fade-rate`; `signal` writes to `signal` relation |

`harden` is exposed via `signal("learning:know")` per `packages/sdk/CLAUDE.md`. Each verb has a pre/post/inv contract — see `plans/contracts.md`. No new verb without one.

## The 3 locked rules

1. **Closed loop** — every signal closes with `mark()`, `warn()`, or `dissolve`. No silent returns.
2. **Structural time** — plan in tasks → waves → cycles. Never days/hours/weeks.
3. **Deterministic results** — every loop reports verified numbers.

Detail and code patterns: `.claude/rules/engine.md`

## Package map

| Package | What | Deployed |
|---------|------|---------|
| `one.ie/web/` | Astro site + API routes | https://one.ie |
| `channels/` | Hono + AI SDK — Telegram/Discord/HTTP/web ingress | CF Worker |
| `api/` | TypeDB proxy + WsHub DO | https://api.one.ie |
| `schema/` | TypeDB .tql + migrations | TypeDB Cloud |
| `sync/` | Scheduled sync | CF Scheduled Worker |
| `backup/` | KV → R2 archive | CF Scheduled Worker |
| `packages/sdk/` | `@oneie/sdk` — core client | npm |
| `packages/react/` | `@oneie/react` — React 19 hooks | npm |
| `packages/mcp/` | `@oneie/mcp` — MCP server | npm |
| `packages/cli/` | `@oneie/cli` — oneie / one bins | npm |

## npm packages — workspace

`packages/` is a bun workspace. To work across packages locally:

```bash
cd packages && bun install   # links packages via workspace:*
bun run build                # builds all 4 packages
```

Cross-package dep: `@oneie/react` and `@oneie/mcp` depend on `@oneie/sdk` via `workspace:*` — no publish cycle needed during local dev.

## Tech stack

- **Astro 6** — SSR on CF Workers Static Assets
- **React 19** — Actions, `use()`, transitions
- **Tailwind 4** + **shadcn/ui**
- **TypeDB 3.0** — brain: paths, classification, learning
- **Cloudflare Workers** — runtime; D1 for signals/messages, KV for snapshots, R2 for backups
- **AI SDK v6** (`ai@^6`) — streaming + tool approval protocol
- **Hono** — agent worker routing
- **OpenRouter** — default LLM; Groq opt-in

## Don't

- Don't rename dimensions, verbs, or outcomes — locked
- Don't create backend routes outside `one.ie/web/src/pages/api/`
- Don't mock TypeDB in integration tests — use real TypeDB or skip
- Don't plan in calendar time

## See also

- `one.ie/CLAUDE.md` — main site detail
- `plans/dictionary.md` — canonical names
- `.claude/CLAUDE.md` — harness (commands, rules, subagents)
