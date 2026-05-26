# 14-development — gap analysis

Source promise: `text/14-development.md`.
Code reality: `sdk/`, `cli/`, `mcp/`, `python/`, root `README.md`.
Rule: verb-surface parity (see `feedback_verb_surface_parity.md`) — every verb must be reachable from every surface.

---

## Promise

- "Three ways to build": chat / markdown / IDE.
- "Four surfaces, one substrate": CLI / API / SDK / MCP — every action reachable from every surface.
- **CLI: 29 verbs** grouped substrate(12) / deploy(5) / commerce(8) / observability(4), plus a `doctor` verb (4 self-checks, exits 0 only when all pass) and a `tail` verb (SSE live stream).
- **CLI ergonomics**: `--output json` on every verb, `--dry-run` on every mutator, shell completion (bash/zsh/fish), REPL mode, profiles, no-install first run via `npx oneie`.
- **MCP**: 42 tools, install + IDE config block, `createRouter()`/`register()` for custom extension.
- **Python**: `oneie run agent.md` boots uAgents Protocol, registers Almanac, OpenRouter client.
- **Deploy in 3 commands**: `npx oneie init` → `npx oneie agent agents/<client>/` → `npx oneie deploy`. Floor: 107s across 4 services with health checks.
- **Local dev**: `oneie dev` starts 4 ports (4321/8787/8788/8789); `oneie doctor` confirms 4-line wiring readout; `agent --watch` hot-reloads markdown.
- **SDK**: `import { ONE } from '@oneie/sdk'` with 6 verbs + reads; closed-loop ask() taxonomy enforced at compile time; `parse()` + `syncAgent()` from markdown.
- **README quickstart**: `npx oneie` is a single command that scaffolds + deploys.

---

## Code reality

### SDK (`sdk/src/client.ts`, 645 lines)

**Strong.** `SubstrateClient` (aliased `OneieClient`) ships ~50 typed methods covering every substrate verb plus pay/skills/groups/inbox/chat/state/listMarket/hire/bounty/publish/revenue/export/listAgents/agentHistory/rollback/closeLoop. The `ask()` method genuinely returns the 4-outcome union (`result | timeout | dissolved | failure`).

Constructor name `SubstrateClient`, not the promised `ONE`. README shows `import { ONE } from '@oneie/sdk'` and `new ONE({…})` — that export does not exist. Aliased `OneieClient` exists but no `ONE` alias. **Documentation/code drift.**

`one.signal(receiver, data)` — signature matches the promise. `one.ask(receiver, data, timeoutMs?)` — extra arg vs docs but compatible. `one.mark(edge, strength=1)`, `one.warn(edge, strength=1)`, `one.fade()`, `one.highways(limit)`, `one.recall()`, `one.reveal()`, `one.forget()`, `one.frontier()`, `one.follow()` all present.

`one.know()` is **deprecated stub** that returns `{}` (line 260-262). Promise positions `know` as a first-class substrate read. README docs it in the 6-verb table without note.

`parse()` / `syncAgent(markdown|input)` exist as a method on the client (line 449). README and copy show `import { parse, syncAgent } from '@oneie/sdk'` — top-level `parse` export not visible in `index.ts`. Drift.

### CLI (`cli/src/index.ts`, 34 lines)

**Weak vs the promise.** The root program registers exactly 5 sub-command groups: `agent`, `skill`, `auth`, `dev`, `group`. There is no top-level `signal`, `ask`, `mark`, `warn`, `fade`, `follow`, `select`, `recall`, `reveal`, `forget`, `frontier`, `know`, `highways`, `pay`, `hire`, `bounty`, `commend`, `flag`, `status`, `capabilities`, `publish`, `stats`, `health`, `revenue`, `export`, `init`, `deploy`, `claw`, `sync`, `doctor`, or `tail`.

Counted against the promised inventory:
- Substrate (12): **0/12 wired.**
- Deploy (5: `init`, `agent`, `deploy`, `claw`, `sync`): **1/5** (`agent`).
- Commerce (8): **0/8.**
- Observability (4: `stats`, `health`, `revenue`, `export`): **0/4.**
- `doctor`, `tail`: **0/2.**

Sub-verbs that **do** ship under `agent`: `new`, `validate`, `lint`, `compile`, `serve`, `publish`, `pull`, `unpublish`, `sign`, `verify`, `eval`, `diff`, `dev`, `list`, `history`, `rollback`, `ai-edit`, `templates`, `fork`. Under `skill`: `new`, `emit`, `publish`, `refresh`, `import`, `list`, `unimport`, `validate`, `eval`. Real, useful, but they don't count toward the 29-verb claim.

Ergonomics:
- `--json` flag is **global** on the root program, not per-verb `--output json`. Output is JSON-on-flag-only — close enough.
- `--dry-run` is **not present** on any mutating verb.
- Shell completion (bash/zsh/fish): **none.**
- REPL: **none.**
- `--profile` / profiles: **none** (only `homedir()/.config/oneie/key` single-key auth).
- `npx oneie` first-run experience: the README claims it "clones the platform, creates your org, wires Claude Code" — repo has **no `init` command** that does this. Running bare `oneie` falls through to commander's default help.

`agent eval`'s `--slug` remote mode exists, uses `/api/chat` with substring match (`text.toLowerCase().includes(expect.toLowerCase())`) — that's a smoke test, not an eval harness. Local mode greps the prompt body for the expect string, which doesn't run the model at all (line 235-238).

`agent ai-edit` (lines 361-437) calls `api.anthropic.com` directly and requires `ANTHROPIC_API_KEY` — bypasses substrate entirely; out of place in a CLI that claims substrate-only operation.

`agent serve` (line 60) just prints `{ ok: true, status: 'listening' }` and exits — **stub, doesn't actually serve.**

`agent sign` (line 170) returns `bundle: 'pending — run oneie publish to trigger Sigstore'` — **stub.**

`skill publish` returns `{ ok: false, reason: 'agentskills.io API key required' }` regardless — **stub.**

`skill refresh` returns `refreshed: 0, failed: 0` regardless — **stub.**

`skill eval` returns `passed: 0, failed: 0, total: 0` regardless — **stub.**

### MCP (`mcp/src/index.ts` + 4 tool files, ~609 lines)

**Real and matches the promise closely.** `MCP_TOOLS` exposes:
- substrate (13): `signal`, `ask`, `mark`, `warn`, `fade`, `follow`, `select`, `recall`, `reveal`, `forget`, `frontier`, `know`, `highways`
- lifecycle (14): auth_agent, sync_agent, publish_agent, pull_agent, unpublish_agent, list_agents, agent_history, rollback_agent, discover_skill, register, pay, list_skills, unimport_skill
- observability (8): stats, health, revenue, frontiers_global, export_units, export_highways, ingest_event, chat_turn
- discovery (3): scaffold_agent, list_agents, get_agent

Total **38 tools** (close to promised 42). `createRouter()` + `register()` extension API exists exactly as promised in the copy's FAQ.

Wiring config block in `mcp/CLAUDE.md` uses env vars `ONE_API_URL` / `ONE_API_KEY`; copy uses `ONEIE_API_URL` / `ONEIE_API_KEY`. **Env-var name drift between doc and code.**

### Python (`python/oneie/`, 5 files, 160 lines)

**Thin.** `oneie run agent.md` exists (`cli.py`). `Agent` class loads markdown and runs on Fetch.ai uAgents (`agent.py`). `OpenRouterClient` (`openrouter.py`) exists. Almanac registration (`almanac.py`) exists.

`__init__.py` exports `Agent` only — no `signal`/`ask`/substrate REST client. Promise: "Python developers call `POST /api/signal`, `GET /api/loop/highways`, and every other substrate endpoint". The package does **not** wrap them — the copy implies a parallel Python client, the reality is just markdown-load + uAgents shim. A Python team building on ONE has to hand-roll `requests` calls.

No `pyproject.toml` console_scripts entry shown for `oneie` command-line wiring beyond the `click.group()` in `cli.py`.

### Deploy

`oneie deploy` **does not exist as a CLI verb.** `cli/src/dev.ts` wraps `wrangler dev` and handles `--remote` / migrations. The CLI has **no `init`** (no project scaffold) and **no `deploy`** (no `wrangler deploy --env production` wrapper).

Promise's worked example:
```
npx oneie init
npx oneie agent agents/client-name/
npx oneie deploy
```
- Command 1: missing.
- Command 2: `oneie agent <dir>` is not a verb (no positional arg form; sub-verbs are `new`, `validate`, etc.). Closest match is `agent publish <path>` per-file.
- Command 3: missing.

107s build-time claim, 4-service deploy claim, health checks claim: **no harness exists** in this repo to produce or measure these numbers. They live in `one.ie/`'s pipeline, not in `one-ie/one/` what an open-source consumer gets.

---

## Gaps

1. **CLI verb-surface parity is broken.** Promise claims 29 substrate/deploy/commerce/observability verbs at the top level; ship count is 0 for substrate, 0 for commerce, 0 for observability, 1 of 5 for deploy. A developer who reads `text/14-development.md` will type `oneie signal chairman --data '…'` and hit "unknown command".

2. **`npx oneie` does nothing.** README's headline command (single command to scaffold + deploy) has no implementation — bare invocation falls through to help text.

3. **`oneie init` / `oneie deploy` missing.** The "deploy in 3 commands" promise can't be executed at all.

4. **`oneie doctor` missing.** Promise puts it in CI gates ("CI pipelines call `oneie doctor` as a pre-deploy gate"). Not implemented.

5. **`oneie tail` missing.** Promise: "watch the substrate respond to live conversation in real time". Not implemented.

6. **SDK export name drift.** Copy and README use `import { ONE } from '@oneie/sdk'`; only `SubstrateClient` and `OneieClient` are exported. New devs copy-pasting from the docs hit "ONE is not exported".

7. **SDK top-level `parse`/`syncAgent` exports missing.** Copy and `sdk/CLAUDE.md` show `import { parse, syncAgent } from '@oneie/sdk'`. `index.ts` re-exports `schemas.ts`/`skills.ts`/etc but no `parse` symbol is visible there; `syncAgent` exists only as a method on `SubstrateClient`.

8. **`one.know()` is deprecated stub but still in the 6-verb canon.** Either un-deprecate it or strip it from README's verb table and from `sdk/CLAUDE.md`'s "seven verbs" matrix.

9. **Several `agent` / `skill` sub-verbs are stubs returning `ok: true` with no work.** `agent serve`, `agent sign`, `skill publish`, `skill refresh`, `skill eval`. Promise treats them as live ("Run agent as local A2A + MCP server on port 8000"). Misleading.

10. **`agent eval` doesn't run a model locally.** Local mode greps the prompt body — that's not an eval. Promise sells evals as part of the dev loop.

11. **Python SDK gap.** Promise: Python teams can use every substrate endpoint and "Python and TypeScript teams can work on the same substrate simultaneously". Reality: no Python REST client at all — just `Agent` markdown loader + uAgents. The "objection-handler" answer in the copy is materially overstated.

12. **MCP env-var naming drift.** Copy uses `ONEIE_API_URL`/`ONEIE_API_KEY`; `mcp/CLAUDE.md` and source use `ONE_API_URL`/`ONE_API_KEY`.

13. **No `--dry-run`, no shell completion, no REPL, no profiles.** All four are sold as core ergonomics in the copy; none ship.

14. **No `doctor` self-check output format** — the promise even shows the rendered table format. No code renders it.

15. **107s deploy time, 4-service deploy, health-check guarantee** are unfalsifiable in this repo. The copy speaks for `one.ie/`'s pipeline; an external consumer cloning `one-ie/one` and following the README cannot reproduce.

16. **`agent ai-edit` calls Anthropic directly.** Bypasses substrate; substrate-as-only-truth thesis (no parallel control plane) is silently broken.

17. **`MCP_VERSION` is `0.3.0`** but the README, copy and SDK docs imply a stable surface. Versioning signals "experimental" while the marketing copy promises stability and a deprecation contract.

---

## Recommended improvements

**P0 — make the promise true at the surface a new dev hits first**

1. Implement `oneie` (bare) and `oneie init` as a one-shot scaffold: clone template, create config dir, write key, render next-step output. The README's headline command must run end-to-end.
2. Implement `oneie deploy` as a `wrangler deploy --env production` wrapper that prints per-service deploy ms + health latency lines. Pull the rendering from the promise copy verbatim.
3. Implement `oneie doctor` with the exact 4-check output the copy shows (`Config`, `API Key`, `Substrate`, `TypeDB`).
4. Wire top-level substrate verbs (`signal`, `ask`, `mark`, `warn`, `highways`, `stats`, `health`) as thin shims over `SubstrateClient`. Each is ~10 lines of commander glue. This alone closes the verb-surface parity gap for the substrate(12) + observability(4) rows.

**P1 — SDK doc/code reconciliation (zero behaviour change)**

5. Add `export { SubstrateClient as ONE } from './client.js'` in `sdk/src/index.ts`. One line, fixes every copy example.
6. Add top-level `parse` and `syncAgent` re-exports (or fix every doc that imports them as top-level symbols).
7. Decide on `know()`: either implement against `signal("learning:know")` per the MCP table or remove from the 6/7-verb tables across README, `sdk/CLAUDE.md`, copy.
8. Standardise on **one** env-var prefix. Pick `ONEIE_*` (matches package name + CLI key path) and rename `ONE_API_URL`/`ONE_API_KEY` in `mcp/`.

**P2 — make the stubs honest**

9. Either implement `agent serve`, `agent sign`, `skill publish`, `skill refresh`, `skill eval` — or have them exit non-zero with "not implemented in this version; see <issue>" so consumers don't ship pipelines that silently pass.
10. Replace `agent eval` local mode with a real eval: load model via OpenRouter, run input through prompt, score expected substring on the LLM output, return pass/fail with token counts.
11. Add `--dry-run` to every mutator (`agent publish/unpublish/rollback/ai-edit`, `skill import/unimport`). Single shared flag through `out()`.

**P3 — commerce, ergonomics, observability**

12. Add CLI verbs: `pay`, `hire`, `bounty`, `commend`, `flag`, `status`, `capabilities`, `publish`, `revenue`, `export`, `tail`, `claw`, `sync`, `init`, `deploy`. All shimmable in <20 lines each against existing SDK methods. Targets the remaining 0/4 observability + 0/8 commerce + 4/5 deploy gaps.
13. Add shell completion via commander's built-in `completion` plugin or `tabtab`. One-time install.
14. Add REPL via `node:repl` with the SDK pre-bound as `one`. Reduce the "try-an-API-without-writing-code" friction the copy keeps invoking.

**P4 — Python**

15. Ship `oneie.client.SubstrateClient` (Python) — 8 methods (signal/ask/mark/warn/fade/follow/highways/stats), each one `httpx.post` against `/api/<verb>`. Match TypeScript signatures.
16. Add `__init__.py` re-exports so `from oneie import signal, ask, mark, warn` works.
17. Add `pyproject.toml` `[project.scripts]` for `oneie = "oneie.cli:main"`.

**P5 — claims that need a measurement harness**

18. Add `oneie deploy --measure` that captures per-service deploy ms + post-deploy health latency, prints the exact table the copy shows. If the numbers don't hit the 107s floor, the copy needs an update — not the other way around.
19. Add a `test/promise.test.ts` that asserts: every verb listed in `text/14-development.md` exists in the CLI; every method listed in the copy's SDK section exists in `sdk/src/client.ts`; every env-var name appears with one spelling across `text/`, `sdk/`, `mcp/`, `cli/`.

---

## Files to touch

| File | Change |
|---|---|
| `cli/src/index.ts` | Register new top-level commands: `signal`, `ask`, `mark`, `warn`, `highways`, `stats`, `health`, `init`, `deploy`, `doctor`, `tail`, `pay`, `hire`, `bounty`, `commend`, `flag`, `status`, `capabilities`, `publish`, `revenue`, `export`, `claw`, `sync`, `recall`, `reveal`, `forget`, `frontier`, `follow`, `select`, `fade`. Default action on bare `oneie` → init wizard. |
| `cli/src/init.ts` (new) | Scaffold project: `wrangler.toml`, `agents/`, sample `agent.md`, write `~/.config/oneie/key` if missing, print next-step. |
| `cli/src/deploy.ts` (new) | `wrangler deploy --env production` wrapper with per-service timing + health-check rendering. |
| `cli/src/doctor.ts` (new) | 4-check renderer: config, API key, substrate (`SubstrateClient.health()`), TypeDB (`/typedb/health`). Exit 0 iff all pass. |
| `cli/src/tail.ts` (new) | SSE client against `/api/events` (or substrate stream endpoint), pretty-print to stdout. |
| `cli/src/substrate.ts` (new) | Thin commander shims for the 12 substrate verbs over `SubstrateClient`. |
| `cli/src/commerce.ts` (new) | Thin shims for `pay`, `hire`, `bounty`, `commend`, `flag`, `status`, `capabilities`, `publish`. |
| `cli/src/observability.ts` (new) | Thin shims for `stats`, `health`, `revenue`, `export`. |
| `cli/src/agent.ts` | Replace stubs (`serve`, `sign`) with real impls or `exitCode=2 "not implemented"`. Fix `eval` local mode. Add `--dry-run` to mutators. |
| `cli/src/skill.ts` | Replace stubs (`publish`, `refresh`, `eval`) with real impls or non-zero exit. |
| `cli/src/completion.ts` (new) | Shell-completion install verb. |
| `cli/src/repl.ts` (new) | `node:repl` with `one` SDK pre-bound. |
| `sdk/src/index.ts` | Add `export { SubstrateClient as ONE } from './client.js'`. Add top-level `parse` and `syncAgent` re-exports (or fix docs). |
| `sdk/src/client.ts` | Either implement `know()` against `signal('learning:know')` or remove + delete from 6-verb tables. |
| `mcp/src/env.ts` | Standardise env-var prefix to `ONEIE_*`; alias old names with deprecation warning. |
| `mcp/CLAUDE.md` | Update wiring example to `ONEIE_API_URL` / `ONEIE_API_KEY`. |
| `python/oneie/client.py` (new) | `SubstrateClient` Python class mirroring TS verbs over `httpx`. |
| `python/oneie/__init__.py` | Re-export `signal`, `ask`, `mark`, `warn`, `SubstrateClient`. |
| `python/pyproject.toml` | Add `[project.scripts]` `oneie = "oneie.cli:main"`. |
| `README.md` | Replace verb table's `know` row if removed. Confirm `npx oneie` flow once `init` ships. |
| `text/14-development.md` | Either: (a) reduce the 29-verb claim until P3 lands, or (b) lock the implementation roadmap to ship it. Same for "Python and TypeScript teams can work simultaneously" — qualify until P4 lands. |
| `test/promise.test.ts` (new) | Cross-check: every verb in `text/14-development.md` exists; every SDK symbol in copy exists; one env-var spelling across repo. CI gate. |
