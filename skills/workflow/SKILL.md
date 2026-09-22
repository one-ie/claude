---
name: workflow
description: Author and run ONE workflows from Claude Code — a DAG of typed steps where every step compiles to signal(receiver, data). Use when creating or editing a workflow, applying a validated diff to one, running or stopping a run, reading step stats, or choosing between the eight locked step kinds (trigger, tool, skill, agent, condition, human, delay, sell). Triggers — "create a workflow", "edit this workflow", "run the workflow", "why did this step not fire", "which step kind should this be".
---

# Workflow — Author + Run SOPs from Claude Code

**A workflow is a DAG of typed steps; every step compiles to `signal(receiver, data)`. Edit it as a validated diff, run it, watch the path learn.**

Copy-structure source: `packages/claude/skills/signal/SKILL.md`.

## The eight step kinds (LOCKED)

`trigger · tool · skill · agent · condition · human · delay · sell` — read top-to-bottom: what starts it · what does the work (tool→skill→agent autonomy ladder) · what shapes the flow. `human`/`delay`/`sell` suspend the run; `condition` routes; `sell` resumes on `checkout:resume`. Full contract: `one-ie/CLAUDE.md § Workflow step kinds` + `text/workflows-plan.md`.

## The tools (MCP + CLI, same receivers)

| Goal | MCP tool | CLI |
|---|---|---|
| what do I have? | `workflow_list` | `oneie workflow list --slug S` |
| inspect a graph | `workflow_get` | `oneie workflow pull <id> --slug S` |
| change it | `workflow_apply_diff` (simulate-first) | `oneie workflow push <id> <diff.json> --slug S [--commit]` |
| run it | `workflow_run` | `oneie workflow run <id> --slug S` |
| monitor runs | `workflow_runs` | — |

## The diff grammar (WorkflowDiff)

`@oneie/sdk` `WorkflowDiffSchema` — `add[]` (tempId·kind·name·config·position?) · `remove[]` (step ids) · `connect[]` (source·target·condition?) · `disconnect[]` · `update[]` (stepId·field·value).

- **Simulate first.** `workflow_apply_diff` validates the WHOLE diff — DAG acyclicity included — without persisting and returns the projected step count. Pass `commit:true` (MCP) / `--commit` (CLI) to persist.
- **`update.field`** accepts `name` · `config` · `position` only. `exit-condition` and `owner` are TypeDB-owned and return **`unsupported_field`** — the grammar refuses them loudly rather than silently dropping.
- **tempId → real id.** New steps carry a client-side `tempId`; `connect`/`update`/`$step.<tempId>.field` refs are rewritten to the persisted id on commit.

## Recipe — "add a human approval before the sell step"

1. `workflow_get` → find the sell step's id and its incoming edge.
2. `workflow_apply_diff` (simulate): `add` a `human` step (config `{"mode":"approve"}`), `disconnect` the old edge into sell, `connect` prev→human and human→sell.
3. Review the projected step count, then re-send with `commit:true`.

## Connect Claude Code

`claude mcp add oneie -e ONEIE_API_KEY=<your-api-key> -e ONEIE_API_URL=https://api.one.ie -- npx -y @oneie/mcp` — mint a key at `/profile/api-keys` (never paste key bytes into a shared file).

## Works With

| Skill | Because |
|---|---|
| `/signal` | every step compiles to one signal |
| `/mcp` | the five `workflow_*` tools |
| `/cli` | the `oneie workflow` group |

## See Also

- `text/workflows-plan.md` — the machine's spec
- `text/dictionary.md` — canonical names
- `one-ie/CLAUDE.md § Workflow step kinds`