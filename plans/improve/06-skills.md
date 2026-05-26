# 06-skills — gap analysis

## Promise

Per `text/06-skills.md`:

- Skill = priced, versioned, callable markdown unit with frontmatter (`name`, `description`, `tags`, `price`, `inputs`, `evals`) + instruction body.
- **6 CLI verbs** cover full lifecycle: `new`, `validate`, `emit`, `publish`, `import`, `eval` — plus `refresh` and `list`. `--json` on all.
- Library ships **5 working skills**: `qualify-lead`, `draft-email`, `brand-voice-check`, `handle-complaint`, `escalate`.
- **Marketplace** at agentskills.io: browse, import in one command, author keeps source, platform takes no cut.
- **L4 economic loop**: every call → `mark`/`warn` on path → attribution → credit flows from caller workspace to author workspace.
- **Versioning** with semver; `refresh` is opt-in; major bumps need eval pass; dependency conflicts caught at import.
- **Eval gate**: 1.0 pass rate required before publish; runs against real model; analytics surface declining pass-rate regressions.
- **Visibility**: `public` (marketplace) vs `private` (whitelist-only); signing chain proves authorship.
- **Composition**: skills call skills; revenue attribution per skill in chain.
- **Cascade** (per memory `project_client_extensibility.md`): workspace > agency > platform; clients add skills by editing frontmatter only.

## Code reality

**CLI (`cli/src/skill.ts`)** — verbs present, depth thin:

| Verb | Status |
|---|---|
| `new` | Scaffolds 11-line template — no `inputs`, no `evals`, no `version` |
| `validate` | Real — uses `skill-parser.ts`, walks dirs, reports diagnostics |
| `emit` | Trivial — copies file to `<name>/SKILL.md` directory shape |
| `publish` | **Stub** — returns `{ ok: false, reason: 'agentskills.io API key required' }` |
| `import` | Real — POSTs to `/api/skill/import`; needs `ONEIE_API_KEY` |
| `refresh` | **Stub** — returns `{ refreshed: 0, failed: 0 }` without doing anything |
| `eval` | **Stub** — returns `{ passed: 0, failed: 0, total: 0 }` always |
| `list` | Real — fetches `/api/skills/workspace?slug=` |
| `unimport` | Real — DELETE on `/api/skill/:name` |

Missing entirely: `unpublish`, `version`/`bump`, sign/verify, conflict-check at import, staging-vs-prod, marketplace search.

**Parser (`cli/src/skill-parser.ts` + `web/src/lib/skill/parser.ts`)** — duplicated, hand-rolled YAML; recognises `name`, `description`, `tags`, `triggers`; **does not parse or validate** `inputs`, `evals`, `version`, `license`, `compatibility`, `accepts`. Two copies that must stay in sync (TODO comment admits this). No JSON Schema. `Skill` loader (`web/src/lib/skill/loader.ts`) surfaces typed fields but their parsing is permissive.

**Import (`web/src/lib/skill/import.ts`)** — fetches from `agentskills.io`, `raw.githubusercontent.com`, or `github.com`; SHA-16 hashes to R2 cache key; writes `<slug>/skills/<name>/SKILL.md`. `withPrice()` injects `price:` line. No signature check. No version pin. No conflict diagnostics. `refresh` re-fetches but no diff/changelog.

**Claw execution (`claw/src/skill-tools.ts`)** — loads `${userId}/skills/` from KV; wraps each in an AI SDK `tool()`. **Critical: `execute` returns a placeholder string `[${skillName}] processed: ${input}`**. The skill body is never used. No model invocation. No `mark`/`warn`. No price-to-credit flow. No attribution. No L4 loop. Skills do not actually run.

`claw/src/prompt.ts` line 48 advertises skills to the model (`Available skills: ${pack.tools.join(', ')}`) but the tool stub returns nonsense, so the model "calls" a no-op.

**Web UI** — `web/src/pages/skills.astro` + `SkillsView.tsx` (workspace-scoped list with toggle), `web/src/pages/u/[slug]/skills/index.astro` (per-profile gallery — renders title/price/version/tags/description from frontmatter; "View" link goes to `[name].astro`). No browse page for agentskills.io marketplace. No publish UI. No import-from-URL UI in the workspace view. No call-count / pass-rate / attribution analytics.

**`agents/` frontmatter** — only `agents/README.md` (`skills: [handle-complaint, escalate]`) and `agents/CLAUDE.md` (contract block) reference skills. **None of the 5 promised library skills** (`qualify-lead`, `draft-email`, `brand-voice-check`, `handle-complaint`, `escalate`) exist as files in `agents/` or anywhere under `/skills/`. `.claude/skills/` holds dev-tooling packs (`astro`, `react19`, `typedb`, `writer`, ...), which are Claude Code harness skills, not product skills.

**`skills-lock.json`** — exists at repo root with one entry (`ai-sdk` from `vercel/ai`). No version pin field; just `sourceType`, `skillPath`, `computedHash`. No dependency graph. No conflict resolution.

**Roles / cascade (`web/roles.md`)** — declares `skills.visible`, `skills.pricing-display`, `features.skills` enable flag, and references skills in role permission tables. Marketing copy says "Workspace > agency > platform" cascade. Code surfaces this in `SkillsView` (one list, one slug) but no merge-from-parent logic visible.

## Gaps

| # | Gap | Severity | Location |
|---|---|---|---|
| 1 | **Skills don't execute.** `claw/src/skill-tools.ts` returns a placeholder string; no model call, no body interpolation, no `mark`/`warn` | Blocker | `claw/src/skill-tools.ts:30` |
| 2 | **`eval` is a stub.** Returns `{ passed:0, failed:0, total:0 }` regardless of input | Blocker for the "eval gate" promise | `cli/src/skill.ts:184` |
| 3 | **`publish` is a stub.** Returns "API key required" error; no agentskills.io upload, no publish receipt | Blocker for marketplace | `cli/src/skill.ts:47` |
| 4 | **`refresh` is a stub.** Returns `{ refreshed: 0, failed: 0 }` without fetching | Blocker for the versioning promise | `cli/src/skill.ts:54` |
| 5 | **Zero library skills shipped.** `qualify-lead`, `draft-email`, `brand-voice-check`, `handle-complaint`, `escalate` — none exist as files | Promise inversion (text claims "5 working skills ship today") | `agents/`, `skills/` |
| 6 | **No attribution / L4 loop.** No record of which workspace called which skill, no credit ledger, no `revenue` tagged on path | Blocker for marketplace economics | `claw/`, `web/src/lib/skill/` |
| 7 | **No version field handling.** Parser ignores `version`; loader exposes it but import doesn't pin; no semver matching; `refresh` doesn't diff versions | Blocker for the dependency-boundary promise | `cli/src/skill-parser.ts`, `web/src/lib/skill/import.ts` |
| 8 | **No `inputs` parsing.** Parser doesn't validate; AI SDK tool uses fixed `z.object({ input: z.string() })` regardless | Frontmatter contract not enforced | `claw/src/skill-tools.ts:27` |
| 9 | **No signing / authorship proof.** Promise mentions cryptographic proof; no code touches signing | Marketplace-trust promise unmet | — |
| 10 | **No conflict check at import.** Promise: "import that breaks dependency fails with diagnostic". Code just overwrites | `web/src/lib/skill/import.ts:74` |
| 11 | **No `visibility: private` whitelist.** Field readable, no enforcement at import | `web/src/pages/api/skill/import.ts` |
| 12 | **No analytics dashboard.** Per-skill call counts, pass rates, attribution — none surfaced | Promise repeated four times in text | `web/src/pages/` |
| 13 | **No marketplace UI.** No browse/search page at `/skills/browse` or equivalent; only own-workspace list | Promise: "Browse the skill library" | `web/src/pages/` |
| 14 | **Two parser copies.** `cli/src/skill-parser.ts` mirrors `web/src/lib/skill/parser.ts` — TODO comment admits it should dedupe via SDK; will drift | Code-quality | both files |
| 15 | **No `evals` block in scaffold.** `oneie skill new` template omits the field the text says is the gate | Onboarding regression | `cli/src/skill.ts:13` |
| 16 | **No cascade resolution.** Workspace > agency > platform skill merge is text-only; `SkillsView` reads `/api/skills/workspace?slug=` for one slug; no parent-walk | Cascade promise unmet | `web/src/lib/skill/` |
| 17 | **Skills don't compose.** Text promises skill-calls-skill with chain attribution; no signal-emit path inside skill body interpreter (because there is no interpreter) | Blocked by #1 | `claw/src/skill-tools.ts` |
| 18 | **`agentskills.io` is a dead host.** Import resolver hardcodes it; no public registry exists yet | External dependency mismatch | `web/src/lib/skill/import.ts:4` |

## Recommended improvements

In order of unblock-radius (each row enables the rows below):

1. **Implement skill execution in claw.** Replace the placeholder in `skill-tools.ts:execute` with: load `body` from R2 → resolve `{{ inputs.X }}` templating → call configured model (`openai-compatible` provider via OpenRouter, same path as `ToolLoopAgent`) → return structured result → `mark` on success / `warn` on error → emit attribution event `skill:<name>:called` carrying author slug + caller slug + price + result hash. Parse `inputs` from frontmatter, generate the matching `z.object()` schema dynamically. This unblocks #1, #8, #17.

2. **Implement `eval` runner.** Read `evals[]` from parsed frontmatter; for each case, call the same model path as step 1 with `inputs`; deep-equal against `expected` (with tolerant key-order matching). Exit non-zero if any case fails. Wire into `publish` as a hard gate. Unblocks #2.

3. **Stand up the registry surface.** Pick one: (a) host registry on `one.ie/registry/skills/<name>/SKILL.md` (own R2, controlled), or (b) implement `agentskills.io` as a separate worker. Either way: `publish` POSTs SKILL.md + metadata to the registry; `import` from agentskills.io actually resolves. Unblocks #3, #13, #18.

4. **Ship the 5 library skills as real files.** Author `agents/skills/qualify-lead.md`, `draft-email.md`, `brand-voice-check.md`, `handle-complaint.md`, `escalate.md` — full frontmatter (inputs, evals, version 1.0.0), bodies that pass their own evals. These become both demo content and the regression suite for step 1. Unblocks #5.

5. **L4 attribution.** New TypeDB pattern: `event:skill-call` with relations to `actor:author-workspace`, `actor:caller-workspace`, `thing:skill`, scalar `price`, `outcome`. Aggregate in nightly job → expose at `/api/analytics/skills/:slug` → render dashboard. Unblocks #6, #12.

6. **Version handling.** Parser: type `version` as semver string (validate). Import: accept `name@1.2.0` and `name@~1.2.0`; resolve via registry index; pin in `skills-lock.json` per slug. Refresh: diff resolved vs locked, surface changelog from registry, require `--yes` for major bumps. Unblocks #7, plus enables #4's evolution.

7. **Conflict + visibility enforcement.** Import endpoint: check `compatibility` field against active runtime, check `inputs` schema diff vs existing version → diagnostic on incompatible; if registry record has `visibility: private`, verify caller slug in `whitelist[]`. Unblocks #10, #11.

8. **Signing.** Add `signature` field — Ed25519 over `sha256(SKILL.md)` using the author workspace's wallet key (Sui address already in agent frontmatter per `agents/CLAUDE.md`). `verify` CLI verb. Marketplace listing shows verified badge. Unblocks #9.

9. **Cascade resolution.** Generalise `/api/skills?slug=` to walk: `workspace/skills` → `agency/skills` → `platform/skills`, merge by name, mark each entry with `source: 'workspace'|'agency'|'platform'`, allow workspace to override per-skill `enabled` and `price`. SkillsView shows source badge. Unblocks #16.

10. **Dedupe parser, fix scaffold, add UI surfaces.** Move `parser.ts` to `sdk/src/skill/parser.ts`; both `cli` and `web` import from there. Update `new` scaffold to include an `evals:` block with one passing case. Add `/skills/browse` page (registry search). Closes #14, #15, #13's UI half.

## Files to touch

| File | Change |
|---|---|
| `claw/src/skill-tools.ts` | Replace placeholder `execute` with model call + body interpolation + mark/warn + attribution emit |
| `claw/src/agents/builder.ts` | Wire skill tools to substrate-middleware so finishReason → mark/warn flows |
| `cli/src/skill.ts` | Implement `eval` (read frontmatter, run model, compare); implement `publish` (POST to registry with auth); implement `refresh` (fetch + diff + re-cache); fix `new` template to include `inputs:` + `evals:` + `version:` |
| `cli/src/skill-parser.ts` | Delete after move to SDK |
| `sdk/src/skill/parser.ts` | New — canonical parser exporting `Skill` type, `parse()`, `validate()`, with `inputs`/`evals`/`version` parsing |
| `sdk/src/skill/eval.ts` | New — `runEvals(skill, model)` returning `{ passed, failed, results[] }` |
| `sdk/src/skill/sign.ts` | New — Ed25519 sign + verify helpers |
| `web/src/lib/skill/parser.ts` | Delete, re-export from `@oneie/sdk/skill` |
| `web/src/lib/skill/import.ts` | Add version pin, conflict check, signature verify, visibility/whitelist enforcement |
| `web/src/lib/skill/cascade.ts` | New — resolve workspace > agency > platform merge |
| `web/src/pages/api/skill/import.ts` | Use cascade resolver; reject on conflict/whitelist fail |
| `web/src/pages/api/skill/refresh.ts` | Actually diff and report changes |
| `web/src/pages/api/skill/publish.ts` | New — accepts SKILL.md + signature, runs eval gate, writes to registry R2 |
| `web/src/pages/api/skill/[name]/calls.ts` | New — call-count, pass-rate, attribution per skill |
| `web/src/pages/skills/browse.astro` | New — marketplace browse + search |
| `web/src/pages/u/[slug]/skills/[name].astro` | Add analytics tab (calls / pass-rate / earnings) |
| `web/src/components/skills/SkillsView.tsx` | Render `source` badge; import-from-URL form |
| `agents/skills/qualify-lead.md` | New library skill — full frontmatter + body + evals |
| `agents/skills/draft-email.md` | Same |
| `agents/skills/brand-voice-check.md` | Same |
| `agents/skills/handle-complaint.md` | Same |
| `agents/skills/escalate.md` | Same |
| `skills-lock.json` | Extend schema: per-slug pin map with `version`, `signature`, `resolved` |
| `web/src/engine/agent-md.ts` | Resolve `skills:` block via cascade; pass to claw with full body, not just name |
| `one/dictionary.md` | Add `skill-call` event, `skill-author` / `skill-caller` actor relations |
| `text/06-skills.md` | After implementation, replace "ship today" with verified call-count from L4 |
