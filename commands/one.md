# /one — the desk and the board

```
   ██████╗ ███╗   ██╗███████╗
  ██╔═══██╗████╗  ██║██╔════╝
  ██║   ██║██╔██╗ ██║█████╗      one tab · many fresh minds
  ██║   ██║██║╚██╗██║██╔══╝      chat the CEO · she routes
  ╚██████╔╝██║ ╚████║███████╗
   ╚═════╝ ╚═╝  ╚═══╝╚══════╝
```

One word for the whole company. Two modes, decided by whether you typed
anything after it.

| You type | You get |
|---|---|
| `/one` | **the board** — the standing fleet (§1 onward). Batch, opt-in, expensive. |
| `/one <anything>` | **the desk** — you talk to the CEO; the CEO routes to fresh subagents and joins the answers. Cheap, conversational, all day. |
| `/one @cto <anything>` | **direct** — skip the CEO, hand it straight to that agent. |

---

# THE DESK — `/one <anything>`

## Why it exists

The problem it solves is one sentence: **you keep opening new tabs to get a
clean context.** A new tab costs you the thread — the decision you made two
hours ago, the file you already ruled out, the thing you already tried.

A subagent already gives you the clean context. `Agent(subagent_type: <anything
but "fork">)` starts **fresh** — no inherited history, no accumulated noise.
That is exactly what a new window buys, without losing the thread. `"fork"` is
the opposite: it inherits everything, and is the wrong tool here.

So the desk inverts your habit. **One tab. Many fresh contexts.** The tab holds
the conversation; the fresh contexts do the work and hand back a paragraph.

## What the main thread is allowed to hold

The desk only works if the tab stays light. The main thread holds:

- the CEO's framing (2–3 sentences per request)
- each agent's **returned summary**
- the decisions you and the CEO made

The main thread never holds file dumps, sweep output, test logs, or search
results. Those live and die inside the subagent. **If reading it would cost the
tab more than 200 lines, it belongs in a subagent** — that is the whole rule.

## You are talking to the CEO

When `/one` carries an argument, the main session **is** the Chief Executive
(`one.ie/ai/agents/ceo/agent.md`). Not a router — an executive. Per that file:

**1. Form a view first.** 2–3 sentences: what is actually being asked, what the
business needs right now, what a good outcome looks like. Your actual opinion —
not a hedge, not the request read back.

**2. Then route — through the world, or to a named owner. Never through a
`route:to-<department>` name.** Those six names are in no registry: an emit to one
dissolves and still answers `ok:true`, so the routing act reaches nobody
(`text/coordination-plan.md` R3; the account is in `.claude/agents/ceo.md`). Two real
doors replace them — `signal("world", { tags })` lets the stake decide who hears it,
and `tasks:reassign` hands a named owner the row.

| Request is about | Tags for `signal("world", { tags })` | Director, when you name one |
|---|---|---|
| brand, demand, campaigns, copy, ads, SEO | `marketing` | `cmo` |
| pipeline, deals, pricing, demos, onboarding | `sales` | `cro` |
| support, churn, CSAT, success, privacy | `service` | `cxo` |
| community, moderation, events, referrals | `community` | `cco` |
| builds, workflows, skills, `/do`, anything code | `engineering` | `cto` |
| spans two or more domains | all the tags it spans, in ONE signal | — never split-route; the world fans it |

The tags are **bare words** — `marketing`, never `lifecycle:marketing`. A namespaced
tag matches zero subscribers.

**3. Own the framing.** Directors execute. You are accountable for whether the
right question was asked. A brief missing its persona, its KPI, or its domain
gets rejected with exactly what is missing — not guessed at.

## Routing without a director

A director is worth a hop when the work needs **deciding which work to do**. It
is pure overhead when the owner is obvious. Read the request:

- **Obvious owner** → spawn the specialist directly. "rewrite the pricing
  headline" is `copywriter`, not `cmo → copywriter`.
- **Needs a decision** → spawn the director, take its plan, then spawn what it
  named. "our activation is flat, what do we do" is `cmo` first.
- **Independent work** → spawn them **in one message** so they run
  concurrently. Two agents in one block is two agents at once; two blocks is
  two agents in sequence.
- **Dependent work** → chain it through one agent with ordered phases. Two
  agents building either end of the same seam will disagree, and the
  disagreement surfaces at merge — the worst place to find it. (§0.5.)

## The roster

80 platform agents are spawnable by name. They are **generated**, not written
by hand:

```bash
node .claude/scripts/one-agents.mjs --chart   # the routing table: agent · tier · staked tags
node .claude/scripts/one-agents.mjs           # regenerate into .claude/agents/
node .claude/scripts/one-agents.mjs --check   # fail if the output drifted from source
```

Source of truth is `one.ie/ai/agents/**/*.md` — the same files that run the org
chart on the platform. Edit the platform agent, re-run the generator. Never
hand-edit a file carrying the `GENERATED by .claude/scripts/one-agents.mjs`
marker; the regenerate sweep is keyed on that marker, which is also what keeps
it from touching the hand-written `w1`–`w4`.

**The roster is read at SESSION START.** Regenerating mid-session does not make
a new agent spawnable — restart first. A spawn that fails with *"Agent type 'x'
not found"* listing only the old roster is this, not a broken file.

The heads: `ceo` · `cmo` (22 marketing) · `cro` (sales) · `cxo` (service) ·
`cco` (community) · `cto` (engineering).

Engineering (10): `cto` heads `architect` · `review-engineer` ·
`test-engineer` · `security-auditor` · `perf-engineer` · `release-manager` ·
`incident-commander` · `tech-writer` · `workflow-optimiser`. All ten stake the
same two tags, so pick by **tagline**, not by tag.

For `/do` work specifically, keep routing to the harness agents — they are the
ones wired into the engine and carrying its contract: `w1-recon` · `w2-decide` ·
`w3-edit` · `w4-verify`, plus `Explore` for fan-out search.

## What every spawned agent inherits — and does not

**A subagent inherits NO parent CLAUDE.md.** That is the price of the fresh
context, and it is why every generated agent has the locked substrate facts
inlined in its body: the 6 dimensions, the 6 verbs, bare-tags-only, structural
time, where code lives, which test lane it ran. Without that inline block the
same freshness that fixes your tab problem makes every agent violate the
schema.

It still inherits nothing about **this conversation**. So the prompt you hand
it must carry every fact it needs — the file path, the measurement, the
constraint, the decision already made. A prompt that says "continue the work" is
a prompt to an agent that has no idea what work.

## Cost

The desk is cheap because the tab stays small; it is not free. A director hop is
Opus. Prefer:

1. the specialist directly, over director → specialist
2. one agent with ordered phases, over N agents on one seam
3. `Explore` (read-only, returns conclusions) over a general agent that returns files

Bare `/one` — the board below — is the expensive gesture and stays explicit
opt-in. The desk is not.

## Don't

- **Don't use `subagent_type: "fork"`** for a fresh context. Fork inherits
  everything; it is the tab you were trying not to open.
- **Don't relay a file dump into the tab.** Relay the conclusion. The agent's
  report is not shown to the operator — say what matters, in your words.
- **Don't spawn an agent that already ran.** Continue it with `SendMessage` and
  it keeps its context; a new `Agent` call starts over.
- **Don't invent an agent name.** `--chart` is the list. A name not on it does
  not exist.
- **Don't fabricate a pending agent's result.** It arrives as a notification.
  If asked before it lands, say it is still running.

---

# THE BOARD — bare `/one`

One word to launch the whole board. Every fleet probes production rather than
reading source, and all of them are synchronised by one shared measurement pack.

**Explicit opt-in.** This spawns many agents and costs real tokens. Never infer
it — it is the same gesture as `ultracode`. The desk above is not.

---

## 0 · RESUME FIRST — pick up where the last harness left off

**Any harness can continue this board.** A session that runs out of credits does
not lose its fleets: every Workflow run persists its script and a journal, and a
resume replays every unchanged agent from cache for free — only edited or new
agents actually run.

```bash
# what was in flight, and how far each got
bash .claude/scripts/one-resume.sh            # the board
bash .claude/scripts/one-resume.sh --deploy   # the board, then land+ship what is ready
```

Then, per fleet still worth continuing:

```
Workflow({ scriptPath: "<script path from the board>", resumeFromRunId: "<runId>" })
```

**Read `text/HANDOFF.md` before spawning anything.** It carries the fleet table,
the branches, the findings that change the design, and the queue of work that was
requested but never built. Re-launching a fleet whose work already landed is the
most expensive mistake available here.

Order, always: **resume → land → deploy → only then fan out.** Landing costs no
model tokens at all; fanning out costs the most.

---

## 0.5 · Chain, don't scatter

When several fleets touch one flow — sell → ads → sell-credits, with upsells
tracked along it — they are ONE chain, not N independent fleets. Fan out on
*independent* work; chain dependent work through a single fleet with ordered
phases, so a later stage reads the earlier stage's real output instead of
guessing at it. Two fleets building either end of the same seam will disagree,
and the disagreement surfaces at merge, which is the worst place to find it.

---

## 0 · Price the box BEFORE you fan out

The binding constraint is **memory, not cores**. A cycle costs ~2GB (vitest
driver + 4 forks + tsc + node). On a 10-core/24GB box, `cores - 2` would
authorise 8 concurrent worktrees — ~16GB of gates before editors, sessions and
the OS get a byte. `gate_headroom` prices it properly and only ever *lowers* the
count.

```bash
bash .claude/scripts/fleet-status.sh           # the board: box · slots · fleet · funnel
bash .claude/scripts/machine-check.sh --watch  # live: load · swap DIRECTION · orphans
```

`fleet-status.sh` costs nothing — no agents, no network. It prints how many
cycles the box can **afford right now**, which fleet docs exist and how many
`[NOT WIRED]` / `[NOT MEASURED]` items each still carries, and the four funnel
numbers that decide whether any of it matters. Run it before and after.

**Read swap direction, not the swapin counter** — swapins spike during recovery
too. Thrash is pages going *out* while free memory shrinks.

| Knob | Default | Raise when |
|---|---|---|
| `GOVERN_MAX_GATES` | 2 | never, on this box |
| `GOVERN_GB_PER_CYCLE` | 2 | your gates got lighter |
| `GOVERN_RESERVE_GB` | 2 | you want more headroom, not less |
| `VITEST_MAX_FORKS` | 4 | a deliberate full-throughput CI run |

**Editors are the other half of the bill.** Each worktree is ~120MB on disk and
its own tsserver in RAM — 3 worktrees measured at 2.3–3.0GB of language servers,
entirely outside the governor. `.vscode/settings.json` and `.cursorignore`
exclude `.do-worktrees`; Zed needs `file_scan_exclusions` in user config.

**Sweep before launching**, or you inherit the last run's ghosts:

```bash
git worktree prune
git worktree list                              # anything finished? remove it
pkill -f 'esbuild|vite/node_modules' || true   # orphans outlive their fleet
```

---

## 1 · Re-measure — the pack goes stale

Nine fleets fed a wrong premise all reach wrong conclusions in unison. These
were true 2026-08-25; every one is a live probe, not a file read.

```bash
DB=one.ie/web/.wrangler/state/v3/d1/miniflare-D1DatabaseObject/e3267303*.sqlite
sqlite3 $DB "SELECT COUNT(*) FROM owners;"                         # 68
sqlite3 $DB "SELECT COUNT(*) FROM owners WHERE charges_enabled=1;" # 0
sqlite3 $DB "SELECT COUNT(*) FROM wallets WHERE sui_address!='';"  # 0  <- THE WALL
sqlite3 $DB "SELECT source,COUNT(*),SUM(amount_credits) FROM credit_grants GROUP BY source;"

curl -s -X POST https://one.ie/api/storefront/checkout \
  -H 'content-type: application/json' \
  -d '{"workspace":"one","ppid":"price_jmujrzb8r7h9sy7c","rail":"card"}' | head -c 200
curl -s 'https://one.ie/api/pay/credits/quote?amountUsd=1' | grep -o '"chain":"SOL"[^}]*'
```

**Known-stale in this file, fix before reusing:** engineering and finance are
NOT new departments — they already exist across five surfaces (`navigation.ts:4`,
`role-types.ts:37`, `urls/law.ts:62`, and live rooms). Only **design** and
**analytics** are new. And 29 agents fall into a `governance` sink because their
declared `domain:` is outside the union — reclassify those before adding more.

---

## 2 · Claim before you forage — no collisions

Two fleets independently built the same skill executor
(`execute-skill.ts` **and** `executor.ts`). That is duplicated *selection*, not a
file-write race — worktrees already prevent those. The fix already ships:
`tasks:claim` is an **evaporating lease**, `CLAIM_LEASE_TTL_MS = 45 min`
(`resolvers/tasks.ts:93`). A dead worker's claim expires; a mutex would deadlock.

```
  ant                    radio                  here
  ───                    ─────                  ────
  deposit  ───────────▶  transmit    ────────▶  claim the region
  read the trail ─────▶  carrier sense ──────▶  read claims first
  evaporate ──────────▶  timeout     ────────▶  45-min lease TTL
  alarm    ───────────▶  jam         ────────▶  warn the path
```

For machine resources use `gate_lock` — `mkdir(2)` is atomic; a read-then-write
to D1 is not. **Exclusion for files and gates; stigmergy for task selection.**

---

## 3 · The fleet

```
    ┌── probe ──┐
    │           ▼
  [pack] ──▶ ┌─────────────────────────────────┐
             │ security   wallet    keys       │
             │ skill      analytics analyst    │  ◀── same pack,
             │ departments colony   dev-env    │      no conductor
             └─────────────────────────────────┘
                          │
                          ▼
                    [ join → text/one.md ]
```

| Fleet | Owns | Lands in |
|---|---|---|
| `security` | the gateway seam — anon spend, SOL rail | `text/auth-enforcement-todo.md` |
| `wallet` | the master ladder, paper that actually restores | `text/wallet-durability.md` |
| `keys` | `/w/keys`, devices, the adoption ceremony | `text/keys.md` |
| `skill-engine` | 87 bodies + one executor (dedupe first) | `text/skill-engine.md` |
| `analytics` | the 8-stage funnel, honest zeros | `text/journey-analytics.md` |
| `analyst` | reads every signal, fires workflows | `text/analyst.md` |
| `departments` | design + analytics only; drain `governance` | `text/departments.md` |
| `colony` | claim-lease selection | `text/colony.md` |
| `dev-env` | one passkey both hosts, redirects | `text/dev-environment.md` |

---

## 4 · The law

1. **Probe before you read.** Every launch-blocking finding came from a probe.
   Mint a real checkout. Read a D1 *count*. Probe an API *from where code runs*.
2. **Synchronise by shared evidence, not orchestration.** One pack, verbatim, in
   every prompt.
3. **One fleet joins** — folds findings into `text/one.md`, which already says
   *the specific doc wins, the spine reconciles*.
4. **Default REFUTED; demand the quoted stopping line.** No line ⇒ not proven.
5. **Two instances of one shape ⇒ fix the seam.**
6. **Kill a fleet the moment its premise dies.**

Four prompt rules, each bought with a real mistake:

- **Never spend money to prove a point** — one audit billed ~$0.22 of DataForSEO.
- **Never simulate a run and report it as one.** Say so and STOP.
- **Give a "no change needed" exit**, or a fleet punches a hole in the payment
  path to make a landing page prettier.
- **Name the forbidden sentence** for anything customer-facing.

**Index fix tasks by NAME, never positionally.** A `.filter(Boolean)` on scopes
shifted indices and handed each fix the wrong scope — both silently returned null
and the run reported "complete".

---

## 5 · Build and deploy — fast by construction

```bash
DEV_SKIP_GATE=1 bash .claude/scripts/deploy-dev.sh   # ~30s -> dev.one.ie
bash .claude/scripts/deploy-dev.sh                    # + fast lane
./deploy                                              # FULL gate -> one.ie
```

Where the speed came from, measured:

| | before | after |
|---|---|---|
| `tsc --noEmit` | 60.0s | **8.7s** (`incremental` + `tsBuildInfoFile` + `skipLibCheck`) |
| dev deploy | — | 23s upload · 4s assets · 3s triggers |
| tests selected | 1,044 files | 35 pinned + `vitest related` |

The tests were never the bottleneck — a cold full typecheck on every pass was.

Two invariants the fast lane must keep: **an empty diff falls back to the FULL
suite** (never to a pass), and **the pins always run** — `vitest related` walks
the import graph, and config/parity/boundary gates import nothing from what they
guard. Take the FULL lane when the change touched `schema/`, `packages/sdk/`, or
auth — that is exactly where `related` misses.

`deploy-dev.sh` regenerates its config from the astro build output every run, so
it cannot drift from what production ships, and strips `triggers`/`crons` — the
dev worker shares production's D1 and KV, and the first deploy inherited six
prod schedules. **Dev observes prod data; it must never drive prod's clock.**

---

## 6 · Standing state — OPEN

A fix on main is not a fix in prod until the worker is redeployed.

| Open | Where | Whose call |
|---|---|---|
| `auth:"member"` enforced NOWHERE — gateway stamps trust on anon requests | `api/src/substrate-binding.ts:46` + `ask:276` | fleet |
| Anonymous DataForSEO spend | `seo.ts:73` | fleet |
| SOL advertised, cannot settle | `quote.ts:60-64`, `solana.ts:66` | fleet |
| 24 words import to a DIFFERENT, EMPTY address | `derive-multichain.ts` HKDF vs BIP-44 | fleet |
| Undecryptable vault envelope, globally mounted | `PasskeyUpgradePrompt.tsx:201` | fleet |
| Stripe in test mode in production | `wrangler.toml:110` | **operator** |
| Paper backup of the Sui deploy key | `~/sui-mainnet-deploy-key.txt` | **operator** |

**CLOSED this session:** the unauthenticated credit mint —
`neuterSelfBootstrapPayload` (`receiver-envelope.ts:207`) strips
parent/plan/credit/markup/cap/brand/agents from a self-bootstrap payload.

---

## Don't

- Don't launch while fleets are in flight. Land the board, don't widen it.
- Don't let a fleet deploy. That is the operator's call.
- Don't skip the join. Nine fleets that never reconcile are nine opinions.
- Don't run a raw `vitest` — it bypasses the governor and `hook:load-guard`
  blocks it. Everything through `gate-run.sh`.
