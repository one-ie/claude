# CLAUDE.md — `.claude/`

Claude Code harness. Commands, skills, rules, hooks, and subagents.

## Structure

```
.claude/
├── commands/      # /see, /create, /do, /close, /sync, /deploy, /browser
├── skills/        # /typedb, /sui, /astro, /react19, /shadcn, /reactflow, /deploy, /writer
├── rules/         # Auto-loaded by glob: engine.md, react.md, astro.md, ui.md, design.md, api.md, documentation.md
├── agents/        # w1-recon, w2-decide, w3-edit, w4-verify
├── hooks/         # Shell hooks wired to events
└── settings.json  # Tool permissions, env vars, model defaults
```

## Loading order

| Layer | When |
|-------|------|
| `rules/` | Auto-loaded per file glob — `*.astro` → `astro.md`, `*.tsx` → `react.md` + `ui.md` + `design.md` |
| `skills/` | Explicit invocation or trigger match |
| `commands/` | User types `/<name>` |
| `agents/` | Spawned via Agent tool — **isolated context, no parent CLAUDE.mds inherited** |
| `hooks/` | Fire on events per `settings.json` |

## Hooks wired (settings.json)

| Event | Matcher | Hooks |
|-------|---------|-------|
| PreToolUse | Edit/Write/MultiEdit | gate-guard (block), config-protect (block), compact-hint |
| PostToolUse | Read | read-tracker |
| PostToolUse | Write/Edit | post-edit-check |
| PostToolUse | Write/Edit/MultiEdit | sync-todo-docs, design-check (block) |
| PostToolUse | * | tool-signal |
| TaskCompleted | * | task-complete-verify (block) |
| Stop | * | session-end-verify, stop-reflect |
| SessionStart | * | session-start |

`hooks/lib/` (hook.sh, signal.sh) are shared helpers, not wired directly.

## The /do lifecycle

`/do <anything>` — idea → goal → promise → survey → spec → todo → code → tests → proof → docs → release. Walks the artifact spine, writing what's missing and skipping what exists. The BUILD engine inside is W0→W4 (recon → decide → edit → verify, rubric ≥ 0.65).

Full contract: `commands/do.md`

## Creating todo files

**Always use `plans/template-todo.md` as the base when creating any `*-todo.md` file.**

```
cp plans/template-todo.md plans/<feature>-todo.md
# then fill in the frontmatter + cycles
```

Never write a `-todo.md` from scratch — the template encodes the frontmatter contract (parallel_budget, batches, shared_recon, source_of_truth, existing_primitives) that `/do` reads at plan start.

## Don't

- Don't add commands without a numeric close
- Don't hardcode API keys in `settings.json` — use env vars
- Don't write skills that bypass the 3 locked rules — extend them

## See also

- `agents/` — subagent prompts (self-contained — don't inherit parent CLAUDE.mds)
- `../plans/patterns.md` — closed loop, sandwich, zero returns
