# CLAUDE.md — `.claude/scripts/`

Moved from `.claude/CLAUDE.md` so it loads only when working here.

## Script notes

```
├── scripts/       # 65 entries — `ls .claude/scripts/` is the map, not this comment.
│                 # deploy.sh — the whole /deploy pipeline, deterministic:
│                 # gates (tree, tsc ×5, vitest, build, creds, smoke, approval,
│                 # D1) then parallel deploy + health probes. `./deploy` at the
│                 # repo root execs it. It is the AUTHORITY for the deploy
│                 # steps — .claude/commands/deploy.md carries no second copy.
│                 # Its vitest gate PROBES THE MEMO BEFORE TAKING A SLOT (the
│                 # `>>> vitest-memo-probe` block): measured 2026-09-13, the gate
│                 # queued 300s under gate-run.sh and then reported both lanes as
│                 # cache HITs. The probe asks PER LANE the way release.sh's
│                 # receipt does (TEST_CACHE_KEY_ONLY=1 + a stamp per key) and
│                 # skips only when EVERY lane is already green — never by reading
│                 # test-lanes.sh's exit code, which under TYPEDB_LANE_NONBLOCKING=1
│                 # is the pool lane's alone and would skip 19 typedb suites that
│                 # had never run. A miss or an unanswerable probe takes the slot.
│                 # A skipped gate counts as PASSED, stays OUT of HEAVY_IDX (a
│                 # process-less gate there makes the next heavy gate `wait 0` —
│                 # exit 127 — and overwrite its rc), and reports REUSED with the
│                 # stamp's timestamp, never "all pass". --skip-tests is distinct.
│                 # release.sh — the PROD door since 2026-09-05: `promote <sha>`
│                 # fast-forwards branch `release`, materialises .release/ (deps
│                 # by symlink, never bun install) and refuses unless that exact
│                 # tree carries deploy's own full-suite receipt (test-cached
│                 # stamp) + 5 clean tsc; `ship` runs deploy.sh --changed FROM
│                 # .release/ so the suite gate is a memo HIT reported REUSED —
│                 # no --skip-tests, ever. Nine named exit codes; --self-test is
│                 # the red proof. Run MAIN's copy (from inside .release/ it
│                 # resolves ROOT to .release and tries to add .release/.release).
│                 # Step 9 (Lighthouse) is detached by default — SPEED_SYNC=1
│                 # holds it inline, SPEED_TIMEOUT bounds it, 124 reads as unrun.
│                 # Two of its gates are MEMOISED on a byte-identical tree: the
│                 # full vitest suite via test-cached.sh (only passes; a reused
│                 # pass is reported as reused, never as "all pass") and the
│                 # astro build via astro-build-cached.sh (stamp inside dist/,
│                 # key covers one.ie/web + packages/ + the gitignored .env and
│                 # lockfiles). The typechecks are deliberately NOT cached —
│                 # measured 8s serial, inside vitest's shadow, and tsc-cached
│                 # shares a gate_lock with do-reconcile — both take a SLOT
│                 # BEFORE that lock since 2026-09-13, never while holding it
│                 # (govern-order-check.sh). An unpaid deferred-pin
│                 # debt (verify-fast's ledger) now REFUSES a deploy that did not
│                 # run the suite. Red proofs: deploy-gate-check.sh (extracts the
│                 # debt block verbatim and drives it), plus --self-test on
│                 # tsc-cached / test-cached / astro-build-cached.
│                 # roles-check.sh — the nine authority checks (IC row 1 of
│                 # roles-vantage-collapse); --check-gate plants a vantage-vs-rung
│                 # comparison and proves one.ie/web's astro-check ratchet goes red.
│                 # --check-floors runs the page-floor matrix (five callers per
│                 # private page through the real guardPage) and proves an
│                 # ANONYMOUS private page cannot land — it forces anonymity with
│                 # a `signed_out=1` cookie, because DEV_SLUG otherwise makes a
│                 # session-less localhost request the owner of the `one` subtree.
│                 # --check-decide / --check-503 run the authority matrix
│                 # (one.ie/web/tests/authority/) through the real decide(), then
│                 # mutate the FIXTURE to prove the deny cells bite and that a
│                 # swallowed lookup error cannot pass as a 403. --check-worldkey
│                 # (C6) replays the same suite with a world-key Principal — the
│                 # original bug report — and asserts a denial NAMES the node
│                 # instead of comparing a vantage word to a rung word.
│                 # land.sh — the BRANCH door. Bare: merge main in, fast gate in the
│                 # branch's worktree, then --ff-only main. `--pr`: gate then open/
│                 # update a PR, skipping the trunk merge so a reviewer sees what the
│                 # branch added. `--pr --deploy`: the whole workflow in order —
│                 # gate → ship THAT WORKTREE to dev.one.ie → prove the routes with
│                 # do-prove (both bases pinned to dev; it falls back to PROVE_PROD_URL
│                 # and would otherwise prove PRODUCTION) → open the PR carrying the
│                 # dev URL. Reads the probe's ROUTE COUNT, never its exit code —
│                 # `PROVE: skipped` exits 0. RUN MAIN'S COPY: from a worktree, ROOT is
│                 # that worktree and the ff merges the branch into itself (always
│                 # "already up to date", main untouched, three false "landed" reports
│                 # on 2026-09-05). It now verifies with `merge-base --is-ancestor`.
│                 # A red gate is DIAGNOSED, not blamed (2026-09-12): branch-alone and
│                 # dev-alone typecheck read from the memo (`tsc-cached.sh --probe`,
│                 # `TSC_CACHE_ROOT=<tree>`), a gateway pre-flight, and which side of
│                 # the merge touched each failing file — branch / dev / seam /
│                 # environment. The verdict is the run's --note. `--self-test` drives
│                 # all seven shapes, including transport+assertion ⇒ NOT environment.
│                 # It links node_modules for every tracked package.json rather than a
│                 # list — the list missed channels/, pay/backend/ and one.ie/web/ in
│                 # turn, each time reading as a RED gate on a branch of shell scripts.
│                 # deploy-record.sh — appends a run to one.ie/web/src/data/deploy-runs.json,
│                 # which /deploy renders (the factory.astro shape: data, not a live
│                 # query — a deploy runs on a laptop and one-prod cannot read that disk).
│                 # Called by deploy.sh and land.sh on BOTH exits, `|| true`. --self-test.
│                 # Load-bearing few: do-reconcile.sh (7 canons) · do-auto.sh + do-fleet.sh
│                 # (worktree cycles) · do-tier.sh (spine prune) · do-promise-lint/settle.sh
│                 # · signal-watch.sh — every door the factory's signals cross (prod + local),
│                 #   with server-timing phases, cf-placement, ratchet budgets, a JSONL
│                 #   ledger and --self-test; the instrument for root CLAUDE.md § The brain
│                 #   and the edge (a receiver that queries TypeDB inline reads RED here)
│                 # · chrome.mjs (the browser — chrome-headless-shell, backs /browser and
│                 # every do-prove.sh --route check; browser-check.mjs is a shim over it)
│                 #   do-prove enforces a LANDING RULE: a route only counts as proven if
│                 #   the run ENDED on the path asked for. A signed-out /u/<slug>/* 302s
│                 #   to /signin, which renders 200 with no console errors — that scored
│                 #   "ok" until 2026-08-04, so authed promise clauses were green on the
│                 #   sign-in page. Every route runs SIGNED-OUT first; only a bounce to
│                 #   the login wall retries with a dev session (dev-sign-in.ts, or
│                 #   OWNER_EMAIL+DEV_PASSWORD over HTTP, localhost base only) so those
│                 #   clauses still run in a bare shell. Lazy on purpose: DEV_SLUG makes
│                 #   a signed-out request render /u/one/* as workspace `one`, while the
│                 #   dev session is tony — signing in up front turned a genuine pass on
│                 #   /u/one/workflows into "landed on /u/tony/workflows".
│                 #   PROVE_SESSION_COOKIE overrides; PROVE_NO_SESSION=1 drives the red
│                 #   half on demand. A worktree without .wrangler/state cannot seed the
│                 #   credential — export the two vars or the cookie there.
│                 # · typedb-env.sh (flip one.ie/web/.env local↔cloud) · factory-repo.sh
│                 # (emits one-ie/factory, see below) · sync-claude-mirror.sh (packages/claude)
│                 # None are on PATH — always invoke as `bash .claude/scripts/<name>`.
│                 # TRAP, measured 2026-08-04: in a `set -o pipefail` script,
│                 # `<producer> | grep -q PAT` returns 141 when it MATCHES if the
│                 # producer is still writing — grep -q exits first and the
│                 # producer takes SIGPIPE. Sharp threshold: curl of 87 bytes is
│                 # fine, curl of a 378 KB page is not; shell builtins never
│                 # misfire. It bit do-walk's expect_text (false RED) and
│                 # factory-repo's cycle gate (false GREEN — the pipe sat under a
│                 # `!`, so failures read as green). Capture the output, then
│                 # match it with a here-string. `printf "$out" | grep -q` puts
│                 # the same race one process to the left.
```

## A non-run must never read as a pass

The SIGPIPE trap above has a sibling class: a gate that never ran, reported green.
Two shapes, both measured 2026-09-14.

- **`gate-run.sh <label> -- <cmd>` exits 127 when `<cmd>` is a bare name not on
  PATH** — `vitest` lives in `node_modules/.bin`, not on PATH. It ran **zero
  tests twice** and the harness reported the wrapper as "completed exit 0". The
  mechanism is unconfirmed in source (`govern.ts` spawns with no `env:`
  override, so PATH *should* inherit); the behaviour is what is measured.
  **Invoke the target by ABSOLUTE path** — `gate-run.sh test --
  /abs/path/node_modules/.bin/vitest run …` — and treat a 127 as RED, never as a
  clean suite.
- **Piping a gate through `tail` masks its exit code.**
  `FULL_VERIFY=1 bun run verify … | tail -60` printed `[exited with code 0]`
  while `verify` itself exited **1**. Same lesson as the pipefail trap one
  process to the right: read **`${PIPESTATUS[0]}`**, or capture the output first
  and match it with a here-string.

## Machine governor — why N sessions no longer melt the box

**Measured 2026-08-18:** several sessions each ran `bun run verify`
(tsc --noEmit + vitest over 875 test files) concurrently on a 10-core/24GB Mac.
Six `tsc` and three vitest pools ran at once — load **57**, swap **15.7/16 GB**,
~26 MB/s of swapins. Starved by paging, each gate took **18 min instead of ~2**,
so sessions hit their Bash timeout and launched *more*. The box got slower the
harder it was pushed. Claude Code was the trigger; the amplifier was that
nothing in this harness bounded a gate's concurrency or its children's lifetime.

macOS ships **neither `flock(1)` nor `timeout(1)`** — both are GNU coreutils.
That absence is the root reason gates were unbounded here. The governor
rebuilds both from `mkdir(2)` atomicity and a real process group.

**Since 2026-09-04 the mechanics are `scripts/lib/govern.ts` (Bun) and
`scripts/lib/govern.sh` is a shim.** The design did not change; the runtime
did — bash 3.2 on macOS has no flock, no timeout and no BASHPID, `set -m`
needs job control, and a watchdog subshell cannot own the `sleep` it forks.
Every function NAME, ARGUMENT and EXIT CODE is unchanged, so no caller
changed. Four functions deliberately stay in bash: `_gv_alive` and the three
`_gv_vm_stat` / `_gv_swapusage` / `_gv_memsize` wrappers are the seams three
of the six proofs **stub as bash functions**, and `_gv_claim_key` is BSD
`cksum` (the POSIX CRC, not zlib's) which the claims checker reads off disk.
A new `_gv_*` seam a checker stubs belongs in the shim, not in the port.

| Piece | Does |
|---|---|
| `scripts/lib/govern.ts` | the mechanics — lock/slot loops, `run_bounded`, the claim reaper + TTL, the memory arithmetic, and BOTH memo keys (`tsc_tree_fingerprint`; test-cached's per-file `_hash_rel`). Reached through the shim, never called directly |
| `scripts/lib/govern.sh` | the shim every caller sources. `gate_lock` (mkdir-atomic named lock, reaps dead owners) · `gate_slot` (machine-wide semaphore, `GOVERN_MAX_GATES`, default 2) · `run_bounded` (wall-clock cap that kills the **process group**) · `gate_pressure` · **claims** — see below. The lock/claim owner is the CALLING SHELL's `$$`, never the short-lived bun process |
| `scripts/gate-run.sh` | `gate-run.sh <label> -- <cmd>` — slot + bound + group-reap. Re-entrant (`verify` calling `test` inherits the slot, never deadlocks). Execs straight through under `CI=1` or `GOVERN_DISABLE=1` |
| `hooks/load-guard.sh` | PreToolUse(Bash) backstop for heavy commands typed directly, bypassing package.json |
| `hooks/governor-escape.sh` | PreToolUse(Bash) — the *escape hatches* themselves are refused unconditionally: `verify:raw`, `test:raw`, a bare `vitest`, an inline `GOVERN_DISABLE=1`/`CI=1`. Matcher shared with the checker at `hooks/lib/governor-escape-match.sh` — one definition, no drift |
| `scripts/governor-doors-check.sh` | the other half — what the TREE OFFERS. `hook:governor-escape` guards what an executor TYPES, but `cd channels && bun run test` was an ungoverned 135-file two-runner suite and nothing about that string looks like an escape: the hole was the package script. Enumerates every tracked `package.json` at run time (never a hardcoded list), follows one hop through `bash <x>.sh`, and fails on any heavy script that is neither governed nor on the reasoned skip list. Also proves the wrapped relative paths resolve and that a nested gate does not deadlock |
| `scripts/governor-escape-check.sh` | its proof, three parts: the matcher's case table (bites / does not false-positive), the real hook driven with a payload, and a RED PROOF that guts the matcher and neuters the hook and asserts both halves go red |
| `scripts/machine-check.sh` | `--watch` for the live read: load, swap **direction**, running gates, held slots, orphans |
| `scripts/gate-watchdog.sh` | the reaper's OPPOSITE — it breaks the jam whose owners are both **alive**, which by definition no reaper can see (2026-09-13: three deadlocks in 35 minutes, 8-28 min each at 0% CPU). Cuts exactly one shape: a lock holder with **no slot** that has a `gate-run.sh` descendant queueing for one — the single process on the wrong side of the ordering. **Never a slot owner.** The clock is the SLOT's directory mtime, not the lock's: during the live jam the lock changed hands every ~9 minutes (each holder killed by its session's 600s Bash ceiling) while the jam ran >20, so a lock-clocked watchdog never fires. `--once` from `hooks/session-start.sh` (0.12s, silent), `--dry-run` to name a victim without cutting, `--self-test` for 14 checks including a real planted deadlock and three red proofs. The code fix that removes the cause is `govern-order-check.sh`'s SLOT-before-LOCK; this stays useful until every worktree has rebased onto it |
| `scripts/govern-claims-check.sh` | the claim registry's two properties — exclusion and evaporation — plus a red-proof. `bash .claude/scripts/govern-claims-check.sh`, exits non-zero on failure, touches only a sandbox `GOVERN_DIR` |
| `scripts/govern-order-check.sh` | **the LOCK ORDER**, proved by deadlocking it. Runs the two roles in the two orders — a gate holding a slot whose child wants the lock, vs a bare caller — and asserts they finish. Its red half plants the pre-2026-09-13 `LOCK -> SLOT` holder and asserts the same harness STALLS, so a green run is never green for lack of power; a third section proves a cache HIT and `--probe` still take neither. ~20s, own sandbox `GOVERN_DIR`, kills only its own children |

Wired: `one.ie/web` `verify`/`test`/`check`/`demo:*` plus `api`, `channels`,
`schema`, `pay/backend`, `packages/sdk` and `packages/cli` `test` all route
through `gate-run.sh` (`verify:raw`/`test:raw` are the ungoverned escapes,
and `governor-doors-check.sh` is what keeps that list honest); `do-reconcile.sh types`
takes a per-folder lock and **caches by tree fingerprint** — git HEAD +
porcelain + source mtimes — so six identical `tsc` runs collapse to one compute
and five cache hits; `vitest.config.ts` caps the fork pool (`maxWorkers` **8**,
`VITEST_MAX_FORKS` to override) with a 1GB per-fork heap.

That cap was **4** until 2026-09-01, and the reason it could double is the reason
it existed: each fork used to hold a ~120MB jsdom. `vitest.config.ts` now defaults
`environment` to `node` (only ~230 of ~1135 files touch a DOM; the rest opt in
with a `// @vitest-environment jsdom` docblock), so **jsdom is no longer the memory
driver** and the same box carries twice the fan-out. Full suite, same tree, all
green: **518s → 324s → 87.3s**. Memory is still the binding constraint the fleet
prices in — `gate_headroom` is unchanged, so N sessions cannot each take 8.

**The fleet prices its own concurrency in memory, not cores.** `do-fleet.sh`
capped slots at `cores - 2` — on a 10-core/24GB box that authorised **8
concurrent worktrees**, and 8 cycles is ~16GB of gates before the editors,
sessions and OS get a byte. Cores were never the binding constraint.
`gate_headroom` prices a cycle (~2GB: vitest driver + 4 forks + tsc + node
overhead), subtracts a reserve, and divides what is actually free. It only ever
*lowers* the count — `--slots` and the core cap still hold — and the fleet now
names the binding constraint on its ranking line:

```
[do-fleet] ranking… (top 5 candidates, 2 slots — bound by memory;
                     cores<=8 mem<=2, DRY-RUN)
```

Tune with `GOVERN_GB_PER_CYCLE` (default 2) and `GOVERN_RESERVE_GB` (default 2).
A probe that cannot read memory returns 99 — a broken sensor must never
silently serialise the fleet.

`hooks/session-start.sh` calls `gate_sweep_stale`: `_gv_reap` only fires when
someone *contends* for a lock, so a session that died holding a slot would
shrink `GOVERN_MAX_GATES` until the next contender happened along. Silent
unless it actually reclaims something. It also calls `claim_sweep` (below) for
the same reason.

### SLOT before LOCK — the one ordering rule, and the day it was broken

The governor hands out two different things and **the order between them is
fixed: take the SLOT first, then the LOCK.** A slot bounds the machine; a lock
dedupes identical work. Take them the other way round anywhere and that site can
deadlock against every site that takes them correctly.

Measured 2026-09-13 — **three occurrences in ~35 minutes**, each stalling every
session on the box for 8-28 minutes at 0% CPU, one of them a production release
gate. `tsc-cached.sh` took the per-folder lock and then queued for a slot while
holding it; `bun run verify:fast` IS `gate-run.sh verify-fast -- …`, so it
arrives already holding a slot and its child then waits for that lock:

```
A: gate-run(verify-fast) holds slot-1   ->  its tsc-cached waits for lock-tsc-one.ie_web
B: tsc-cached holds lock-tsc-one.ie_web ->  its inner gate-run waits for a slot
```

Owner pairs measured: 22173/68920, 15762/97557, 87579. **Nothing reaps this** —
`reapLock` and `gate-reaper.sh` only reap an owner whose pid is GONE, and both
owners are alive and idle. And **killing the lock holder does not fix it**
(observed twice): the lock passes straight to the next waiter, which is itself
inside a gate holding a slot, and the cycle re-forms within seconds. Kill the
**slot** holder — that is the resource nobody else can produce.

Both inverted sites are fixed (`tsc-cached.sh` re-enters itself through
`gate-run.sh` in an internal `--locked-compute` mode; `do-reconcile.sh` takes the
lock INSIDE its `gate-run.sh` command). A cache HIT and `tsc-cached.sh --probe`
still take neither — a memo lookup must never join a queue. Proof, both halves:
`bash .claude/scripts/govern-order-check.sh`.

### Region claims — one pheromone map, not nine

`do-fleet.sh` kept its conflict registry in `LOCK_FILE="$(mktemp)"` — **private
to one fleet process**. Nine concurrent fleet invocations therefore held nine
private maps and could not see each other, so two fleets each read their region
as free and both took it. That is how two fleets came to audit the same auth
seam on one box: not a lock that failed, a map nobody else could read.

The registry now lives at `$GOVERN_DIR/claims/<region>.<cksum>` — the same
machine-wide directory the gate locks use, so every session and worktree reads
one map. `ls` it; it is meant to be legible.

| Function | Does |
|---|---|
| `claim_take <region> [slug]` | deposit. `mkdir(2)` is the arbiter — N racers, exactly one wins. 0 = yours (re-claiming your own is idempotent), 1 = a live worker holds it |
| `claim_owner <region>` | `<slug> <pid>` of the LIVE owner, empty if free — **reaps before it answers** |
| `claim_release` / `claim_release_all` | give ground back; the latter is wired to do-fleet's EXIT trap |
| `claim_list` / `claim_sweep` | the live map / reap everything dead, echo the count |

**It is not a lock and there is no coordinator.** A worker that finds its region
claimed takes the next candidate — contention costs a re-rank, never a wait, so
there is no queue and nothing to deadlock.

**Evaporation is the whole contract.** A claim expires with no human in the
loop, two ways: the owner pid is dead (`kill -0`, instant) or the lease expired
(`GOVERN_CLAIM_TTL_SECS`, default 5400s = 90 min — p100 observed fleet duration
is 79 min). Both fire on the **read** path, so the next contender reclaims dead
ground by itself; `claim_sweep` at session start only stops uncontended dirs
accumulating. Note `gate_sweep_stale` matches `lock-*` at depth 1 and will never
see a claim — that is what `claim_sweep` is for.

Proof, not assertion: `bash .claude/scripts/govern-claims-check.sh` runs 12
concurrent independent processes at one region (exactly one wins), kills a live
owner and proves the region becomes claimable again, backdates a lease to fire
the TTL branch, proves a losing multi-region worker holds **no** ground
(rollback), and proves do-fleet's own `has_conflict` shape clears on a dead
owner. It also **stubs `_gv_alive` true and asserts the evaporation checks then
fail** — a checker that stays green against a gutted reaper proves nothing.

The lock dir is `$TMPDIR/one-govern` — **machine-wide**, so sessions coordinate
across worktrees automatically. A worktree only participates once it has this
code: `do-fleet.sh` now **warns per stale worktree** at launch, because until it
rebases onto `main` its gates are the old unbounded ones and the slot cap is the
only thing protecting the box from it.

**Editors are the other half of the bill.** Each `/do` cycle drops a ~115MB
checkout in `.do-worktrees/`; it is gitignored, but editors index gitignored
paths (Zed only with `search.include_ignored`, which is on here) and every
indexed worktree costs its own tsserver — measured 16 language-server processes
holding 2.3-3.0GB from 3 worktrees, entirely outside the gate governor.
`.vscode/settings.json` + `.cursorignore` exclude it; Zed's equivalent
(`file_scan_exclusions`) is user-level config, not in this repo.

**Reading swap correctly:** swapins spike during *recovery* too, as freed memory
lets pages fault back in. Thrash is pages going **out** while swap usage grows
and free memory is scarce. `machine-check.sh --watch` distinguishes the two;
don't diagnose from the swapin counter alone.
