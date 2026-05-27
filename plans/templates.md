# Cycle templates, skills & agents — the per-stage registry

The canonical map of which **template**, which **skills**, and which **agents** (at which **model · effort**) run at each stage of the `/do` cycle. `text/000-do.md` is the narrative; this is the operational lookup. Keep them in sync.

Two principles govern every row:

**Progressive disclosure.** A stage loads only what it needs, when it needs it. Recon reads the last few turns and the top paths, not the whole history. A context doc is pulled only when a stage's findings match its trigger pattern. A skill's knowledge is invoked, never inlined. The default is the smallest context that lets the stage decide — you widen only on a miss.

**Parallel agents at the right effort.** Reach for the cheapest tool that can answer, then run as many as the work allows in one message. Model and effort are two separate dials:

| Model | Use for | Effort dial |
|---|---|---|
| **bash** | bit-equal checks, greps, schema validation, test exit codes | `none` — zero tokens |
| **Haiku** | recon, ambiguous binary judgments, rubric scoring | `low` lookup · `medium` judgment |
| **Sonnet** | real edits, restructures, test writing, prose | `low` mechanical · `medium` genuine edit |
| **Opus** | architecture, substrate reconciliation, the merge | `high` design · `xhigh` schema/novel |

Fan-out rule: independent agents go in **one message**, capped by the plan's `parallel_budget`. Recon and verify are embarrassingly parallel (Haiku × N). Edits are parallel per file (Sonnet × N). Only the decide stage (Opus) is single — understanding is not delegable.

---

## The registry

| Stage | Template | Skills | Agents · model · effort | Parallel? |
|---|---|---|---|---|
| **P0 GOAL** | — (inline) | `do-intent` | main context · opus · low · + `do-tier.sh` (bash) | no |
| **P1 FRAME** | `text/template-frame.md` | `writer`, `copywriting`, product-marketing voice | — · sonnet · medium | no |
| **P2 SURVEY** | — (`do-survey.sh`) | `oneie` | `w1-recon`, `Explore` · haiku · low | yes (×N) |
| **P2b INVESTIGATE** | — | `typedb` (if data) | `w1-recon` (forensic), `Explore` · haiku→sonnet · medium | yes (×N) |
| **P3 SPEC** | `plans/template-spec.md` | `typedb`, `signal` | `Plan`, `w2-decide` · opus · high · + `do-reconcile.sh` (bash) | no (single decider) |
| **P4 PLAN** | `plans/template-todo.md` | — | `/create todo`, `w2-decide` · sonnet · medium · + `do-analyze.sh` (bash) | no |
| **P5 BUILD** | (agents from `plans/agent-template.md`) | per surface: `astro`, `react19`, `shadcn`, `ai-ui`, `ai-sdk`, `reactflow`, `typedb`, `signal`, `cloudflare`, `hono`, `build` | `w3-edit` · sonnet · low–medium | yes (×N per file) |
| **P6 TEST** | — | `vitest`, `playwright-best-practices`, `webapp-testing` | `w3-edit` · sonnet · low · + test runner (bash) | yes |
| **P7 VERIFY** | — | `perf`, `typecheck`, `accessibility`, `find-bugs` | `w4-verify` + `pr-review-toolkit:*` (code-reviewer, silent-failure-hunter, type-design-analyzer, pr-test-analyzer, code-simplifier) · haiku · medium | yes (×5+) |
| **P8 PROVE** | — | `webapp-testing`, `accessibility`, `playwright-best-practices` | `/browser`, `/sync`, curl, contract test · sonnet · low | by surface |
| **P9 TEACH** | — | `tutorial`, `writer` | — · sonnet · medium | parallel with code |
| **P10 SHIP** | — | — | `/release`, `/deploy` · sonnet · low | no |
| **P11 LEARN** | — | — | `/do --improve`, `/close` · haiku · low / bash | no |

`—` means no markdown template applies (the stage is code or a bash gate, governed by its skills/agents). A skill name in `code` is invokable today; a bracketed one is the command that owns the stage.

---

## The template family

| Template | Stage | Purpose |
|---|---|---|
| `text/template-frame.md` | P1 FRAME | the promise — features, benefits, journey, UX intent, proof |
| `plans/template-spec.md` | P3 SPEC | the design — reuse verdict, reconciliation, pre-mortem, decisions, clarifications |
| `plans/template-todo.md` | P4 PLAN | the build plan — goal contract, deliverables, DAG, waves, parallel budget |
| `plans/agent-template.md` | P5 BUILD | a markdown agent definition (for `agents/`) |

Always copy the template — never write a stage artifact from scratch. The frontmatter and section contracts are what `/do` reads.

---

## See also

- `text/000-do.md` — the narrative walk-through of every stage
- `.claude/commands/do.md` — the engine (tool ladder, model routing, wave specs)
- `.claude/commands/do-lifecycle.md` — the lifecycle spec `/do` reads
- `plans/dictionary.md` · `plans/rubrics.md` — names and scoring (always in scope)
