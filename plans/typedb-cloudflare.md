# TypeDB ↔ Cloudflare

How TypeDB is loaded, cached, and served across the CF edge — and how to make it fast, stable, secure, and simple.

---

## What exists today

### Topology

```
Browser / SDK
    │
    ▼
one.ie (CF Worker)          channels/ (CF Worker)
    │ substrate.ts               │ substrate.ts
    └────────────┬───────────────┘
                 │ POST /typedb/query  (Bearer GATEWAY_API_KEY)
                 ▼
           api.one.ie (CF Worker — the only door to TypeDB)
                 │
                 │ JWT auth (admin + password → /v1/signin)
                 │ token cached module-scope, 60s margin
                 ▼
          TypeDB Cloud (flsiu1-0.cluster.typedb.com:1729)
                 ▲
                 │ GET /api/export/{paths,units,skills,highways,toxic}
                 │ every 1 minute
          sync/ (CF Scheduled Worker)
                 │
                 ▼
             CF KV (5 snapshots: paths/units/skills/highways/toxic)
                 ▲
                 │ isToxicFast(), pollOutcome()
          module-scope memos (toxicMemo 5min TTL, tokenCache JWT)
```

### The three layers

| Layer | Contents | Freshness | Owner |
|---|---|---|---|
| TypeDB Cloud | Canonical truth — paths, actors, signals, hypotheses | Real-time | api/ only |
| CF KV | 5 hot snapshots + signal outcome keys | ≤ 1 min stale | sync/ writes |
| globalThis | JWT token, toxicMemo verdicts | 5 min TTL | per-isolate |

### Hot-path timings (current)

```
signal(receiver)
  ├─ isToxicFast()        → KV read (~20ms) or memo hit (0ms, 5min stale)
  ├─ callGateway(tql)     → api.one.ie → TypeDB (~50ms)
  ├─ writeSignal()        → KV write (~5ms)
  └─ response             ~75ms total (cold), ~55ms (memo hit)

pollOutcome(id)           → KV read every 250ms, up to 40 reads over 10s

mark(src, tgt)
  ├─ callGateway(tql)     → TypeDB write (~50ms)
  ├─ D1 write             → fire-and-forget
  └─ KV toxic invalidate  → KV delete (~5ms)
                          ~55ms total, KV now 1min stale
```

### What's broken

**State is distributed across isolates.** Every CF Worker isolate carries its own `toxicMemo` and `tokenCache`. They diverge. A `mark()` on one isolate doesn't update the memo on another.

**Reads are stale.** KV snapshots are up to 1 minute behind TypeDB. After a `mark()`, the graph is updated but nothing that reads via KV sees it for 60 seconds.

**Outcomes are polled.** `pollOutcome()` fires every 250ms for up to 10s — 40 KV reads in the worst case. Under load this accumulates.

**Substrate is duplicated.** `one.ie/web/src/lib/substrate.ts` and `channels/src/substrate.ts` are nearly identical (~400 lines combined). Three separate retry implementations. When the policy changes, three files change.

---

## The solution: BrainDO

The graph fits in RAM. Load it once into a Durable Object. Serve everything from memory.

### Size estimate

| Snapshot | 10k-edge graph | 100k-edge graph |
|---|---|---|
| paths | ~800 KB | ~8 MB |
| units | ~300 KB | ~3 MB |
| skills | ~100 KB | ~1 MB |
| toxic (derived Set) | ~50 KB | ~500 KB |
| **total** | **~1.3 MB** | **~12 MB** |

A DO has 128 MB RAM. The entire graph fits at any realistic scale.

### Architecture after BrainDO

```
TypeDB Cloud (durable truth)
    ↑ write-through (batched, 100ms window)
    ↓ reload on hash mismatch (DO alarm, every 60s)
    ↕ DO writes KV snapshot on hash change (disaster-recovery)

BrainDO — instance name: "global"  (locationHint: 'enam' — near TypeDB US cluster)
    ├── paths:    Map<"src→tgt", { strength, resistance }>
    ├── units:    Map<id, Unit>
    ├── skills:   Map<id, Skill>
    ├── toxicSet: Set<"src→tgt">         ← precomputed, O(1)
    ├── writeQueue: persisted Map        ← state.storage.put() before flush; 100ms window
    └── WebSockets: hibernated sockets  ← WsHub absorbed

Workers (stateless — call brain via api.one.ie HTTP, not direct DO stub)
    one.ie  ·  channels         →  POST https://api.one.ie/brain/*  (GATEWAY_API_KEY)
    api (gateway)               →  BRAIN.get(idFromName('global')).fetch(...)
```

`one.ie` and `channels` have no `BRAIN` namespace binding — they call through the api.one.ie gateway using the existing `GATEWAY_URL` + `GATEWAY_API_KEY` pattern. The gateway holds the only DO stub. This keeps the DO access pattern identical to the current `callGateway` pattern and requires no new wrangler bindings in downstream workers.

KV becomes disaster-recovery only — not on the hot path. The DO writes to KV after each reload so cold starts can recover from KV if TypeDB is slow.
sync/ Job 1 (TypeDB → KV) is replaced by the DO alarm handler.
WsHub is absorbed; one fewer DO binding everywhere.

### Hot-path timings after

```
signal(receiver)
  ├─ brain.isToxic()      → DO stub → Set.has() (~2ms, always fresh)
  ├─ brain.route()        → DO stub → Map.get() (~2ms)
  ├─ typedb write         → async, off the response path
  └─ response             ~4ms total, zero staleness

pollOutcome(id)           → gone. brain pushes via WebSocket on write.

mark(src, tgt)
  ├─ brain.mark()         → DO stub → memory patch (~2ms)
  │                         TypeDB write batched async (100ms window)
  │                         WebSocket push to subscribers (instant)
  └─ response             ~2ms total, graph fresh immediately
```

### BrainDO interface

```typescript
// Routes (all reads synchronous from memory)

GET  /toxic?src=A&tgt=B            → { toxic: boolean }       O(1) Set.has()
GET  /path?src=A&tgt=B             → { strength, resistance } O(1) Map.get()
GET  /neighbors?actor=A            → [{ target, strength, resistance }]
GET  /graph                        → full dump (debug only)

POST /mark    { src, tgt, delta=1 }          → { ok: true }  patch memory + queue TypeDB write
POST /warn    { src, tgt, delta=1 }          → { ok: true }  patch memory + queue TypeDB write
POST /fade    { group }                      → { ok: true }  apply fade-rate to group paths
POST /notify  { id, outcome, payload? }      → { ok: true }  broadcast signal outcome to subscribers

GET  /ws                           → WebSocket upgrade (absorbed from WsHub)
POST /send  { message }            → broadcast to all connected sockets
GET  /count                        → { connected: number }
```

### BrainDO — implementation shape

```typescript
export class BrainDO {
  private state: DurableObjectState
  private env: Env

  private paths    = new Map<string, { strength: number; resistance: number }>()
  private units    = new Map<string, Unit>()
  private skills   = new Map<string, Skill>()
  private toxicSet = new Set<string>()

  private writeQueue = new Map<string, { markDelta: number; warnDelta: number }>()
  private writeTimer: ReturnType<typeof setTimeout> | null = null
  private loaded = false
  private graphHash = ''

  // Write queue is persisted to DO storage before each flush so mutations
  // survive a DO eviction during the 100ms batch window. On cold start,
  // any queued-but-unflushed writes are replayed before serving requests.

  async fetch(request: Request): Promise<Response> {
    await this.ensureLoaded()
    const url = new URL(request.url)

    if (url.pathname === '/toxic') {
      const key = `${url.searchParams.get('src')}→${url.searchParams.get('tgt')}`
      return Response.json({ toxic: this.toxicSet.has(key) })
    }
    if (url.pathname === '/mark') {
      const { src, tgt, delta = 1 } = await request.json<Mark>()
      this.applyMark(src, tgt, delta)
      return Response.json({ ok: true })
    }
    // /warn, /fade, /path, /neighbors, /ws, /send, /graph ...
  }

  private applyMark(src: string, tgt: string, delta: number) {
    const key = `${src}→${tgt}`
    const p = this.paths.get(key) ?? { strength: 0, resistance: 0 }
    p.strength += delta
    this.paths.set(key, p)
    this.recomputeToxic(key, p)
    this.enqueueWrite(key, delta, 0)
    this.broadcast({ type: 'mark', src, tgt, strength: p.strength })
  }

  private recomputeToxic(key: string, p: { strength: number; resistance: number }) {
    const total = p.strength + p.resistance
    if (total > 0 && p.resistance / total > 0.5) this.toxicSet.add(key)
    else this.toxicSet.delete(key)
  }

  private enqueueWrite(key: string, markDelta: number, warnDelta: number) {
    const e = this.writeQueue.get(key) ?? { markDelta: 0, warnDelta: 0 }
    e.markDelta += markDelta
    e.warnDelta += warnDelta
    this.writeQueue.set(key, e)
    // Persist queue to DO storage so eviction during the 100ms window doesn't lose writes
    this.state.storage.put('writeQueue', Object.fromEntries(this.writeQueue))
    if (!this.writeTimer) this.writeTimer = setTimeout(() => this.flushWrites(), 100)
  }

  private async flushWrites() {
    const batch = [...this.writeQueue.entries()]
    this.writeQueue.clear()
    this.writeTimer = null
    await this.state.storage.delete('writeQueue')
    if (batch.length === 0) return
    // One TypeDB transaction — N match-insert clauses, one commit
    // TQL shape per edge: match $p isa path, has source "A", has target "B"; insert $p has strength += delta;
    await typedbBatchWrite(this.env, batch)
  }

  private broadcast(event: object) {
    const msg = JSON.stringify(event)
    for (const ws of this.state.getWebSockets()) {
      try { ws.send(msg) } catch { /* already closed */ }
    }
  }

  private async ensureLoaded() {
    if (this.loaded) return
    await this.reload()
    await this.state.storage.setAlarm(Date.now() + 60_000)
  }

  async alarm() {
    try {
      // GET /api/export/hash — returns { paths, units, skills, toxic } hashes only, no payloads
      const live = await fetchGraphHash(this.env)
      if (live !== this.graphHash) {
        await this.reload()
        this.broadcast({ type: 'reload', hash: this.graphHash })
      }
    } catch { /* TypeDB unreachable — serve stale memory, next alarm retries */ }
    // Replay any write queue that survived a previous eviction
    const saved = await this.state.storage.get<Record<string, { markDelta: number; warnDelta: number }>>('writeQueue')
    if (saved && Object.keys(saved).length > 0) {
      this.writeQueue = new Map(Object.entries(saved))
      await this.flushWrites()
    }
    await this.state.storage.setAlarm(Date.now() + 60_000)
  }

  private async reload() {
    // Try KV first (fast, ~10ms). Falls back to TypeDB export if KV key is missing.
    const keys = ['paths', 'units', 'skills', 'toxic'] as const
    const [paths, units, skills, toxic] = await Promise.all(
      keys.map(k => loadSnapshot(this.env, k))  // loadSnapshot: KV.get → fallback fetch /api/export/{k}
    )
    this.paths    = toMap(paths,  p => [`${p.source}→${p.target}`, { strength: p.strength, resistance: p.resistance }])
    this.units    = toMap(units,  u => [u.id, u])
    this.skills   = toMap(skills, s => [s.id, s])
    this.toxicSet = new Set(toxic.map(t => `${t.source}→${t.target}`))
    this.graphHash = fnv(paths, units, skills, toxic)
    this.loaded   = true
    // Write back to KV so future cold starts skip TypeDB
    await Promise.all(keys.map((k, i) =>
      this.env.KV.put(`snapshot:${k}`, JSON.stringify([paths, units, skills, toxic][i]))
    ))
  }
}
```

Three invariants that make this correct:

1. **Single-threaded** — no races on Maps/Sets. `applyMark` is synchronous; next request sees the update.
2. **Write batching is safe** — memory is authoritative for the DO's lifetime. If the DO restarts before a flush, `reload()` re-reads from TypeDB. mark/warn are monotone — re-applying a delta already in TypeDB is safe.
3. **Alarm ensures convergence** — if a flush fails silently, the 60s reconcile detects hash drift and reloads.

### Workers become thin

`one.ie` and `channels` have no direct DO binding — they call through the gateway using the existing `GATEWAY_URL` + `GATEWAY_API_KEY` env vars already in every worker's `wrangler.toml`. No new bindings required.

```typescript
// packages/sdk/src/brain.ts — replaces substrate hot-path in all workers (~30 lines)

export class BrainClient {
  private base: string
  private key: string

  constructor(env: { GATEWAY_URL?: string; GATEWAY_API_KEY?: string }) {
    this.base = (env.GATEWAY_URL ?? 'https://api.one.ie') + '/brain'
    this.key  = env.GATEWAY_API_KEY ?? ''
  }

  private h(): HeadersInit {
    return { Authorization: `Bearer ${this.key}`, 'Content-Type': 'application/json' }
  }

  isToxic(src: string, tgt: string): Promise<boolean> {
    return fetch(`${this.base}/toxic?src=${encodeURIComponent(src)}&tgt=${encodeURIComponent(tgt)}`,
      { headers: this.h() })
      .then(r => r.json<{ toxic: boolean }>()).then(r => r.toxic)
  }

  mark(src: string, tgt: string, delta = 1): Promise<void> {
    return fetch(`${this.base}/mark`, {
      method: 'POST', headers: this.h(), body: JSON.stringify({ src, tgt, delta })
    }).then(() => undefined)
  }

  warn(src: string, tgt: string, delta = 1): Promise<void> {
    return fetch(`${this.base}/warn`, {
      method: 'POST', headers: this.h(), body: JSON.stringify({ src, tgt, delta })
    }).then(() => undefined)
  }

  subscribe(): Promise<WebSocket> {
    return fetch(`${this.base}/ws`, {
      headers: { ...this.h(), Upgrade: 'websocket' }
    }).then(r => r.webSocket!)
  }
}
```

Inside the gateway, the `/brain/*` routes proxy to the DO stub with `locationHint`:

```typescript
// api/src/index.ts — gateway owns the only DO stub
const brain = env.BRAIN.get(env.BRAIN.idFromName('global', { locationHint: 'enam' }))
return brain.fetch(new Request('https://do' + url.pathname + url.search, request))
```

`locationHint: 'enam'` pins the DO to eastern North America, co-located with the TypeDB US cluster. Revisit when an EU TypeDB replica exists.

### Signal outcome path (C4 design)

Signal outcomes are currently written to KV by `writeOutcome()` in `substrate.ts`, then polled by `pollOutcome()`. After C4, the signal processor calls `brain.notify(id, outcome)` after writing the outcome to TypeDB. BrainDO broadcasts `{ type: 'outcome', id, outcome }` to all WebSocket subscribers. Callers awaiting the outcome receive it via `waitForOutcome(id, ws)` on the open subscription socket.

The KV outcome write (`signal:outcome:{id}`) is kept as a fallback for HTTP-only callers (MCP one-shot, CLI without WebSocket). The poll frequency drops from 250ms to 1s with a max of 3 retries — covering the edge case without burning KV reads at scale.

---

## Security hardening (standalone — BrainDO doesn't absorb these)

**G1 — TQL interpolation audit**

Signal receivers and edge identifiers are interpolated into TQL strings. TypeDB Cloud's REST API has no prepared statements, so the defense is input validation at the boundary.

Fix: audit all TQL string templates in `api/src/index.ts`. Enforce an allowlist format (`actor:task`, no arbitrary strings) on all user-controlled values before they reach TQL.

**G2 — gateway-guard over-broad Authorization check**

`gateway-guard.ts:35-49` allows a request with _any_ `Authorization` header value. A request with `Authorization: Bearer garbage` clears the guard.

Fix: check that the header matches `Bearer <known-key>`, not just that it exists.

**G3 — GATEWAY_API_KEY is write-capable and shared**

Any holder of the key can POST arbitrary TQL including schema mutations. The key is shared across `one.ie`, `channels/`, and `sync/`.

Fix: split into `GATEWAY_READ_KEY` and `GATEWAY_WRITE_KEY`. Gateway routes by key to read vs write transaction type. Write key stays server-side only.

**S1 — No circuit breaker on TypeDB fetch**

If TypeDB Cloud is down, every request hammers a fresh fetch + error, amplifying load on a degraded cluster.

Fix: module-scope circuit breaker in the gateway. After 5 consecutive 5xx in 10s, open circuit for 30s; half-open probe after cooldown. ~30 lines.

**S2 — No AbortSignal on TypeDB fetches**

Slow queries hang a CF Worker request slot for the full 60s wall-clock limit.

Fix: `AbortSignal.timeout(10_000)` on every `fetch()` to TypeDB Cloud.

---

## What disappears

| Removed | Replaced by |
|---|---|
| `toxicMemo` (5-min stale, per-isolate) | `brain.isToxic()` — always fresh, O(1) |
| `tokenCache` (per-isolate JWT) | Single JWT in DO memory, proactively refreshed |
| `isToxicFast()` + async refresh pattern | `toxicSet.has(key)` in DO |
| `pollOutcome()` (40 KV reads worst case) | WebSocket push from DO on write |
| sync worker Job 1 (TypeDB → KV every minute) | DO alarm handler (same logic, no worker) |
| KV as hot-path read cache | KV as disaster-recovery snapshot only |
| WsHub DO | Absorbed into BrainDO |
| Duplicate substrate.ts files (one.ie + channels) | Single `BrainClient` in SDK (~25 lines) |
| D1 mirror on write hot path | D1 kept for audit log, not reads |

## What survives

| Kept | Why |
|---|---|
| TypeDB as durable truth | Source of record; BrainDO is a projection |
| api.one.ie gateway | Still the only door to TypeDB; now also hosts BrainDO |
| KV snapshots (5 keys) | Cold-start recovery: reload from KV faster than TypeDB |
| sync worker Jobs 2–5 | Sui absorb, D1 sync, reconcile, role sweep — unrelated to graph hot path |
| D1 for audit trail | Append-only mark/warn history |

---

## Migration path overview

Six cycles, each independently deployable. DO stub falls back to old path on 5xx during cutover.

| Cycle | What | Batch |
|---|---|---|
| C1 | BrainDO class + namespace + graph load | 1 |
| C2 | BrainClient in SDK, replace substrate.ts hot path | 2 |
| C3 | Absorb WsHub into BrainDO | 2 |
| C4 | Replace pollOutcome with WebSocket push | 3 |
| C5 | Remove sync Job 1, KV → backup role | 4 |
| C6 | Security: TQL audit, AbortSignal, circuit breaker, split keys | 2 (parallel with C2/C3) |

See `typedb-cloudflare-todo.md` for the full execution plan.
