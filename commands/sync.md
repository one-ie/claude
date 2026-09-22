# /sync

**Skills:** `/typedb` (loop queries & writes) · `/signal` (per-loop outcomes, L4 payment emissions)

Reconcile substrate state — report the growth loops, fire the on-demand ones, absorb markdown.

**Where the loops actually run:** L3/L5/L6 are LIVE on the **channels worker's Cloudflare cron** (`channels/src/cron.ts`, triggers in `channels/wrangler.toml`, re-enabled 2026-06-28). There is no `/api/tick` aggregator — the world breathes on cron, not on request. `/sync` therefore has two jobs: fire the on-demand loops that have real endpoints, and report the state of the ones that run themselves.

## Loop reality map (verified 2026-07-02)

| Loop | Mechanism | Status | On-demand handle |
|------|-----------|--------|------------------|
| L1 tasks | `do-rank.py` → local `todo.md` (+ Stop/SessionStart hooks) | LIVE (local) | `python3 .claude/scripts/do-rank.py` |
| L3 fade | channels cron `fade-tick` daily, rate 0.05 — TypeDB + D1 `claw_paths` | LIVE | `POST /api/fade` (web) |
| L4 pay | signal with payment data → path revenue | LIVE | `POST /api/signal/<receiver>` |
| L5 evolve | channels cron `evolution-tick` hourly → `agents:evolve` signal | LIVE | `POST /api/signal/agents:evolve` |
| L6 know | channels cron `harden-tick` hourly (D1 strength≥10 → TypeDB hypotheses, via `rememberHypothesis`) | LIVE (cron only) | **no HTTP door** — `learning:know` is unregistered |
| L7 frontier | read surface only — no detection job exists | READ-ONLY | `GET /api/frontiers` |

**Not built (do not invoke, do not describe as live):** `GET /api/tick`, `POST /api/tasks/sync`, `src/engine/{doc-scan,task-parse,reusable-tasks}.ts`. The `sync-todo-docs.sh` hook that best-effort-POSTed `/api/tasks/sync` was removed 2026-09-05 (it only ever no-op'd). If a tick aggregator is ever wanted, it's a `/do` cycle (thin web route composing `fade()` + `agents:evolve` + a harden receiver that must first be BUILT + frontiers read), not a doc edit.

## Nouns

| Noun | What | Loop |
|------|------|------|
| *(default)* | Verify + rank todos + fire on-demand loops + report | L1, L3-L7 |
| `todos` | `do-rank.py` — rank `text/*-todo.md` into `todo.md` | L1 |
| `agents` | Scan agent `.md` frontmatter (`channels/src/lib/agent-md.ts` / `web/src/lib/agent-md.ts`) → sync units + skills + subscriptions to TypeDB | L1 |
| `fade` | Fire L3 once — asymmetric decay | L3 |
| `evolve` | Fire L5 once — rewrite struggling agents | L5 |
| `know` | **Read** L6 — no on-demand door; `harden-tick` is the only writer | L6 |
| `frontier` | Read L7 — current frontiers (detection job unbuilt) | L7 |
| `pay <receiver> <amt>` | Emit L4 payment signal | L4 |
| `<path>` | Absorb a markdown file/dir — extract concepts (no harden door; see below) | L6 |

## Steps

### *(default)*

1. `(cd one.ie/web && bun run verify)` — W0 gate (skip if already passed this session). The `cd` is required: there is no root `package.json`, so a bare `bun run verify` from the repo root errors with "Script not found".
2. `python3 .claude/scripts/do-rank.py` — rank + report the task queue
3. Fire on-demand loops against the local dev server (or `ONE_API_URL`):
   `POST /api/fade` · `GET /api/frontiers` — L6 has no on-demand door (below)
4. Report:
   ```
   Queue:    N ready  M gated  K faded  (top slug + score)
   L3 fade:  N paths decayed
   L6 know:  N highways hardened  M hypotheses written
   L7:       N frontiers (read)
   Cron:     L3 daily · L5/L6 hourly on channels (no action needed)
   ```

### todos

1. `python3 .claude/scripts/do-rank.py` (add `--tasks` for the tagged-signal view, `--json` for the fleet)
2. Report: ready/gated/faded counts, top-N slugs, fleet waves.

### agents

1. Scan agent `.md` files (`one.ie/ai/agents/`, `channels` agent dirs)
2. Parse frontmatter via the shipped parser (`channels/src/lib/agent-md.ts` or `one.ie/web/src/lib/agent-md.ts`) → `AgentSpec[]`
3. Sync to TypeDB: unit + skills + capabilities + group membership; register `meta.subscribes` tags via `subscriptions:register`
4. Report: agents synced, skills synced, subscriptions registered.

### fade

1. `POST /api/fade` (web) — same decay the daily channels cron runs
2. Asymmetric: resistance forgives 2× faster than strength decays
3. Report: paths decayed, net strength/resistance changes.

### evolve

1. **Select the targets first — the receiver does not.** The hourly
   `evolution-tick` (`channels/src/cron.ts`) runs the TypeDB query
   `match $a isa actor, has aid $id, has success-rate $r, has sample-count $n; $r < 0.5; $n >= 20; select $id;`
   and then posts **one signal per uid**. A bare `POST /api/signal/agents:evolve`
   with an empty body targets nobody — it just writes a signal row.
2. For each selected uid: `POST /api/signal/agents:evolve` with
   `{ "data": { "uid": "<aid>" } }` (the cron posts to `$ONE_EVENTS_URL`; locally that is `http://localhost:4321`).
3. Report: agents evaluated, agents evolved, generation numbers.

### know

1. **There is no manual door.** `learning:know` is in no registry, so
   `POST /api/ask/learning:know` 404s — this subcommand cannot force a harden.
   The promotion happens only on the hourly `harden-tick` cron
   (`channels/src/cron.ts:121`), which reads D1 `claw_paths` where
   `strength >= 10` and calls `rememberHypothesis` directly.
2. Report what the cron last wrote: highways hardened, hypotheses written. To
   verify, read the hypotheses rather than trying to trigger a write.

### frontier

1. `GET /api/frontiers` — read current frontiers from TypeDB
2. Report: frontiers listed. **Detection** (finding new unexplored clusters) has no job yet — flag it, don't fake it.

### pay

1. Parse `<receiver>` and `<amount>` from `$ARGUMENTS`
2. `POST /api/signal/<receiver>` with `{ data: { type: "payment", amount } }`
3. Report: payment signal sent, path updated, revenue total for that path.

### `<path>`

1. Read markdown file or directory at `<path>` from `$ARGUMENTS`
2. If directory: scan all `*.md` files recursively
3. Extract concepts → **no door exists** (`learning:know` unregistered); record them in `text/` and let `harden-tick` promote what earns strength (or agent specs → the `agents` flow)
4. Report: files processed, entities written.

---

*The world breathes on cron. `/sync` reads the pulse and squeezes the on-demand loops — it does not pretend to be the heart.*
