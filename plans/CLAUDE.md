# CLAUDE.md — `plans/`

Spec, architecture, and todo docs for the ONE monorepo. Design decisions live here; code lives in packages.

## Canonical docs (always consult)

| Doc | Locks |
|-----|-------|
| `dictionary.md` | Canonical names, 6 verbs, dimension → runtime map |
| `one-ontology.md` | 6 dimensions, actor/group/thing types |
| `patterns.md` | Closed loop, zero returns, deterministic sandwich |
| `rubrics.md` | Code rubric (security/stability/simplicity/speed) + agent rubric — gate 0.65 |
| `lifecycle.md` | Agent journey stages |
| `dsl.md` | Signal grammar |

## File naming

| Pattern | Purpose |
|---------|---------|
| `<feature>.md` | Spec or architecture doc |
| `<feature>-todo.md` | Active implementation plan (W1-W4 cycle) |

## How to use

- Before naming anything → `dictionary.md`
- Before a `/do` cycle → find or create `<feature>-todo.md`
- Architecture questions → check `plans/` first, then code

## Sub-folders

| Folder | Purpose |
|--------|---------|
| `improve/` | Improvement proposals — check before proposing structural changes |
| `world/` | World-level architecture docs |

## See also

- Root `CLAUDE.md` — package map, 6 dimensions, 3 locked rules
- `.claude/rules/documentation.md` — when to update which doc
- `.claude/commands/do.md` — `/do` cycle (W1-W4) that consumes `-todo.md` files
