# /vespio — start the fleet

```
  ██╗   ██╗███████╗███████╗██████╗ ██╗ ██████╗
  ██║   ██║██╔════╝██╔════╝██╔══██╗██║██╔═══██╗
  ██║   ██║█████╗  ███████╗██████╔╝██║██║   ██║   probe · fan out · join
  ╚██╗ ██╔╝██╔══╝  ╚════██║██╔═══╝ ██║██║   ██║   no conductor · no collisions
   ╚████╔╝ ███████╗███████║██║     ██║╚██████╔╝
    ╚═══╝  ╚══════╝╚══════╝╚═╝     ╚═╝ ╚═════╝
```

One word to start work on this repo. `/vespio` prices the box, shows the board,
and names the one next move.

**This is the vespio-side command.** The harness here is generated output, synced
one-way from the `one-ie` monorepo. You cannot sync from inside this clone, and
you are not meant to — see § 4.

---

## 0 · First run, once per clone

```bash
bun install
mkdir -p text                                   # the loop's working directory
cp data/docs/templates/template-todo.md text/   # the frontmatter contract
```

**`text/` is not optional.** `/do` reads and writes `text/<slug>-todo.md` — the
command names that path 38 times. A fresh clone has no `text/`, so the loop exits
before it starts. This is the step nobody guesses, which is why it is step one.

---

## 1 · Price the box BEFORE you fan out

The binding constraint is **memory, not cores**. A cycle costs roughly 2GB
(vitest driver + forks + tsc + node). On a 10-core/24GB box, `cores - 2` would
authorise 8 concurrent worktrees — about 16GB of gates before your editor, your
session and the OS get a byte.

```bash
bash .claude/scripts/machine-check.sh --watch    # load · swap DIRECTION · orphans
```

**Read swap direction, not the swapin counter.** Swapins spike during recovery
too. Thrash is pages going *out* while free memory shrinks.

Everything heavy goes through the governor:

```bash
bash .claude/scripts/gate-run.sh <label> -- <cmd>
```

A raw `vitest` bypasses it and `hook:load-guard` blocks it. macOS ships neither
`flock(1)` nor `timeout(1)` — `lib/govern.sh` rebuilds both out of `mkdir(2)`
atomicity and bash job control. That absence is the whole reason the wrapper
exists.

---

## 2 · Run a cycle

```bash
bash .claude/scripts/do-tier.sh    # what tier is this REALLY? run it first
/do <client-or-feature>            # the spine, tier-pruned
```

Run `do-tier.sh` against the real file list **before** writing a plan. It is the
repo's own sizer, and it will often tell you that a job you were about to give
nine cycles is a FIX. Believe it.

**Every branch lives in a worktree cut from `main`:**

```bash
bash .claude/scripts/do-auto.sh <slug> --setup-only
```

Never switch HEAD in the shared tree — `hook:branch-pin` blocks it, and
concurrent sessions would otherwise pull each other onto the wrong branch.

---

## 2b · The fleet — fan out, but only after you measure

**Explicit opt-in.** A fleet spawns many agents and costs real tokens. Never
infer it. Say `ultracode`, or ask for a fleet in your own words, or run
`/vespio fleet` — otherwise work solo.

### Measure first, or nine fleets agree on a wrong premise

Fleets given identical facts cannot drift. Fleets given only a task description
will. So build ONE measurement pack before you launch anything, and paste it
**verbatim** into every fleet prompt.

```bash
bash .claude/scripts/machine-check.sh            # what the box can afford
bash .claude/scripts/do-tier.sh                  # what tier the work really is
node .claude/scripts/chrome.mjs <url> --text     # what a page ACTUALLY renders
```

A pack is live probes, never file reads. **Declared is not wired is not
configured is not reachable is not working from where the code runs.** Every
launch-blocking finding worth having comes from a probe; none would have been
caught by reading source.

### The board

One fleet per client node, plus the shared surfaces. Each owns its own tree, so
they cannot collide on a write:

```
  clients/alice           clients/mover          site/
  clients/elitemoversca   clients/moverchat      ai/agents/
  clients/family-rentals  clients/movers-demo    packages/
  clients/maestromovers   clients/servicio-express
  clients/themoverlist    clients/therooferlist
```

**Writers get a worktree; read-only and doc-only fleets do not need one.**

```bash
bash .claude/scripts/do-fleet.sh          # rank + launch, memory-priced
bash .claude/scripts/do-auto.sh <slug> --setup-only   # one worktree by hand
```

`do-fleet.sh` prices concurrency in **memory, not cores**, and names the binding
constraint on its ranking line. It only ever lowers the count.

### Claim before you forage

Two fleets picking the same job is the failure worktrees do **not** prevent —
worktrees stop write races, nothing stops duplicated *selection*. Read the
claims first. A claim is an evaporating lease, not a mutex: a dead worker's
claim expires, where a mutex would deadlock.

```
  ant                    radio                  here
  ───                    ─────                  ────
  deposit  ──────────▶   transmit   ─────────▶  claim the region
  read the trail ────▶   carrier sense ──────▶  read claims first
  evaporate ─────────▶   timeout    ─────────▶  the lease expires
  alarm    ──────────▶   jam        ─────────▶  warn the path
```

**Exclusion for files and machine gates; stigmergy for task selection.** For
machine resources use `gate_lock` — `mkdir(2)` is atomic; a read-then-write is
not.

### Four prompt rules, each bought with a real mistake

- **Never spend a client's money to prove a point.** One audit billed real API
  credit demonstrating a hole it had already proven from code. Once the door is
  open, reason from source — and say in the prompt that you did.
- **Never simulate a run and report it as one.** Say so and STOP. A fabricated
  run report poisons every decision downstream of it.
- **Give a legitimate "no change needed" exit**, or a fleet will punch a hole in
  something that worked to make a page prettier.
- **Name the forbidden sentence.** Have each fleet quote verbatim the
  client-facing sentences that would be FALSE, so nobody ships one by accident.

### Then join

**One fleet folds the others' findings back into a single doc.** Nine fleets
that never reconcile are nine opinions. Kill any fleet the moment its premise
dies — a fleet still building against a design you changed is worse than no
fleet.

---

## 3 · The law

1. **Probe before you read.** A file that exists is not a page that renders, and
   a route that returns 200 is not a route that landed — a signed-out
   `/u/<slug>/*` redirects to `/signin`, which renders 200 with no console
   errors. A route counts as proven only if the run **ended** on the path you
   asked for.
2. **Default REFUTED.** No quoted stopping line means not proven. Say "not
   proven" rather than "probably fine".
3. **Two instances of one defect shape means fix the seam, never the sites.**
4. **Never simulate a run and report it as one.** If you cannot execute for real,
   say so and stop.
5. **"No change needed" is a legitimate exit.** Say it rather than inventing work.
6. **Name the forbidden sentence.** For anything a client will read, quote
   verbatim the sentences that would be false, so nobody ships one by accident.

---

## 4 · Where the harness comes from

`.claude/` in this repo is **generated output**, synced one-way from the `one-ie`
monorepo by `vespio-sync.sh` — which is classified `monorepo-only` and
deliberately does **not** ship here. So:

- **Never hand-edit `.claude/`.** The next sync overwrites it. If something is
  wrong or missing, say so in `space:vespio`; it gets fixed upstream and
  re-synced.
- **A manifest decides what ships**, not taste. Every upstream script is
  classified `portable`, `needs-env`, or `monorepo-only`, and an *unclassified*
  script does not ship — silence is not a licence.
- **What is deliberately absent:** the five-service deploy pipeline, the `text/`
  promise layer, and the `schema/`-dependent skills (`typedb`, `sdk`, `mcp`,
  `cli`, `puck`, `promise-*`). None of them have a tree to assert against here.
  Their absence is a decision, not a gap.

---

## 5 · Talk to the other side

```bash
.claude/scripts/cc-connect.sh listen    # once per session
/chat                                   # read
/chat "message"                         # send
```

Inbox on the web: **one.ie/u/vespio/in**

---

## Don't

- Don't hand-edit `.claude/` — it is generated. Change it upstream.
- Don't run a raw `vitest`. Use `gate-run.sh`, or the governor cannot see you.
- Don't blanket-stage. Concurrent sessions mean a neighbour's uncommitted work
  gets swept into your commit. Stage by explicit path, always.
- Don't switch HEAD in the shared tree. Branch work goes in a worktree.
- Don't plan in days or weeks. Tasks, then waves, then cycles.
