# deploy — REFERENCE

The trap encyclopedia for `.claude/commands/deploy.md`. Split out 2026-09-17: the
command page is what a conductor reads to decide *who* deploys (the answer is
always `release-manager`); this is what that agent reads to actually do it.

Nothing here was rewritten in the split. Every section below is the text that
stood in `deploy.md`, with its measurements and dates intact — a trap loses its
authority the moment it is paraphrased.

Authority for the PROCEDURE is still `.claude/scripts/deploy.sh`, never this file.
Edit the script when a step changes; edit here only when what a gate *means* changes.

---

### The suite runs as two lanes, not one run (measured 2026-09-03)

The gate had become a coin flip. Four full runs on an **unchanged tree** gave
four different failure sets — 8, 12, 13, 8 — and every failing file in all four
was one of the 19 suites marked `real TypeDB`. Not one of the other ~1126 files
ever failed. Each run's log carried 41-72 `upstream 503` plus 25-38
`upstream 500`, and those print only *after* the retry budget is spent
(`substrate.ts:208`).

The cause is capacity, not code. `substrate.ts:56-60` already recorded it in
2026-07-25: the shared TypeDB Cloud gateway 503s **in bursts lasting seconds**,
while the retry cover is 500ms + 1000ms. Eight vitest forks against one external
singleton turn that into a dice roll — and a dice-roll gate costs far more than
it saves. The 2026-09-03 deploy spent hours on re-runs and root-cause agents for
failures that were never in the diff.

`.claude/scripts/test-lanes.sh` splits the suite by its two binding constraints
and runs them **concurrently**:

| lane | files | bound by | concurrency |
|---|---|---|---|
| `pool` | ~1126 | CPU | 8 forks |
| `typedb` | 19 | one shared gateway | serial (`--no-file-parallelism --maxWorkers=1`) |

The `typedb` lane spends its life waiting on a socket, so it costs almost no CPU
while `pool` saturates the cores: wall clock is **max(), not sum()**.

| | before | after |
|---|---|---|
| wall clock | 238-282s | **121.9s** |
| result | RED, rotating victims | **BOTH GREEN** — pool 1125 passed, typedb 19 passed |
| tests | 8-13 failing | 10940 passed |

**This is not `--no-file-parallelism` over the whole suite** — that serialises
1126 innocent files to fix 19. Every test still runs, no assertion is weakened,
nothing is skipped; only the suites sharing the external singleton are
serialised, which removes the contention at its source.

**The selector is read from the tree, never hardcoded.** It greps the
`real TypeDB` marker the suites already carry, so a new such suite joins the
serial lane automatically. A frozen list is exactly how this rots back into
flakiness — `--self-test` asserts the selector finds >0 files, is a strict
subset, and that every path it names exists.

Both lanes still go through `test-cached.sh`, so passes are memoised per lane
and a RED is still never cached. `test-full.sh` remains the one definition of
the vitest flags and hands them over as `TEST_FULL_ARGS`.

```bash
bash .claude/scripts/test-lanes.sh --list        # show the split, run nothing
bash .claude/scripts/test-lanes.sh --self-test   # prove the selector still selects
```

**Two lanes mean two `Tests N passed` lines in the log.** `TESTS_REPORT` used to
`tail -1` and reported only the 19-file lane — the first two-lane production
deploy said `Tests 143 passed` for a run that executed **10940**. It now sums the
lanes and says `(2 lanes)`. A gate that is fine while the report understates it
by two orders of magnitude is the same dishonesty as calling a fast pass a full
one.

### Making the deploy faster — two disproved ideas (measured 2026-09-03)

Recorded so nobody spends an afternoon re-deriving them. Both were plausible,
both are wrong, and the second fails in a way that reads like a pass.

**The gates are at their floor at ~256s. Rescheduling does not move them.**
From the 2026-09-03 production log:

```
vitest  256s   (the lanes, run alone: 121.9s)
build   256s   (astro's own report: 2m 13s = 133s)
gates wall-clock: 256s
```

Serial would be 133+122 = 255s — *identical*. Each gate paid ~2x its solo cost
and the overlap bought nothing, because eight vitest forks plus an 8 GiB-heap
build on a 10-core box is oversubscription, not parallelism.

The obvious next move — give the build room by capping the pool — makes it
**worse**:

| | gates wall-clock | build |
|---|---|---|
| 8 forks (baseline) | **256s** | 133s |
| 5 forks (`VERIFY_POOL_FORKS=5`) | **272s** | 209s |

Parallel, serial and capped all land at 250-270s. That is the floor for
build+suite on this hardware as currently shaped.

**The real target is import cost, and the obvious fix is blocked upstream.**
The pool lane, run solo, spends more time loading modules than running tests:

```
import 145.42s | tests 107.87s
```

`vitest.config.ts:131` sets `pool: 'forks'`, and every fork re-imports the whole
module graph independently. Threads share a module cache, so that ought to be
the win — but **vitest 4.1.7's threads pool is broken in this repo**. Every
worker dies with `The worker thread was torn down or never initialized. This is
a bug in Vitest.` Do not reach for `--pool=threads` until vitest is upgraded and
this is re-tested.

**Read the exit code, not the summary.** That broken run printed:

```
 Test Files  no tests
      Tests  no tests
   Duration  162ms
```

with `rc=1`. "no tests" in a 162ms run is a *collect crash*, one careless glance
from being reported as a clean pass — the same shape as
`vitest-collect-crash-reads-as-pass`. An empty selection is never a pass.

**What actually speeds a deploy today:** scope it. `./deploy dev` runs the fast
lane with no approval; `./deploy workers` skips the astro rebuild entirely when
`one.ie/web` did not change. The astro build is the long pole and is already
memoised by tree fingerprint — a warm tree pays none of it.

### Why the gates are not all parallel (measured 2026-08-19)

Steps 1+3 used to launch seven heavy processes with a bare `&`: five `tsc`,
vitest, and the astro build. That is not parallelism, it is a swap storm. The
astro build carries `--max-old-space-size=8192` and vitest runs a driver plus
four 1GB forks, so the two together want ~14GB — on a 24GB box where editors
and sessions are already resident.

Paging is a cliff, not a slope. Same suite, same commit, same machine:

| vitest ran… | wall-clock | outcome |
|---|---|---|
| alone | **176s** | 912 files, 7624 tests, green |
| beside the build + 5×tsc | **1145s** | 0.0% CPU, no log output, killed |

It happened twice in one day before anyone read it as anything but "tests are
slow". They are not slow — the suite's own summary accounts for only ~165s of
actual test time.

**Correction, same day: memory is NOT the proven cause of the hang.** The
serialisation below is still worth having — 14GB of overlap on a 24GB box is
real — but the 1145s runs were later reproduced with the build serialised and
the box at 41% free, no swap thrash, and no network connections held. See
"The vitest gate hangs" below. Do not cite the memory story as the explanation
for a hung gate; it explains a *slow* gate, not a *parked* one.

So the heavy gates are now **priced before they launch**: `heavy_free_gb`
reads free memory the way `lib/govern.sh` does and compares it against
`DEPLOY_HEAVY_NEED_GB` (default 14). Enough → they overlap as before. Not
enough → they run one after the other, which is roughly **3x faster
end-to-end** than "parallel", because the parallel version spends its time
paging. The five typechecks stay parallel and ungoverned; cached by tree
fingerprint, they cost ~1s each.

Both heavy gates also run under `gate-run.sh`, for its wall-clock **bound**
(`DEPLOY_GATE_TIMEOUT`, default 900s — a healthy vitest is 176s and a build
174s) and its process-group **reap**. macOS ships no `timeout(1)`, and killing
only the shell reparents the vitest forks to launchd. A hung gate must die on a
clock rather than outlive the deploy.

A probe that cannot read memory returns a large number, so a broken sensor
never silently serialises the pipeline. Escape hatches: `DEPLOY_HEAVY_PARALLEL=1`
forces overlap, `DEPLOY_HEAVY_NEED_GB` retunes the threshold.

### The vitest gate hangs — open, characterised, unexplained

> **Numbers below are from 2026-08-19 and are superseded as measurements** (the
> suite was 912 files then and is 1145 now; it runs as two lanes since
> 2026-09-03, ~122s wall). The *diagnosis* still stands and the hang is still
> unexplained, so the section is kept as-is rather than half-rewritten. Note the
> non-TTY fork stall below bit again on 2026-09-03: a background re-run with
> stdout to a file parked until it was killed, and the `script -qeF /dev/null`
> wrapper fixed it. That wrapper is not optional for any logged run.


Three times on 2026-08-19 the vitest gate parked indefinitely and had to be
killed. What is established:

- The suite itself is healthy: run on its own it completes in **176s**, 912
  files / 7624 tests / 0 failures, on the same commit and machine.
- The hang is **not** the astro build competing for memory. It reproduced with
  the heavy gates serialised, `memory_pressure` reporting 41% free and low
  pageouts.
- It is **not** network. At the moment of the hang the vitest main process held
  **no** open sockets, and neither did its worker.
- The shape is a fork-pool stall: main parked in `LibuvStreamWrap::OnUvRead`
  waiting on worker IPC, while its single worker sat at **0.43s CPU / 46MB RSS**
  seven minutes in — a fork that was spawned and never given work. The log
  always stops ~90s in, after the jsdom noise, before any test result.
- `globalSetup` was ruled out: `tests/_global-setup.ts` is local only (reads an
  env file, prints) with no network call to hang on.

Not established: why. The one difference between every hung run and the green
one is that the green run passed `--testTimeout/--hookTimeout/--teardownTimeout`
explicitly — but nothing in that run came close to a timeout, so that may be
coincidence rather than cause.

Until it is understood, the gate runs under `gate-run.sh`'s bound, so a hang
now dies on a clock instead of outliving the deploy. If it bites you: the suite
is trustworthy run directly (`cd one.ie/web && bunx vitest run`), and a deploy
whose only commits since a green run are harness/doc changes can legitimately
use `--skip-tests` — verify with
`git diff --name-only <green-sha>..HEAD | grep -v '^\.claude/'` returning empty.

**Health endpoints** (custom domains only — `*.oneie.workers.dev` is blocked on
this network, curl exit 6/28): `api.one.ie/health` · `one.ie/api/health`
(assert `"status":"ok"`) · `channels.one.ie/health` · `pay.one.ie/status`
(assert `"ok"`; there is no `/health` on that entry — it 404s). The agents
worker is named **`channels`**, reachable at `channels.one.ie`.

**Build OOM, fixed 2026-07-19:** the build was V8-heap-OOMing (`FATAL ERROR:
Reached heap limit`, `Abort trap: 6`, exit 134) at Node's default ~4 GiB
old-space ceiling — not a system memory shortage. `package.json`'s `build`
script now sets `NODE_OPTIONS=--max-old-space-size=8192` inline; no manual env
var needed.

**Migrations and the trap:** `wrangler.toml`'s `[[routes]]`/`[triggers]` were
reconciled to top level 2026-07-04, so there is no env-scoped target left to
hit and `--env production` has no block to resolve against. Passing it anyway
silently targets the `one-prod-production` decoy — see the trap note at the top
of this file.

## Bundle Size Rules (CF Workers Free Tier — 3 MiB gzipped upload)

The Astro Worker upload must stay under **3 MiB gzipped** on the free tier (10 MiB
on paid). Wrangler reports both `Total Upload` (uncompressed) and `gzip` — only
gzip counts toward the ceiling. All chunks in `dist/server/chunks/` are uploaded
together; dynamic `await import()` does NOT exclude code from the upload.

These rules are **LOCKED** — do not revert them. Apply identically to any
developer template we ship (`oneie init` Workers scaffold mirrors this shape).

### Rule 1 — `syntaxHighlight: false` in `astro.config.mjs`

```js
markdown: { syntaxHighlight: false }
```

Disables Shiki from Astro's markdown pipeline. Without this, Shiki pulls ~5.8 MiB of
language grammar files into the SSR worker on every build. **Do not re-enable.**

### Rule 2 — `ssr.external` for heavy packages

```js
ssr: {
  external: ["node:async_hooks", "shiki", "@shikijs/core", "@shikijs/types", /* … */]
}
```

**`one.ie/web/astro.config.mjs` § `vite.ssr.external` is the authority for this
list — never reconcile that file to this doc.** It carries 17 entries as of
2026-08-02 (`cookie`, `cytoscape`, `@xyflow/react`, `recharts`, `@stripe/*`,
`media-chrome`, `motion`, `@100mslive/*`, … alongside the shiki trio). Deleting
entries to match a stale snippet here would blow the bundle. A companion
`build.rollupOptions.external` also drops anything matching `shiki/` or
`@shikijs/` by prefix.

The CF adapter bundles everything by default. `ssr.external` creates a bare
`import { x } from 'pkg'` reference without inlining the package.

**Critical nuance:** `ssr.external` only works safely when the externalized package is
never executed on the server path. For `shiki`: `codeToHtml` is imported by `code-block.tsx`,
but all components that use `code-block.tsx` are `client:only` — so `codeToHtml` is never
called in the worker. The import statement exists in the bundle but is dead code.

If you add a new heavy dependency used only client-side, add it here.

### Rule 3 — Pure-shell pages use `client:only` + `prerender = true`

```astro
---
export const prerender = true
import { MyComponent } from "@/components/MyComponent"
---
<Layout title="...">
  <MyComponent client:only="react" />
</Layout>
```

`client:only="react"` — Astro renders an empty div on the server; the component never
runs in the worker. The React component tree (+ all its imports) stays out of the SSR bundle.

`export const prerender = true` — the page becomes a static asset generated once
at build time. The page's SSR handler collapses to a small stub. Zero worker cost
at runtime.

**Use this pattern for:** any page that has no server-side data dependencies
(no `Astro.locals`, no `Astro.request`, no DB queries in frontmatter).

The prerendered set changes every cycle — never hardcode it. Read it from the
tree (34 pages as of 2026-08-02):

```bash
cd one.ie/web && grep -l "export const prerender = true" src/pages/*.astro
```

Pages that CANNOT be prerendered: any page whose frontmatter reads
`Astro.locals` (session/workspace context), `Astro.request`, or queries the DB.
Those must stay SSR.

### Rule 4 — `inlineStylesheets: 'auto'` in `astro.config.mjs`

```js
build: { inlineStylesheets: 'auto' },   // ← NEVER 'always'
```

With `'always'`, Astro inlines the full Tailwind stylesheet into **every route's
serialized manifest entry**. With ~100 routes the entry chunk balloons by 8+ MiB
of duplicated CSS as a single string literal — diagnosable in worker-entry at
the line `const _manifest = deserializeManifest({...})`.

`'auto'` ships the bundle as one external `<link rel="stylesheet">` referenced
once across all routes. Browsers cache it across navigations — a page-speed
win, not just a worker-size win.

**Verified 2026-05-22:** flipping `always` → `auto` dropped worker-entry from
9.5 MiB → 672 KiB and total gzip from 3302 KiB → 2079 KiB.

### Rule 5 — `react-dom/server.edge` alias (production only)

```js
resolve: {
  alias: {
    ...(isDev ? {} : { "react-dom/server": "react-dom/server.edge" })
  }
}
```

Already in `astro.config.mjs`. Required for CF Edge runtime compatibility.
Do not remove for production builds.

---

## Verified Bundle Numbers

| Snapshot | Total upload | gzip | Worker-entry | What changed |
|---|---|---|---|---|
| 2026-04-18 (post Pages→Workers migration) | — | — | 9.5 MiB | Rules 1-3 + 5 |
| 2026-05-22 before `inlineStylesheets` fix | 18.5 MiB | 3.3 MiB | 9.5 MiB | Over 3 MiB ceiling — deploy FAILED |
| 2026-05-22 after Rule 4 (`'always'` → `'auto'`) | 10.1 MiB | **2.1 MiB** | **672 KiB** | Under ceiling — deploy ✓ |
| 2026-07-08 | 14.7 MiB | **3.22 MiB** | — | **Exceeds the documented 3 MiB (3072 KiB) free-tier ceiling and still deployed successfully.** Either this account is on a paid Workers plan (10 MiB ceiling) rather than free tier, or the ceiling figure elsewhere in this doc is stale — unconfirmed which. Don't treat "under 3 MiB" as a hard gate until this is resolved; treat 3.2 MiB as the new floor to watch, and re-run Bundle Size Diagnosis if growth continues. |
| 2026-07-19 | 20.2 MiB | **4.43 MiB** | — | +37% over 2026-07-08's 3.22 MiB. Deployed successfully — no diagnosis run yet. Growth window covers several merged features that day (newsletter platform, directory-submission, social-formats, movers-playbook, etc.) landing in one `/deploy` cycle; not isolated to a single change. Re-run Bundle Size Diagnosis if the next snapshot keeps climbing. |
| 2026-07-29 | 20.9 MiB | **4.60 MiB** | 1.2 MiB | +6% over 2026-07-19, third consecutive climb. Cheap diagnosis WAS run this cycle (the two grep/`ls` commands below, not a full audit): **no single runaway** — Shiki hits 0, top chunks are `_astro_data-layer-content` 2.1 MiB (content collections), `worker-entry` 1.2 MiB (up from 672 KiB at the 2026-05-22 baseline), `index` 1.3 MiB, `icons` 0.8 MiB, `mermaid` 0.8 MiB, `stripe.esm.worker` 0.6 MiB, `react-vendor` 0.5 MiB. Growth is diffuse feature accretion, not a regression; this deploy's own diff was test-only. Two named candidates if a real audit is ever warranted: `mermaid` (0.8 MiB in the SSR bundle — Rule 2 `ssr.external` candidate if it's only reached from `client:only` islands) and the 15 chunks referencing `react-vendor` (Rule 3 suggests some page still SSR-renders React via `client:load`). |
| 2026-08-02 | 22.0 MiB | **4.96 MiB** | 1.2 MiB | +8% over 2026-07-29, **fourth consecutive climb**. Cheap diagnosis run again: still **no single runaway** — Shiki 0, `react-vendor` referenced by 15 chunks (unchanged), `worker-entry` flat at 1.2 MiB. Top chunks: `_astro_data-layer-content` 2.1 MiB, `index` 1.3 MiB, **`_broadcast_` 1.3 MiB (new to the top list)**, `worker-entry` 1.2 MiB, `index` 0.9 MiB, `icons` 0.8 MiB, `mermaid` 0.8 MiB, `stripe.esm.worker` 0.6 MiB, `react-vendor` 0.5 MiB, **`generateAuthenticationOptions` 0.5 MiB (new)**. This cycle shipped beautiful-blocks (45 visual blocks + 12 background components), which is a plausible share of the delta. Four climbs in a row with the same "diffuse accretion" verdict each time is itself the signal — the cheap diagnosis has now exhausted what it can tell us, and the two standing candidates (`mermaid` via Rule 2, the 15 `react-vendor` chunks via Rule 3) want a real audit rather than a fifth restatement. |

The 2026-05-22 regression was caused by `build: { inlineStylesheets: 'always' }`
inlining the full Tailwind stylesheet into every route's manifest entry. One
char change (`always` → `auto`) saved 8.8 MiB.

---

## Service Map (post-migration)

`./deploy <mode>` covers every live row; the per-service command is what the
script runs, recorded here for rollback and one-off work.

| Service | URL | Config | Deploy command |
|---------|-----|--------|---------------|
| Astro Worker (prod) | `one.ie` → `one-prod` | `one.ie/web/wrangler.toml` | `cd one.ie/web && wrangler deploy` — **no `--env production`** (deploy-target trap: appends `-production` to the script name → `one-prod-production`, which nothing routes to; see trap note at top of this file) |
| Gateway | `api.one.ie` → `one-gateway` | `api/wrangler.toml` | `cd api && wrangler deploy` |
| Sync | `one-sync` — **cron-only, no HTTP route** (health = deploy success) | `sync/wrangler.toml` | `cd sync && wrangler deploy` |
| Agents | `channels.one.ie` → `channels` (`*.workers.dev` blocked on this network) | `channels/wrangler.toml` | `cd channels && wrangler deploy` |
| Pay gateway | `pay.one.ie` → `one-core-worker` | `pay/backend/wrangler.toml` | `cd pay/backend && bun run deploy` (= bare `wrangler deploy`, no `--env` flag) |
| Pages (legacy idle, rollback) | `oneie.pages.dev` | — | **do not deploy** — rollback target for `one.ie` |
| Worker (legacy idle, rollback) | `one-demo` (still serves `demo.one.ie`, `onestudio.dev`) | — | **do not deploy** — rollback window for the prod cutover |

---

## Auth (CRITICAL — never change)

Never: `CLOUDFLARE_API_TOKEN` (scoped token lacks workers + custom domain permissions).

**wrangler reads `CLOUDFLARE_API_KEY` + `CLOUDFLARE_EMAIL`** for global-key auth
— `CLOUDFLARE_GLOBAL_API_KEY` is *our* name for it and wrangler ignores it. The
script now exports both spellings off one resolved value, so the two can never
diverge again.

**The credential lives on disk, not in your shell** — `.env.local` at the repo
root and `one.ie/web/.env` (same 52-char key). You do not need to export
anything. If you *do* export one, it wins — which is the trap: a **stale**
export shadows the good key everywhere, because process env beats wrangler's
per-directory `.env` autoload. That is exactly how 2026-08-19's deploy used two
different credentials in two consecutive steps (see the Step 6.6 note below).
The ladder now probes each rung and falls through a rung that does not answer,
so a stale export costs a log line instead of a red deploy:

```
    rejected: ambient env (len=37 sha=eaafbda9) — /user did not answer 200
  ✓ resolved: global-api-key
    source: /Users/toc/Server/one-ie/.env.local (len=52 sha=435cba23)
  ✓ 5/5 services agree on account 627e0c7c…
```

Ground truth is the API, in **both** directions — it is as able to prove a key
alive as dead. Never conclude either from wrangler alone:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  https://api.cloudflare.com/client/v4/user     # 200 = fine
```

The deploy script auto-unsets `CLOUDFLARE_API_TOKEN` from the spawned env to prevent
accidental use of a scoped token that was exported in the shell.

Required env (export locally before running `./deploy` — there is no CI; the
script asserts the first two at gate 4 and refuses to ship without them):
- `CLOUDFLARE_GLOBAL_API_KEY` + `CLOUDFLARE_EMAIL` — auth
- `PUBLIC_GATEWAY_URL: https://api.one.ie` — build-time-inlined by Astro (**required**; without it the Worker bundle falls back to `one-gateway.oneie.workers.dev` and gateway-backed routes break). Lives in `one.ie/web/.env`.

---

## Mode-specific notes

Everything common lives in the script. These are the bits that are true of one
mode only.

### `./deploy astro`

**Resolved 2026-07-04:** `one.ie/web/package.json`'s `"deploy"` script had the
same `--env production` trap. Confirmed via the CF API that it was real —
neither `one-prod` (live) nor the `one-prod-production` decoy had any cron
schedules registered, meaning `billing-alerts-cron.ts` /
`billing-allocation-cron.ts` / `billing-autotopup-cron.ts` /
`billing-lifecycle-cron.ts` / `billing-verify-cron.ts` /
`funnel-aggregate-cron.ts` / `webhook-deliver.ts` / `broadcast-drain-cron.ts`
were not running on any schedule. Fixed by reconciling `wrangler.toml`: the
`[[routes]]` (custom domain) and `[triggers]` (crons) blocks — the only two
things that existed *only* under `[env.production]` — were moved to top level
(everything else was already duplicated there); the now-fully-redundant
`[env.production.*]` block was deleted entirely, and `package.json`'s script
dropped `--env production`. The trap is now structurally impossible — there's
no `--env production` target left to hit.

**Pre-flight (one-time, on cutover only):** ensure no other CF entity owns the
`one.ie` custom domain. If wrangler errors with a hostname conflict, detach the
prior owner first:

```bash
# If a Pages project owns it (was `oneie` project pre-cutover):
curl -s -X DELETE \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/pages/projects/oneie/domains/one.ie" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_GLOBAL_API_KEY"
```

### `./deploy workers`

Verified 2026-07-08: gateway, sync and channels complete independently with no
shared state — which is why the script runs them concurrently.

### `./deploy pay`

`pay/backend/src/index.ts` mounts `src/routes/status.ts` (`/status`) and
`discoveryRoutes` (`/`). It does **not** serve `/health` — the `/health`
handler in `pay/backend/src/api/routes/status.ts` belongs to the separate,
unmounted `src/api/` tree. Both `/` and `/status` probed live 2026-08-02: 200,
unauthenticated. `/status` also reports version, destinationMode, and contract
addresses.

**Found 2026-07-05:** `pay/backend` shipped a real commit (`feat(pay):
embeddable payment-link page`) that sat unshipped through a full deploy cycle
because the service map only named 4 services. `pay.one.ie` is a first-class
5th target, not an afterthought — check `git log` scoped to `pay/` for
unshipped commits, same as the other four.

## Bundle Size Diagnosis

If build fails with "exceeds size limit":

```bash
# Check total worker size
du -sh dist/server/

# Find top offenders
ls -lhS dist/server/chunks/ | head -20

# Check if a new import pulled in Shiki
grep -r "from 'shiki'" dist/server/chunks/ | wc -l
# If > 0: a component that imports shiki was SSR'd
# Fix: make its page client:only="react" + prerender=true

# Check if React crept back into worker via client:load
grep -l "react-vendor" dist/server/chunks/
# If multiple chunks: some page SSR-renders React via client:load
# Fix: audit src/pages/*.astro for client:load on pure-shell pages
```

---

## The TypeDB flake waiver — a red suite the deploy may ship past

`one.ie/web`'s suite talks to a REAL shared TypeDB Cloud cluster (CLAUDE.md:
"Don't mock TypeDB in integration tests"). When that cluster blips or a query
outruns its timeout, a handful of task/substrate suites go red without anything
in the diff being wrong. That used to be an eyeball judgement, which is exactly
the call that gets rubber-stamped on the fifth deploy attempt at 2am.

`.claude/scripts/typedb-flake-check.sh` makes it a check. When the vitest gate
goes red, `deploy.sh` runs it against the gate log:

| exit | means |
|---|---|
| 0 | every failure carries a substrate-unavailable signature — waivable, deploy continues |
| 1 | at least one failure is real, or the log could not be classified — deploy stops |

**It keys on the failure SIGNATURE, never on the filename.** A file-based
allowlist waives every future failure in that file, including the real ones. The
waived signatures are `upstream_50[234]`, `status=50[234]`,
`fixture write failed`, `Test timed out in Nms`, `ETIMEDOUT`, `ECONNRESET`,
`ECONNREFUSED`, `EAI_AGAIN`, `socket hang up`, `fetch failed`, and TypeDB
connection errors.

Four properties, each with a red half in `--self-test`:

- **`not_found` is never waivable.** Checked first, independently of everything
  else. It is the `tasks:claim` privilege boundary and four separate real
  defects have presented as that exact string. A `not_found` wrapped inside a
  503 still blocks.
- **One flake never vouches for its neighbour.** The log is split into vitest's
  per-failure blocks and EVERY block must carry a signature. A genuine assertion
  break standing beside a 503 blocks the deploy.
- **Silence is not a pass.** An empty or unparseable log, or one with no
  `Tests N failed` line, exits 1.
- **A waiver is not a green suite.** The report says
  `WAIVED as TypeDB outage (suite NOT green)`, and a waived run **cannot settle
  deferred-pin debt** — the waiver speaks only to the failures that reported, not
  to a pin that never got to.

On by default. `--no-typedb-flake-waiver` (or `DEPLOY_ALLOW_TYPEDB_FLAKE=0`)
restores the hard stop. Prove the checker still bites before trusting it:

```bash
bash .claude/scripts/typedb-flake-check.sh --self-test   # 6 cases, 4 of them red halves
bash .claude/scripts/typedb-flake-check.sh <a-gate-log>
```

**The waiver is not a diagnosis.** `curl -sS -o /dev/null -w '%{http_code}' https://api.one.ie/health`
returning 200 while the suite reports 503s means the cluster blipped mid-run. A
200 alongside failures that are NOT in the signature list means the code is
wrong — and the checker will tell you so.

## Known-Flaky Test Allowlist

`deploy.sh` deliberately enforces no allowlist — a red suite stops it, and it
prints the failing files with a pointer here. Triage is yours: treat these by
name when they appear in `bunx vitest run` output in `one.ie/web`; don't block deploy on them, but don't silently ignore new failures either
— confirm the failure signature matches before waving it through:

- `tests/e2e/c5-webhook-subscribe.test.ts` — `workflow:webhook-subscribe` "writes a KV
  record…" and "fails closed on a non-owned workflow". **Root cause (confirmed 2026-07-08):**
  `ssrfGuard()` (`one.ie/web/src/lib/ssrf.ts`) resolves DNS via Cloudflare DoH by fetching
  `https://1.1.1.1/dns-query` directly; this local dev network refuses connections to
  `1.1.1.1:443` (`curl: (7) Failed to connect`), so `resolveHostIPs` returns `[]` and every
  URL — including the test's `https://example.com` — comes back `blocked_url`. Verify before
  waving through: `curl -v --max-time 5 https://1.1.1.1/dns-query 2>&1 | grep -i refused`
  — if that shows "Connection refused", it's this network gap, not a code regression. If it
  connects fine and the test still fails, it's real — investigate.
- `tests/unit/tasks-humans.test.ts` + `tests/tasks-do-roundtrip.test.ts` — **only** when
  the failure is `fixture write failed (status=503 error=upstream_503)` or
  `(status=502|504 …)`. That message means the shared TypeDB Cloud cluster was
  unavailable through every retry `typedbQueryDetail` already performs — the substrate
  refused setup, so nothing downstream proved anything. Verify before waving through:
  `curl -sS -o /dev/null -w '%{http_code}' https://api.one.ie/health` — a 200 there with a
  503 in the test means the cluster blipped during the run, not that the code is wrong.
  **Any OTHER failure in these two files is real and blocks deploy** — in particular a bare
  `not_found` on `tasks:claim`, which is the privilege boundary and must never be waved
  through. Four separate defects that used to present as that same `not_found` were fixed
  2026-08-02 (concurrent-run sweep destruction, silent fixture writes, same-attribute
  insert races, read-after-write lag); if it reappears, something new is wrong. History:
  the commit message on `140975e44` and `tests/helpers/probe-sweep.ts`.
- Hardware/stochastic benchmarks (speed, distribution-timing tests) — expected variance,
  not correctness bugs.

Any other failure (type errors, assertion mismatches on business logic) blocks deploy —
diagnose and fix before proceeding.

---

## First-Time Setup

Only needed once, before `./deploy` can work at all. There is no
`docs/deploy.md` — this block plus the script is the whole walkthrough.
Resource names below are the ones
actually declared in `one.ie/web/wrangler.toml`; creating differently-named
resources produces bindings the Worker can't resolve.

```bash
# Create CF resources — names must match wrangler.toml exactly
bunx wrangler d1 create one-owners                # → binding DB
bunx wrangler kv namespace create SESSION         # → binding SESSION
bunx wrangler kv namespace create CHAT_CACHE      # → binding CHAT_CACHE
bunx wrangler kv namespace create THREADS         # → binding THREADS
bunx wrangler r2 bucket create one-content        # → binding CONTENT
# → Paste IDs into one.ie/web/wrangler.toml + sync/wrangler.toml

# Run D1 migrations (the ledger starts at 0001_owners.sql — there is no 0001_init.sql)
cd one.ie/web && bunx wrangler d1 migrations apply DB --remote

# Gateway secrets (TypeDB credentials) — no --env flag, ever
cd api
printf 'admin' | bunx wrangler secret put TYPEDB_USERNAME
bunx wrangler secret put TYPEDB_PASSWORD   # paste at the prompt; never inline the value
cd ..

# First deploy — Worker auto-provisions on first `wrangler deploy`
# Then just: ./deploy
```

---

## Logs

`./deploy` writes `.deploy-logs/deploy-<stamp>.log` (gitignored) — every gate's
stdout in order — plus `.deploy-logs/<service>-<stamp>.log` for each service in
the parallel wave, since their output would otherwise interleave. The report at
the end names the log path.

Live logs:

```bash
cd one.ie/web && bunx wrangler tail --name one-prod   # Astro Worker (production)
cd api && bunx wrangler tail                          # Gateway
cd one.ie/web && bunx wrangler deployments list --name one-prod | head -10
```

---

## Gotchas

- **A service with no local `wrangler` falls through to a shared `bunx wrangler@latest` cache, and that cache can rot.** Hit 2026-08-06: `sync/` was the only one of the five without wrangler in its `devDependencies`, so `bunx wrangler deploy` resolved to `$TMPDIR/bunx-501-wrangler@latest/` — whose install was missing `esbuild`, so it died `MODULE_NOT_FOUND` before reading a single config. The other four were unaffected because they resolve wrangler from their own `node_modules`. Fixed by pinning `wrangler` into `sync/package.json` like its siblings. If this shape reappears elsewhere, the workaround is a version-pinned invocation (`bunx wrangler@4.80.0 deploy`, which lands in a different cache dir); the fix is a local dep.
- **Piping `./deploy` into `tail`/`head` masks its exit code** — the pipeline reports the pager's status, not the script's, so a failed run reads as exit 0. `die()` really does `exit 1`; read the ✓/✗ lines or the `.deploy-logs/` file, and don't infer success from a piped exit status.
- TypeDB Cloud port is **1729** (not 80 or 443)
- TypeDB HTTP API prefix is `/v1/` (signin, query, databases)
- Always `CLOUDFLARE_GLOBAL_API_KEY` — scoped tokens lack permissions for workers + custom domains
- `import.meta.env` is build-time — `PUBLIC_GATEWAY_URL` is baked into the worker bundle at build. Missing → gateway-backed routes fall back to the wrong host and break
- Custom domains: `[[routes]]` double bracket, no wildcards, add `workers_dev = true`
- Worker upload limit: **3 MiB gzipped** on free tier (10 MiB on paid) — though a 2026-07-08 deploy shipped at 3.22 MiB gzip successfully, so this account's actual ceiling is unconfirmed (see Verified Bundle Numbers). Wrangler reports `gzip:` — only that number counts. Follow the 5 Bundle Size Rules above regardless of which ceiling applies
- **D1 schema-drift fails at runtime, not compile-time.** Migrations that DROP+CREATE a table (e.g. `0059_domains.sql` renamed `slug`→`gid`, `verified`→`verified_at`) silently break any code that queries the old columns — typecheck passes, deploy succeeds, the route 500s in production. After any DROP+CREATE migration, grep the codebase for the old column names and fix call sites BEFORE deploying
- **Error responses get the same `cache-control` as success responses.** Astro's Layout sets `public, max-age=300, s-maxage=86400, stale-while-revalidate=604800` on every render including 5xx pages. A bad deploy will be cached at the CF edge for 24h. When diagnosing, always bust the cache: `curl "https://host/path?_t=$(date +%s)"`. Consider a middleware rule that strips `cache-control` on `>= 500` status

---

*Deploy is the closed loop. W0 baseline in, health check out. If health fails, mark() is blocked. Determinism: every step reports numbers, every number gets marked.*

### `code: 9103` does not mean the key was revoked

Measured 2026-08-18, and it cost an hour plus a wrong accusation that a security
incident had rotated the key. `Unknown X-Auth-Key or X-Auth-Email [code: 9103]`
at Step 6.5 was a **variable-name mismatch**: the script exported
`CLOUDFLARE_GLOBAL_API_KEY`, wrangler only reads `CLOUDFLARE_API_KEY`.

Before concluding a Cloudflare credential is dead, ask the API directly — it is
ground truth and wrangler is not:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  https://api.cloudflare.com/client/v4/user     # 200 = the key is fine
```

Three companion traps, all real:

- **wrangler 4.x auto-loads `.env` from the cwd**, so a stale key in
  `one.ie/web/.env` beats both your exported vars and an OAuth session. Isolate a
  credential test by running it from `/tmp`.
- **`/user/tokens/verify` is Bearer-only** — `400 Missing "Authorization" header`
  there is not evidence against a global key. Use `/user` or `/accounts`.
- **Length proves nothing.** A classic global key is 37 hex chars; a `cfk_`-prefixed
  one is ~52 and equally valid.

**Never edit `.env` while a deploy is running.** Doing so took a run fully red —
tsc, vitest, and the astro build — for reasons that had nothing to do with the code.

### The 2026-08-19 sequel: `code: 7403` at Step 6.6, and two keys

The same family, one layer deeper, and worth reading before you diagnose any
Cloudflare auth failure here. Step 6.5 (D1 in `one.ie/web`) **passed** and Step
6.6 (D1 in `channels`) **failed** in the same run, seconds apart, on the same
account. That is only possible if they used different credentials — and they
did:

- **Three** credentials were reachable from one `./deploy`: a stale 37-char key
  in the ambient env (injected by `~/.claude/settings.json`'s `env` block — so
  it existed inside Claude Code sessions and *not* in a plain terminal, which is
  why grepping the shell profiles found nothing), the good 52-char key in
  `one.ie/web/.env` + `.env.local`, and the `wrangler login` OAuth session.
- Nothing *chose* between them. Each service got whatever its own cwd surfaced.
  Of the five dirs, only `one.ie/web` has a `.env` — so it read the good key and
  passed, while `channels` fell through to OAuth and hit `7403`.
- **`7403` ≠ `9103`.** `9103` ("Unknown X-Auth-Key") points at a key; `7403`
  ("account is not authorized to access this service") points at an account
  scope, i.e. a session. Reading them as the same symptom is what sent the first
  diagnosis at a perfectly good key.

Fixed by making the credential *resolved* rather than *ambient* — see Step 0.4
above. Run `./deploy --check-creds` if you ever doubt which key is in play; it
names the source and proves all five services agree.
