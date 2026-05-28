# /do cheat-sheet

The whole lifecycle on one page. Sources: [`text/000-do.md`](../text/000-do.md) (phases), [`plans/templates.md`](../plans/templates.md) (templates/skills/agents), [`.claude/commands/do-new.md`](../.claude/commands/do-new.md) (tiers/gates).

## Phases

| Phase | Purpose | Template | Skills + agents | Model · effort | Gate |
|---|---|---|---|---|---|
| **P0 GOAL** | idea → checkable outcome | — | `do-intent`, `do-tier.sh` | opus · low | you confirm goal + tier |
| **P1 FRAME** | sell it before building | `template-frame.md` | `writer`, `copywriting` | sonnet · medium | promise concrete enough to verify against |
| **P2 SURVEY** | find what exists | — (`do-survey.sh`) | `oneie`, `w1-recon`, `Explore` | haiku · low | no rebuilding what exists |
| **P2b INVESTIGATE** | understand legacy code first | — | `typedb`, `w1-recon` | haiku→sonnet · medium | root cause + blast radius known |
| **P3 SPEC** | design + reconcile | `template-spec.md` | `typedb`, `signal`, `Plan`, `w2-decide`, `do-reconcile.sh` | opus · high | unambiguous, reuses primitives, failure modes answered |
| **P4 PLAN** | spec → tasks | `template-todo.md` | `/create todo`, `w2-decide`, `do-analyze.sh` | sonnet · medium | coverage 100%, no critical gaps |
| **P5 BUILD** | write code, reuse shapes | `agent-template.md` | `astro`/`react19`/`shadcn`/`ai-ui`/`ai-sdk`/`reactflow`/`hono`/`cloudflare`, `w3-edit` | sonnet · low–medium | new primitives justified, all states handled |
| **P6 TEST** | goal-asserting tests | — | `vitest`, `playwright-best-practices`, `webapp-testing` | sonnet · low | every deliverable has a green test, written first |
| **P7 VERIFY** | score the rubric | — | `perf`, `typecheck`, `accessibility`, `find-bugs`, `w4-verify`, `pr-review-toolkit:*` | haiku · medium | composite ≥ 0.65, goal-fit ≥ 0.50, delta_tsc ≤ 0 |
| **P8 PROVE** | live proof = promise | — | `webapp-testing`, `accessibility`, `do-prove.sh` | sonnet · low | proven live, matches promise, merges only on pass |
| **P9 TEACH** | docs alongside code | — | `tutorial`, `writer` | sonnet · medium | stale-name 0, links ok, contracts current |
| **P10 SHIP** | surface it | — | `/release`, `/deploy` | sonnet · low | reachable + release recorded |
| **P11 LEARN** | close the loop | — | `/do --improve`, `/close` | haiku · low / bash | result + learning written, nothing dangling |

## Tier spines (what each tier walks)

| Tier | Stops |
|---|---|
| **PATCH** | code (edit + W4 verify gate; 0 spawns) |
| **FIX** | survey → [investigate if legacy] → code → tests → prove |
| **FEATURE** | promise → survey → spec ▸clarify → todo ▸analyze → code → tests → proof → docs → release |
| **SCHEMA** | = FEATURE + substrate reconcile at max |

## Gates

| Gate | Trigger | Behavior |
|---|---|---|
| **CLARIFY** | FEATURE/SCHEMA spec | ≤5 questions, edits spec in place |
| **ANALYZE** | FIX+ todo | `do-analyze.sh` — CRITICAL exit 1 blocks BUILD |
| **W4 rubric** | every cycle | `0.35·goal-fit + 0.20·security + 0.20·stability + 0.15·simplicity + 0.10·speed`; gate composite ≥ 0.65 AND goal-fit ≥ 0.50 |
| **doc-sync** | W4 | stale-name 0, links ok, contract mtime current |
| **PROVE-merge** | FEATURE/SCHEMA | built in a worktree; merge to trunk only on PROVE pass, abandon on fail |
