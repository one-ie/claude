# /sweep

> **Every finished branch into `dev`, one gate, one sha to promote.**
> `/sweep` is the door before `/deploy`. It runs `bash .claude/scripts/sweep.sh`
> — the script is the authority for the procedure; this page never carries a
> second copy of the steps.
>
> ```bash
> bash .claude/scripts/sweep.sh --dry-run    # the whole plan, nothing moved
> bash .claude/scripts/sweep.sh              # doctor · fetch · classify · land · ONE gate · gc · close
> bash .claude/scripts/sweep.sh --pr         # …and open/refresh the dev → main PR
> ```
>
> **Run it from the MAIN tree's copy**, like every other door script — `land.sh`,
> `release.sh` and `deploy.sh` all derive `ROOT` from `${BASH_SOURCE[0]}/../..`,
> so a worktree's copy sweeps that worktree (`../CLAUDE.md § The dev → prod loop`).

**It does not ship.** It ends by naming the sha and handing the last two doors to
`release-manager` — see `/deploy`.

---

## What it costs: one gate, not N

`land.sh` gates each branch **with dev merged in**. That is a different tree per
branch, so six branches is six full computes plus the release gate. The memo does
not help: `test-cached.sh` is content-addressed, so the same suite on the same
tree is already free — the cost was never double-calling, it was N different trees.

`/sweep` inverts the order:

1. merge every **ready** branch into `dev` first,
2. read each branch's own typecheck as a **memo lookup** (`tsc-cached.sh --probe`
   — a read, never a compute),
3. run **one** gate on the integrated tree.

N+1 computes becomes 1. The lane is chosen deterministically from what was swept:
`fast` by default, **`full`** whenever the merge touched `schema/`,
`packages/sdk/` or auth — the canon's own escalation rule, applied by the script
rather than remembered by a human.

**What that trade costs, said out loud.** A batched gate cannot name which of N
branches owns a red. So a red **resets `dev` to the pre-sweep sha** and prints the
`land.sh` line for each branch — where the four-owner diagnosis (branch · dev ·
seam · environment, measured 2026-09-12) still lives. You pay the N gates only in
the case that needs them. **`land.sh`'s own default is unchanged**; use it
directly for a single branch.

---

## The four classes

Classification is `lib/gc-finished.sh` — the same predicate the sweep that removes
worktrees uses, sourced, not re-implemented. It is **content identity**, never
`rev-list --count`: a branch whose patch landed under another sha (rebase,
squash, cherry-pick) is finished, and a merge commit carrying unique files is not.

| Class | Test | What happens |
|---|---|---|
| `infra` | `main` · `dev` · `release` | never touched |
| `landed` | its content is already in `dev` | left for the gc, which measures against **`origin/main`** |
| `busy` | ahead, but its worktree has uncommitted **work** or something is running in it | skipped, and the reason is named |
| `ready` | ahead, clean, idle | merged |

Build output is not work: `one.ie/web/.astro`, `.wrangler`, `.preview`,
`node_modules` and friends never make a branch busy.

**gc measures against `origin/main`, after a fetch, and that is deliberate.** A
branch is finished when it is *released*, not when it is integrated — a reviewer
asking for changes must not find the branch already deleted. A stale local ref
makes landed work look unmerged (measured 2026-09-07: local main 131 behind, 1.0 GB
hoarded), which is why the fetch is the first git command.

---

## The doctor holds the box

Phase 0 is `health.sh --box --json`. A sweep **starts gates**, and on a paging box
a gate runs long — a slow gate is indistinguishable from a red one at the wall
clock, which is how a good tree gets diagnosed as broken code.

| Verdict | What sweep does |
|---|---|
| `HEALTHY` | go |
| `DEGRADED` | go — it funds one concurrent gate, and a sweep needs exactly one |
| `UNHEALTHY` | reap **only if `orphans > 0`**, re-read, then refuse (exit 3) and name the agent |

On a refusal, spawn the doctor and re-run:

```
Agent({ subagent_type: "doctor", model: "opus",
        prompt: "health.sh says: <why>. Reclaim what nothing is coming back for, then report the verdict." })
```

`--dry-run` is **never** refused for the box — a plan starts no gates, and a tool
that refuses a plan teaches you to pass `--no-doctor` by reflex. The flag you
reach for out of habit is the flag that stops protecting you.

---

## The numeric close

```
ready=2 merged=2 landed=4 busy=1 infra=3 gates=1 lane=fast box=DEGRADED dev=85250c0b6 ahead_of_main=8
```

Every number is counted, not narrated. `gates` is the one that matters: it is the
count of real computes the sweep cost, and it is 1.

Exit codes are distinct and named, because "it refused" is not a finding:
`0` ok · `2` usage · `3` box refused · `4` integrated gate RED (dev reset) ·
`5` a merge conflicted (dev reset) · `6` nothing to sweep and nothing to promote.

---

## Prove it can go red

```bash
bash .claude/scripts/sweep.sh --self-test     # 22 assertions, ~3s
```

The live estate is usually three worktrees and no feature branches, so a green
`/sweep` proves only that a no-op is a no-op. The self-test mints throwaway
estates instead, and covers **both halves** — the read-only classifier and the
half that moves refs:

| What it proves | How |
|---|---|
| every class | one branch each: landed **under a different sha**, ready, dirty, ephemeral-dirt-only, infra |
| liveness, both ways | it must see a process under the tree (`exec -a`, because `pgrep -f` matches argv, not cwd) and must **not** match a prefix neighbour |
| the merge | ready branches land, the dirty one does not, `gates=1` |
| the lane | a `schema/` touch selects `full` without being asked |
| **a red gate** | exit 4, `dev` **back at the pre-sweep sha**, and the `land.sh` line named per branch |
| **a conflict** | exit 5, `dev` back at the pre-sweep sha — a conflict is not a red suite and does not share its code |
| the seam itself | `SWEEP_GATE_CMD` is read **only** under `SWEEP_ROOT`, so there is no way to spell "skip the gate" in a real run |

The two reset paths are the reason the merge half is tested at all: a reset
nobody ever runs is a reset nobody knows is broken, and the ref it fails to
restore is someone's branch. Deleting the reset line makes the suite go **RED**
on exactly that assertion — verified, not asserted.

It has already bitten its own author twice: an untracked `one.ie/` collapsing in
`git status --porcelain` read a build-output-only branch as busy, and a `sleep`
with no path in its argv proved nothing about `pgrep -f`.

**The box refusal is proved the same way** — stub `health.sh` to `UNHEALTHY` and
a real run exits **3** while `--dry-run` reports and proceeds.

---

## Then deploy

```
/sweep --pr      # dev carries everything, one gate green, PR open
/deploy          # spawns release-manager, which promotes the named sha and ships
```

See also: `/deploy` · `.claude/skills/deploy/SKILL.md` (the run as tracked work) ·
`../CLAUDE.md § The dev → prod loop`.
