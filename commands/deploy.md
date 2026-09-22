# /deploy

> **Every deploy spawns `release-manager`, and it always reports to the CEO.**
> Not just the slash command — `/deploy`, `./deploy`, `bash .claude/scripts/deploy.sh`,
> `release.sh promote`, `release.sh ship`, and any plain-English "ship it" / "deploy the
> site" all take this door. The conductor does not run the doors itself. First action:
>
> ```
> Agent({ subagent_type: "release-manager", model: "opus",
>         prompt: "Read one.ie/ai/agents/release-manager/agent.md and .claude/skills/deploy/REFERENCE.md, then run /deploy <args>. Target: <sha | PR | origin/main>. Authorised to ship: <yes | gates-only>." })
> ```
>
> Pass `model: "opus"` (the generated roster maps a specialist to Sonnet). Tell it
> to read the source prompt — a session started before the last `one-agents.mjs`
> run holds the older roster copy. The agent opens and closes with a post to the
> CEO in `/u/one/in` (group `release`) — see its § Report to the CEO. The
> conductor relays the agent's closing report to the operator; it never re-runs
> the gates to double-check a green, and never ships past a held one.
>
> **This is not advice about a slash command — it is the rule for the last two doors
> of the loop** (`../../CLAUDE.md § The dev → prod loop`). The only work the asked
> session does itself is deciding the target sha and relaying the report. If you find
> yourself typing `release.sh` or `wrangler` in the conductor, you have already skipped
> the agent — and with it the CEO post that is the only record the release happened.
>
> **And the doctor holds the box.** `deploy.sh` reads `health.sh --box --json`
> before its first gate and refuses an UNHEALTHY box (`DEPLOY_SKIP_DOCTOR=1`
> overrides). When it does, spawn `doctor` and let release-manager wait:
>
> ```
> Agent({ subagent_type: "doctor", model: "opus",
>         prompt: "health.sh says: <why>. Reclaim what nothing is coming back for, then report the verdict." })
> ```
>
> A deploy runs five gates. On a paging box each one runs long, and a slow gate
> is indistinguishable from a red one at the wall clock — which is how a good
> tree gets diagnosed as broken code. The box comes first.

**Skills:** `/cloudflare` (Workers auth) · `/signal` (deploy:success / deploy:degraded) · `deploy` (the run as tracked work) · `.claude/skills/deploy/REFERENCE.md` (every trap this page used to carry)

**Before a production deploy, run `/sweep`** — it lands every finished branch into
`dev`, pays **one** gate on the integrated tree instead of one per branch, sweeps
the worktrees, and ends by naming the sha to promote. `/deploy` then has one tree
to think about instead of six.

Ship all five services to Cloudflare. Deterministic sandwich — W0 baseline, build, smoke, approval, parallel deploy, health.

> **Production door (2026-09-05): `bash .claude/scripts/release.sh promote <sha>` then `ship`** — prod ships from `.release/`, a clean checkout carrying a full-suite receipt for its exact tree. `./deploy` stays the pipeline; `release.sh` is what points it at a tree that cannot be dirty. Loop: `../../CLAUDE.md § The dev → prod loop` · plan: `text/release-path-plan.md`.
>
> **Monorepo (2026-06-04):** all services live in one repo (`Server/one-ie`). Deploy each via `wrangler deploy` from its folder — **never via repo push, no CI**. Deploys are run locally.
>
> **Production cutover (2026-05-23):** Astro site runs on **CF Workers with Static Assets** (not Pages). Production target is **`https://one.ie`** via the `one-prod` worker. Deploy command is **`wrangler deploy` (no `--env` flag)** — see the deploy-target trap note below.
>
> **⚠️ Deploy-target trap (found 2026-07-03; fixed in-tree 2026-07-04, verified still fixed 2026-08-02 — `one.ie/web/package.json`'s `deploy` script is now `npm run build && wrangler deploy` with no `--env`, and `wrangler.toml` has no `[env.production]` block. The trap is only reachable by hand-typing `--env` now):** `one.ie`'s custom domain is bound to Worker service **`one-prod`** (confirmed via Cloudflare API). `one.ie/web/wrangler.toml` has no explicit `legacy_env` setting, which means Wrangler's **default legacy-environment behavior applies** for TOML configs: passing `--env production` appends `-production` to the top-level `name`, deploying to a *different* script, `one-prod-production` — which nothing routes to. Three consecutive deploys to `one-prod-production` showed zero effect on `https://one.ie` until `wrangler deploy` was run **without** `--env production`. **Always deploy this worker bare: `wrangler deploy` (no `--env` flag).** Do not re-add `--env production` out of habit — it silently ships to a decoy. **The trap is not limited to `wrangler deploy`** — `wrangler secret put`/`secret delete` take the same `--env` flag and silently target the same `one-prod-production` decoy (hit 2026-07-06 provisioning `UPGRADE_LINK_SECRET`: it landed on the decoy first, invisibly — no error, just a secret nothing reads). Any bare `wrangler <subcommand>` against this worker: **no `--env` flag, ever.**
>
> **Environment model:**
> - **Production (live):** `https://one.ie` — `one-prod` worker, deployed from `one.ie/web/` via bare `wrangler deploy` (**not** `--env production` — see trap note above)
> - **Gateway (live, stable):** `https://api.one.ie` — `one-gateway` worker
> - **Pay gateway (live, stable):** `https://pay.one.ie` — `one-core-worker`, deployed from `pay/backend/` via `bun run deploy` (no `--env` flag; no explicit `[[routes]]` block in its wrangler.toml either — same bare-deploy discipline as `one-prod`). Not part of the original "4 services" naming (found 2026-07-05 after a commit there went unshipped for a full deploy cycle) — treat it as a 5th first-class deploy target, not an afterthought.
> - **Dev (live again since 2026-08-25):** `https://dev.one.ie` — the **`one-dev`** worker, deployed from `one.ie/web/` by `.claude/scripts/deploy-dev.sh` (reachable as **`./deploy dev`**). Its config is *derived from the Astro build output* by `.claude/scripts/gen-dev-config.py` — never hand-rolled — so it cannot drift from what production ships. That script does two things worth knowing: it renames the worker to `one-dev` + binds `dev.one.ie`, and it **strips every cron**. Dev shares production's D1 and KV bindings, so inheriting prod's schedules would mean two workers running the same handlers against the same rows — double sends, double syncs, races. The first dev deploy shipped 6 schedules including `*/5 * * * *` before this was caught. **Dev observes prod data; it must never also drive prod's clock.**
>   - **`dev.one.ie` is not a data sandbox.** It reads and writes production's rows byte-for-byte. Ship code there freely; treat its DATA as production.
>   - **The RETIRED thing was `one-substrate`**, the old CF-Pages-built dev project whose git integration was disconnected 2026-06-04. That project stays dead — do not deploy it, and do not confuse it with `one-dev`. The sibling tree `apps/dev.one.ie` is still dead code: do not build or ship it. Nothing deploys via repo push.
> - **Legacy idle (rollback only — do not deploy):**
>   - `https://oneie.pages.dev` — old Pages project for `one.ie` ("Ecommerce Playbook" content). Re-attach `one.ie` to this project to roll back.
>   - `demo.one.ie`, `onestudio.dev` — still bound to the prior `one-demo` worker. `one-demo` stays in the account untouched for rollback; redeploying `one-demo` would push stale code, so don't.
>   - `app.one.ie` moved OFF `one-demo` to `one-prod` on 2026-08-06 — it is now an ordinary verified custom domain for `group:one` (D1 `domains` row) and serves `/u/one/*`. Declared in `one.ie/web/wrangler.toml` as a Custom Domain.
>
> The custom-domain detach step (Pages → Worker) is done manually via the CF API (no in-repo script today).

## Run it — `./deploy`

**`.claude/scripts/deploy.sh` is the authority for the procedure. This doc never
carries a second copy of the steps** — same discipline as `astro.config.mjs §
vite.ssr.external`. When a step changes, change the script; edit here only when
what a gate *means* changes.

```bash
./deploy dev            # one.ie/web → one-dev (dev.one.ie) — FAST gate, no approval
./deploy                # full pipeline — 5 services (PRODUCTION)
./deploy astro          # one-prod only
./deploy workers        # api + sync + channels
./deploy gateway|sync|agents|pay
./deploy --dry-run      # print every command, ship nothing
```

`./deploy` is a repo-root wrapper that `exec`s `.claude/scripts/deploy.sh`;
either path works, and `/deploy` in Claude Code runs the same script rather than
retyping its steps.

### The two tiers — one command, two destinations

| | `./deploy dev` | `./deploy` |
|---|---|---|
| Destination | `dev.one.ie` (`one-dev`) | `one.ie` + the other four services |
| Gate | **FAST lane** (`verify:fast`) | **FULL** (`FULL_VERIFY=1`, every test) |
| Approval prompt | none | yes, unless `--yes` |
| Migrations | none | `d1 migrations apply --remote` |
| Crons | stripped | shipped |
| Who ships it | agents, finishing a loop | a human, promoting |

**`./deploy dev` ships whatever tree it is invoked from — which is `main`.** To
put a *branch* on dev.one.ie, and to open the PR that proposes it, use
`bash .claude/scripts/land.sh <branch> --pr --deploy` — one command for
gate → dev → probe → PR. See "Branch → dev → PR → main" below.

`./deploy dev` exits into `deploy-dev.sh` immediately rather than threading a
flag through the production pipeline — a different destination with a different
gate is a different procedure, and `deploy-dev.sh` stays its authority. The one
production flag that carries over is `--skip-tests`, which becomes the dev
script's `DEV_SKIP_GATE=1`.

**A fast pass is never reported as a full pass.** Dev going green says the fast
lane passed and `dev.one.ie` answered 200 — nothing more. Promotion to
production runs every test again, because the full suite is the gate that has
actually caught the regressions.

| Mode | Ships |
|---|---|
| *(none)* | full pipeline — gates + 5 services + health |
| `astro` | Astro Worker only (re-bundle after UI changes) |
| `workers` | Gateway + Sync + Agents (no Astro rebuild) |
| `gateway` · `sync` · `agents` · `pay` | that one service |

Flags: `--check-creds` (self-test the credential ladder, ship nothing) ·
`--skip-tests` · `--skip-typecheck` · `--skip-build` · `--skip-migrations`
· `--skip-health` · `--allow-dirty` · `-y/--yes` (or `DEPLOY_YES=1`) ·
`-n/--dry-run`. Exit 0 = `deploy:success`; a failed probe exits 1 and prints the
rollback command. Logs: `.deploy-logs/deploy-<stamp>.log` (gitignored) plus one
per service for the parallel wave.

### What the script does NOT do — and won't

Two things stay human, by design:

- **Commit / PR / merge** (its own section below). Commit messages and PR bodies
  need judgment. The script's first gate refuses a dirty tree
  (`--allow-dirty` overrides) so the deploy and the history can't disagree.
- **Known-flaky triage.** On a red suite it prints the failing files and stops,
  pointing at the allowlist. Deciding "that one's the DoH network gap" is a read
  of the evidence, not a rule. The ONE exception is now mechanised: a suite whose
  every failure is the shared TypeDB cluster refusing to answer is classified and
  waived by `typedb-flake-check.sh` — see "The TypeDB flake waiver" below. That
  check is deliberately narrow; everything else is still your read.

## The gates — what each one asserts

The script runs these in order. Named here so a failure message means something;
the commands themselves live in the script.

| Gate | Asserts |
|---|---|
| **0 · Tree** | working tree clean (`git status --porcelain` empty). First, so a dirty tree fails in a second instead of after a full W0 |
| **1a · Typecheck** | `bunx tsc --noEmit` clean in all 5 services. Builds `packages/sdk` first when its `dist/` is missing — `one.ie/web` and `channels` resolve SDK types from there, and an unbuilt `dist` fakes a wall of `TS2307` |
| **1b · Tests** | the full suite in `one.ie/web`, as TWO concurrent lanes — see below. Red blocks, except a classified TypeDB outage; the script won't wave anything else through for you |
| **3 · Build** | `NODE_ENV=production bun run build` in `one.ie/web` (~30–35s). Emits `dist/server/` + static assets via `@astrojs/cloudflare@13`, patches `wrangler.json` with DO bindings, symlinks `.dev.vars` |
| **0.4 · Credentials** | Runs **first**, before the slow gates — one curl is cheap, discovering a bad credential after a 2m14s build is not. Resolves ONE credential from an ordered ladder (ambient env → `.env.local` → `one.ie/web/.env` → OAuth), probing each rung with `curl /user` — ground truth, unlike `wrangler whoami`, which answers about whichever credential *that one directory* surfaces. Exports the winner to all five service subshells, so a per-dir `.env` can no longer make two consecutive steps use two different keys. Logs the source as `len=… sha=…`, never bytes, then asserts all five services report the same account id. Self-test: `--check-creds` |
| **1c · Heavy-gate scheduling** | that vitest and the astro build only overlap when the box can pay for it. Priced in **memory, not cores** — see the section below |
| **5 · Smoke** | `dist/server/` exists; all 5 `wrangler.toml`s present. Warns if `one.ie/web/wrangler.toml` grew an `[env.production]` block — that's the decoy trap coming back |
| **6 · Approval** | on `main`, prompts for a literal `yes`. Other branches auto-approve |
| **6.5 · Migrations** | `wrangler d1 migrations apply DB --remote` — **no `--env`**. "✅ No migrations to apply!" is a pass. Failure blocks: never ship worker code ahead of its schema |
| **7 · Deploy** | Gateway + Sync + Agents + Pay in parallel (~10s each), then Astro (~30s, largest bundle). Every call bare — no `--env`, ever |
| **8 · Health** | 4 HTTP probes × 3 tries with backoff, cache-busted with `?_t=`. Sync is cron-only — its clean deploy IS its health signal |

## Branch → dev → PR → main — `land.sh`, not this doc

**`.claude/scripts/land.sh` is the authority for this procedure**, the same way
`deploy.sh` is the authority for the pipeline. It replaced the hand-rolled
`git worktree add` + `gh pr create` recipe that used to sit here; that recipe
was a second copy of a procedure and it rotted — it still told you to
`git switch main` in the shared tree, which `hook:branch-pin` refuses.

```bash
bash .claude/scripts/land.sh feat/x --pr --deploy --probe / --probe /pricing
```

One command, four steps, in this order:

| # | Step | What it proves |
|---|---|---|
| 1 | **gate** — `verify:fast` in the branch's own worktree | the branch is green ON ITS OWN. Not that it survives the trunk — `--pr` deliberately does not merge main in, so the reviewer sees what the branch added and GitHub computes the merge |
| 2 | **dev** — `$wt/.claude/scripts/deploy-dev.sh` | the branch RUNS. It ships the *worktree's* tree, because `deploy-dev.sh` derives its own ROOT from its own path — `$ROOT`'s copy would ship main and call it the branch |
| 3 | **probe** — `do-prove.sh`, both bases pinned to dev | the routes answer on dev, under the LANDING RULE. Not `curl / → 200`, which a redirect to `/signin` satisfies |
| 4 | **PR** — `pr-body.sh` → `gh pr create`/`edit` | a reviewer gets the diff, the trunk drift, the mergeability, the gate label and the dev URL. Re-running UPDATES the open PR, never duplicates it |

Then a human merges the PR, and **promotion to `one.ie` is still `./deploy`** —
the full gate, from `.release/`. Nothing above touches production.

Four things that are load-bearing, each of which read as a pass before it was fixed:

- **dev.one.ie is one slot, and it writes production's rows.** `--pr --deploy`
  takes exactly one branch; with two, the second overwrites the first while the
  first is being probed. Ship code there freely; treat its DATA as production.
- **Both probe bases are pinned to dev.** `do-prove.sh` falls back to
  `PROVE_PROD_URL` (default `https://one.ie`) when its dev base is silent — an
  unreachable dev would otherwise prove *production* and report it as the branch
  passing.
- **The probe's route COUNT is read, not its exit code.** `PROVE: skipped (no
  reachable environment)` exits 0. An unrun probe is not a pass.
- **The gate is paid once, except under `--quick`.** Step 2 passes
  `DEV_SKIP_GATE=1` because step 1 just ran `verify:fast` in that same tree.
  Under `--quick` step 1 was tsc only — not the fast lane — so `deploy-dev.sh`
  runs its own gate before anything reaches dev.

`land.sh` still has its other two doors: bare (merge main in → gate → `--ff-only`
main → optionally one dev deploy for the batch) and `--pr` alone (gate → PR, no
dev). The commit itself stays human — a commit message needs judgment, and
`deploy.sh`'s first gate refuses a dirty tree so the deploy and the history
cannot disagree.

---

## Rollback

```bash
# Workers — rollback to previous version
cd one.ie/web && bunx wrangler rollback --name one-prod        # production

# Redeploy a Worker from its last-committed code WITHOUT touching the shared tree.
# Never `git checkout HEAD -- .` here: it silently destroys every uncommitted
# change under that path, including a concurrent session's. `hook:branch-pin`
# permits pathspec restores, so nothing will stop you — that's why it's banned by
# convention. `git stash` is blocked outright by hook:git-add-guard.
# Cut a throwaway worktree at the good commit and deploy from there instead.
# A fresh worktree has NO node_modules — install before wrangler, or bunx fails:
git worktree add /tmp/rollback-wt <good-sha>
(cd /tmp/rollback-wt/api && bun install && unset CLOUDFLARE_API_TOKEN && bunx wrangler deploy)
git worktree remove /tmp/rollback-wt
```

`wrangler rollback` is the cheaper move when the last good code is simply the
previous deployment — it needs no worktree and no rebuild.

---


---

## The reference — traps, numbers, forensics

Everything below the operating surface moved to **`.claude/skills/deploy/REFERENCE.md`**
on 2026-09-17, because this page is read by a conductor deciding *who* deploys and
by an agent that then needs *all* of it. Two audiences, two lengths. Nothing was
deleted — the file carries the same sections, byte for byte:

| In the reference | What it holds |
|---|---|
| The suite runs as two lanes | why the full gate is two keys, and what that costs a caller |
| Two disproved speed ideas · why the gates are not all parallel | measurements that closed a question — read before re-opening it |
| The vitest gate hangs | open, characterised, unexplained |
| Bundle size rules 1–5 · verified numbers · diagnosis | the 3 MiB CF free-tier ceiling and how each rule buys headroom |
| Service map · auth (CRITICAL) · mode-specific notes | the five targets, the credential ladder, `./deploy astro|workers|pay` |
| The TypeDB flake waiver · known-flaky allowlist | the red suite a deploy may ship past, and its bounds |
| First-time setup · logs · gotchas (`9103`, `7403`) | provisioning, and the two auth failures that are not the same symptom |

`release-manager` is told to read it. If you are reading this page to *run* a
deploy, you are on the wrong side of the door — see the top of this file.
