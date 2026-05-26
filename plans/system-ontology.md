# System Ontology

Complete map of ONE — every named concept, its layer, and how it connects.
Source of truth: `one-ontology.md` (dimensions) + `dictionary.md` (names) + `agents.md` (authority).

---

## The 6 Dimensions (locked forever)

The irreducible ontology. Remove any one and the system breaks.

| # | Dimension | What it models | Biology analogue |
|---|-----------|----------------|-----------------|
| 1 | **Groups** | Containers — scope, isolation, nesting | Colony structure |
| 2 | **Actors** | Who acts — humans, agents, animals, worlds | Individual ants |
| 3 | **Things** | What exists — skills, tasks, tokens, services | Environment |
| 4 | **Paths** | Weighted connections — learned routes | Pheromone trails |
| 5 | **Events** | What happened — signals, payments | Foraging activity |
| 6 | **Learning** | What was discovered — hypotheses, frontiers | Colony memory |

```
GROUP
 ├── actors/     humans · agents · animals · worlds
 ├── things/     skills · tasks · services · tokens
 ├── paths/      strength + resistance (unit→unit and task→task)
 ├── events/     signals that happened
 └── learning/   hypotheses · frontiers · objectives
```

---

## TypeDB Schema — 3 entities, 5 relations, 22 attributes

```tql
define

# 1. GROUPS
entity group,
    owns gid @key, owns name, owns group-type;

# 2. ACTORS
entity actor,
    owns aid @key, owns name, owns actor-type,
    owns model, owns prompt, owns generation,
    owns wallet, owns auth-hash, owns tag @card(0..);

# 3. THINGS
entity thing,
    owns tid @key, owns name, owns thing-type,
    owns task-status, owns task-wave, owns task-priority,
    owns price, owns tag @card(0..),
    owns rubric-security, owns rubric-stability,
    owns rubric-simplicity, owns rubric-speed,
    owns rubric-fit, owns rubric-form,
    owns rubric-truth, owns rubric-taste,
    owns rubric-composite;

# 4. PATHS
relation path, relates source, relates target,
    owns strength, owns resistance, owns traversals, owns revenue;
relation capability, relates provider, relates offered, owns price;
relation membership, relates group, relates member, owns role;
relation containment, relates container, relates contained;
relation blocks, relates blocker, relates blocked;

# 5. EVENTS
relation signal, relates sender, relates receiver,
    owns data, owns amount, owns success, owns latency, owns ts;
# data convention: { tags?: string[], weight?: number, content?: unknown }

# 6. LEARNING
entity hypothesis,
    owns hid @key, owns statement, owns confidence,
    owns observations, owns status, owns scope;
```

---

## Dimension 1 — Groups

**Group types:**

| Type | What | Example |
|------|------|---------|
| `world` | Top-level container | ONE, Donal's agency |
| `personal` | Private group for one human | owner's personal group |
| `friends` | Personal social group | inner circle |
| `team` | Working group | marketing, engineering |
| `community` | Open shared-interest group | ONE builders |
| `org` | Autonomous organisation | OO Agency |
| `dao` | Token-holder governance | token-holders |

Groups nest: `platform → org → team → personal`. Agent visibility is bounded by group membership. No middleware — isolation is structural.

**Membership roles (permission = role × pheromone):**

| Role | Can | Cannot |
|------|-----|--------|
| `chairman` | everything | — |
| `board` | read highways, revenue, toxic | write anything |
| `ceo` | hire/fire, tune sensitivity | appoint roles |
| `operator` | add units, mark/warn | remove units, tune |
| `agent` | mark/warn own paths only | add/remove, read revenue |
| `auditor` | read highways, revenue, toxic | write anything |

---

## Dimension 2 — Actors

**Actor types:**

| Type | What | Gate | Example |
|------|------|------|---------|
| `human` | A person | Touch ID (Secure Enclave passkey) | Tony, Donal |
| `agent` | An AI agent | Move consensus (ScopedWallet) | scout, analyst |
| `animal` | Non-human biological / IoT | signal only | sensor device |
| `world` | Another ONE world (federation) | federated signal | marketing-world |

**Actor classification (auto, by pheromone):**

| Class | Condition |
|-------|-----------|
| `proven` | success-rate ≥ 0.75, activity ≥ 70, samples ≥ 50 |
| `at-risk` | success-rate < 0.40, activity ≥ 25, samples ≥ 30 |
| `active` | everything else (default) |

**Actor identity — four layers:**

```
layer 1: id           immutable primary key (system-assigned)
layer 2: name         canonical name (owner sets, everyone sees)
layer 3: alias[skin]  per-metaphor variant (owner sets)
layer 4: nickname     personal (viewer sets in KV)
```

Resolution: `nickname ?? alias[skin] ?? name ?? id`

---

## Dimension 3 — Things

`thing-type` selects what kind. One entity, not four.

| `thing-type` | What | Notes |
|-------------|------|-------|
| `plan` | 5-cycle work program | has `goal`, `cycles-planned`, `escape-condition` |
| `cycle` | One W0→W4 sandwich | `containment` links plan→cycle |
| `task` | Atomic work unit | 7-state machine |
| `skill` | Verified capability | promoted from `task` when `verified` + rubric ≥ 0.65 |
| `service` | Priced skill | `price > 0` = service automatically |
| `token` | On-chain asset mirror | SUI, USDC, etc. |

**Task 7-state machine:**

| Status | Meaning | Pheromone |
|--------|---------|-----------|
| `open` | Ready to pick | — |
| `blocked` | Waiting on another task's `verified` | — |
| `picked` | Agent has claimed it | — |
| `done` | Result returned, awaiting W4 verify | mark(+depth) |
| `verified` | Rubric ≥ 0.65; skill may be promoted | mark(score×5) |
| `failed` | No result, not timeout | warn(1) |
| `dissolved` | Missing unit or capability | warn(0.5) |

**Task-wave → model routing:**

| Wave | Model | Role letter |
|------|-------|------------|
| W1 recon | Haiku | `r` |
| W2 decide | Opus | `d` |
| W3 edit | Sonnet | `e` |
| W4 verify | Sonnet | `v` |

**Task ID format:** `{plan-slug}:{cycle}:{role}{index}` — e.g. `loop-close:1:r1`

**Task pheromone classification:**

| Class | Condition |
|-------|-----------|
| `attractive` | strength ≥ 50, no blockers |
| `repelled` | resistance > strength |
| `exploratory` | strength = 0, resistance = 0 |
| `ready` | everything else |

---

## Dimension 4 — Paths

Two weighted connection types. Both carry `strength` and `resistance`.

**Path** (unit → unit):

| Status | Condition |
|--------|-----------|
| `highway` | strength ≥ 50 |
| `fresh` | strength 10–50, traversals < 10 |
| `active` | default |
| `fading` | strength 0–5 |
| `toxic` | resistance > strength AND resistance ≥ 10 |

**Trail** (task → task):

| Status | Condition |
|--------|-----------|
| `proven` | pheromone ≥ 70, completions ≥ 10, failures < completions |
| `fresh` | pheromone 10–70, completions < 10 |
| `active` | default |
| `fading` | pheromone 0–10 |
| `dead` | pheromone ≤ 0 |

Resistance fades **2× faster** than strength — the system forgives failures sooner than it forgets successes.

Paths also carry `revenue` — every payment strengthens the path. Money is pheromone. Paying routes become highways.

**Path scope (federation boundary):**

| Scope | Visible to | Harden to Sui? |
|-------|------------|----------------|
| `private` | sender + receiver only | No |
| `group` | All group members | No |
| `public` | Anyone cross-org | Yes |

---

## Dimension 5 — Events (Signals)

Every signal leaves a record:

| Field | Type | Meaning |
|-------|------|---------|
| `sender` | actor ref | Who sent it |
| `receiver` | actor ref | Who got it |
| `data` | JSON | `{ tags?, weight?, content? }` |
| `amount` | number | Payment attached (0 = free) |
| `success` | boolean | Did it work? |
| `latency` | ms | How long it took |
| `ts` | timestamp | When it happened |

**Data convention — three slots:**

| Slot | Type | Meaning |
|------|------|---------|
| `tags` | `string[]` | Routing + classification key |
| `weight` | number | Pheromone deposit. Positive = mark(). Negative = warn(). Also the payment amount. |
| `content` | any | Actual payload — rubric scores, task body, API response |

---

## Dimension 6 — Learning

Three entities that emerge from accumulated signals:

**Hypothesis** — a belief being tested:
```
status: pending → testing → confirmed | rejected
action-ready: true when p-value ≤ 0.05, observations ≥ 50
```

**Frontier** — something the system doesn't know yet:
```
status: unexplored → exploring → exhausted
expected-value: potential × probability / cost
```

**Objective** — a goal the system set for itself:
```
status: pending → active → complete
progress: 0.0 to 1.0
```

---

## The Signal — the primitive

```
{ receiver, data }
```

Two fields. That's everything that flows. The runtime moves signals. TypeDB remembers.

**Five receiver modes:**

| Mode | Example | Meaning |
|------|---------|---------|
| Direct | `alice` | Deliver to a specific actor |
| Direct + skill | `alice:review` | Specific actor, named skill |
| World | `world:review` | Pheromone picks the best actor |
| All | `all:review` | Fan-out — every capable actor gets a copy |
| Subscribe | `sub:news:crypto` | Fan-out — every opted-in actor gets a copy |
| Bare world | `world` | Follow the strongest outgoing path |

**Grammar:**

```
receiver   := actor | world-addr | all-addr | sub-addr
actor      := <aid> [":" <skill>]
world-addr := "world" [":" <tag-expr>]   -- pheromone picks ONE
all-addr   := "all"   ":" <tag-expr>     -- fan-out to ALL capable actors
sub-addr   := "sub"   ":" <tag-expr>     -- fan-out to ALL subscribers
tag-expr   := <tag> ("+" <tag>)*
```

**Subscription = a path** — `carol.subscribe("news:crypto")` seeds a TypeDB path from topic `news:crypto → carol` with `strength: 1.0`. Same pheromone mechanics as all other paths: strengthens on engagement, fades via L3 if ignored, dissolves naturally. No unsubscribe needed.

`all:` reads capability (anyone with the skill). `sub:` reads subscription paths (actors who opted in). Both fan-out and mark each delivery independently.

---

## The 6 Verbs

```
send    ── signal moves ──────────────► next receiver
mark    ── path gets stronger
warn    ── path gets weaker
fade    ── everything slowly decays
follow  ── go where the trail is strongest
harden  ── proven path becomes permanent (TypeDB hypothesis or Sui Highway)
```

Resistance fades 2× faster than strength. Harden runs hourly (L6).

**Per-metaphor names for `harden`:** imprint (ant) · myelinate (brain) · codify (team) · seal (mail) · bedrock (water) · license (radio) · freeze_object (Sui)

---

## The 4 Outcomes

Every `ask()` resolves to exactly one:

```
result     → mark(edge, chainDepth)    success — path strengthens
timeout    → neutral                   not the agent's fault
dissolved  → warn(edge, 0.5)           mild — path doesn't exist
failure    → warn(edge, 1)             full warn — agent produced nothing
```

---

## The 5 Slash Commands

| Verb | Primitive | What |
|------|-----------|------|
| `/see` | `follow()` | Read world state — tasks, highways, paths, frontiers, hypotheses, events |
| `/create` | `send()` | Emit new entity into substrate |
| `/do` | `select()` + tick | Drive work through deterministic W1→W4 sandwich |
| `/close` | `mark()` / `warn()` | Close a signal loop |
| `/sync` | `tick()` + `know()` | Full substrate tick + markdown absorption |

---

## The 7 Loops

```
L1  SIGNAL       per message     signal → ask → outcome
L2  TRAIL        per outcome     mark/warn → strength/resistance accumulates
L3  FADE         every 5 min     asymmetric decay (resistance forgives 2× faster)
L4  ECONOMIC     per payment     revenue on paths (capability price)
L5  EVOLUTION    20+ samples     agent rewrites its own prompt when success-rate < 50%
L6  KNOWLEDGE    50+ obs         harden highways into hypotheses
L7  FRONTIER     weekly          detect unexplored tag clusters
```

Each loop feeds the next. Signals build trails. Trails survive fade. Survivors attract payments. Payments fund agents. Agents evolve. Evolution produces learning. Learning reveals frontiers.

---

## The 3 Locked Rules

### Rule 1 — Closed Loop
Every signal closes with `mark()` on result, `warn()` on failure, or `dissolve` on missing unit/capability. No silent returns. No orphan signals.

### Rule 2 — Structural Time Only
Plan in **tasks → waves → cycles**. Never days, hours, weeks, or sprints. Calendar time can't be `mark()`d.

### Rule 3 — Deterministic Results
Every loop reports verified numbers: tests passed/total, build ms, deploy ms, rubric scores. Path strength without verification is superstition.

---

## The 2 Rubrics

### Agent rubric (trade VERIFY)

| Dimension | What |
|-----------|------|
| `fit` | Response fits the task spec |
| `form` | Response is well-formed |
| `truth` | Response is accurate |
| `taste` | Response is high-quality prose |

### Code rubric (/do W4)

| Dimension | Weight | What |
|-----------|--------|------|
| `security` | 0.35 | Zero vulnerabilities, boundaries validated |
| `stability` | 0.30 | Tests pass, no type errors, loops closed |
| `simplicity` | 0.25 | Minimum code, every line earns its place |
| `speed` | 0.10 | 100% Lighthouse, lean tokens, fast build |

Gate: `rubric-composite ≥ 0.65`. Formula: `0.35·sec + 0.30·sta + 0.25·sim + 0.10·spd`

---

## The 4 Agent Authority Patterns

| Pattern | Move | Shape | Best for |
|---------|------|-------|---------|
| **A — Co-sign** | none | `2-of-2 multisig { user_passkey, agent_key }` | High-value, irregular actions |
| **B — Scoped autonomy** | `ScopedWallet<T>` | Daily cap + allowlist + pause + revoke | Repetitive day-to-day ops |
| **C — Delegated capability** | `Capability` object | Bounded scope + expiry, single purpose | One-shot complex workflows |
| **D — Peer agents** | `spawn_child<T>` | Agent owns agent (or human economic scope) | Machine-speed fleets |

**Safety floor (invariant):** An agent cannot produce a human's passkey signature. The Secure Enclave + finger is non-transferable by physics, not policy. Agents can own a human's *economic scope* — never the human's *identity*.

---

## Identity Architecture

**Human wallet — 5 states:**

```
State 1  Ephemeral  — crypto.getRandomValues(32), IndexedDB plaintext
State 2  Saved      — PRF-wrapped seed, passkey largeBlob + 12 BIP39 words
State 3  Linked     — Google OAuth joins human identity to wallet
State 4  Multi-device — iCloud/Google Keychain sync (passkey carries largeBlob)
State 5  Recovered  — BIP39 paper break-glass regenerates key
```

**Agent key storage (prod → dev):**
1. Owner-PRF-wrapped ciphertext in D1 (recommended)
2. Session SE identity — `age-plugin-se` with `biometry-any`
3. `~/.vault.age` `[agents/<name>]` — local dev
4. Cloudflare Worker secret — always-on server-side agents

**The biometric chain:**

```
Mac personal    Secure Enclave + age-plugin-se   Touch ID   mac.md
Dev secrets     Secure Enclave (same identity)   Touch ID   secrets.md
Owner apex      WebAuthn passkey PRF             Touch ID   owner.md
Wallet seed     WebAuthn passkey PRF             Touch ID   passkeys.md
Agent authority  ScopedWallet Move module         consensus  agents.md
```

---

## Lifecycle Stage Tags (the 0→sell→buy funnel)

Tags on signals — not schema entities. Each stage writes to its natural dimension.

| Tag | Stage | Writes to |
|-----|-------|-----------|
| `stage:wallet` | 0 — identity | `actor.wallet` |
| `stage:key` | 1 — save key | `actor.auth-hash` or device credential |
| `stage:signin` | 2 — sign in | `signal` receiver=`auth:signin` |
| `stage:personal` | 3 — personal group | `group(type:personal)` + `membership(role:chairman)` |
| `stage:team` | 4 — create team | `group` + `actor` inserts |
| `stage:deploy` | 5 — deploy | `capability` relation |
| `stage:discover` | 6 — discover | `signal` receiver=`discover:<tag>` |
| `stage:message` | 7 — first signal | `signal` with `data` |
| `stage:converse` | 8 — converse | N signals → `path.strength` accumulates |
| `stage:sell` | 9 — sell | `signal` + `amount > 0` + `mark` |
| `stage:buy` | 10 — buy | mirror of 9, other direction |
| `stage:advocate` | 11 — advocate | `hypothesis(source:observed)` |
| `stage:subscribe` | 12 — subscribe | reverse edge `tag → agent` with scope |
| `stage:invite` | 13 — invite | referral signal + new `actor` + initial paths |

---

## Trade Lifecycle (10 stages)

```
IDLE → BROWSING → SELECTED → NEGOTIATING → ESCROWED →
LOCKED → CLAIMED → VERIFIED → SETTLED → COMPLETE
(+ FAILED + RESET as escape routes)
```

Each transition emits `ui:marketplace:transition:<stage>` via `emitClick`.
Invalid transitions throw at call-site via `useTradeLifecycle` reducer.

---

## The Tech Stack

| Layer | Technology | Role |
|-------|-----------|------|
| UI pages | Astro 6 + Cloudflare Workers Static Assets | SSR islands |
| UI components | React 19 (Actions, `use()`, transitions) | Interactive islands |
| Styling | Tailwind 4 + shadcn/ui + 6-token design system | Dark-first, WCAG AA |
| AI streaming | AI SDK v6 (`ai@^6`, `@ai-sdk/react`) | `ToolLoopAgent`, `useChat` |
| LLM routing | OpenRouter (default) · Groq (opt-in) | Via AI SDK Gateway |
| Database | TypeDB 3.0 | Brain: paths, classification, learning |
| Worker runtime | Cloudflare Workers | Hono, D1 (signals/messages), KV (snapshots) |
| On-chain | Sui + Move | Wallets, ScopedWallet, PTBs, escrow |
| Gateway | api.one.ie | TypeDB proxy + WsHub DO; <10ms |

---

## The 4 Surfaces

| Surface | URL | Audience | Speed claim |
|---------|-----|----------|------------|
| **one.ie** | https://one.ie | Humans + agents | 5s wallet, 50ms agent wallet, 3s buy, 30s list |
| **pay.one.ie** | https://pay.one.ie | Developers + businesses | Accept crypto in 60s |
| **api.one.ie** | https://api.one.ie | All surfaces | TypeDB proxy + WsHub; <10ms gateway |
| **github.com/one-ie/one** | https://github.com/one-ie/one | Developers | `npx oneie` → SDK + MCP + CLI |

---

## Repo Geography

| Path | What | Role |
|------|------|------|
| `one/` | Canonical docs — ontology, dictionary, patterns, rubrics | Source of truth for names |
| `web/` | Astro 6 + React 19 substrate app | Chat, passkeys, skills, payments |
| `claw/` | Edge-native agent worker — Telegram/Discord/HTTP | Ingress + LLM + memory |
| `sdk/` | `@oneie/sdk` — TypeScript SDK | External TS surface |
| `mcp/` | `@oneie/mcp` — MCP server | Claude/Cursor tool surface |
| `cli/` | `@oneie/cli` — 15 verbs | `npx oneie` |
| `agents/` | Markdown agent definitions | Templates consumed by claw + mcp |
| `.claude/` | Claude Code harness — commands, skills, rules | W1-W4 wave agents |

---

## TypeDB Functions (routing + classification)

**Routing:**

| Function | Returns |
|----------|---------|
| `suggest_route(from, task)` | Top 5 units by path strength |
| `optimal_route(from, task)` | Single best unit |
| `cheapest_provider(task)` | Lowest price with capability |
| `highways(threshold, min)` | All strong paths |

**Classification:**

| Function | Returns |
|----------|---------|
| `path_status(path)` | `highway · fresh · active · fading · toxic` |
| `trail_status(trail)` | `proven · fresh · active · fading · dead` |
| `actor_classification(actor)` | `proven · active · at-risk` |
| `is_attractive(task)` | Strong trail + no blockers |
| `needs_evolution(actor)` | Success < 50%, samples ≥ 20 |
| `is_action_ready(hypothesis)` | Confirmed + p-value ≤ 0.05 + obs ≥ 50 |

---

## The /do Wave Cycle

```
W1 recon   (Haiku)  → reads files, reports findings verbatim
W2 decide  (Opus)   → tradeoffs, file list, rubric targets
W3 edit    (Sonnet) → precise edits per W2 spec, docs + code parallel
W4 verify  (Sonnet) → biome + tsc + vitest, rubric ≥ 0.65
```

Gate: `rubric-composite ≥ 0.65` → ship. Below threshold → W3 again.

---

## Two Layers of Learning

```
WORLD LEARNING                        AGENT LEARNING
─────────────────────────────         ─────────────────────────────
mark() → path strengthens             success-rate < 50%, samples ≥ 20
warn() → path weakens                   → needs_evolution() fires
fade() → stale paths dissolve           → agent reads its failures
                                        → rewrites system-prompt
The world gets smarter.                 → generation++
Agents can stay identical.
                                      The agent gets smarter.
```

---

## Dead Names (never use — causes schema drift)

| Dead name | Use instead | Retired |
|-----------|-------------|---------|
| `task-id` (old key) | `tid` | v2.0 2026-04-20 |
| `task-name` | `name` | v2.0 |
| `task-type` | `thing-type` | v2.0 |
| `status` (old task) | `task-status` | v2.0 |
| `phase` | `task-wave` | v2.0 |
| `priority-score` | `task-priority` | v2.0 |
| `"todo"` | `"open"` | v2.0 |
| `"in_progress"` | `"picked"` | v2.0 |
| `"complete"` | `"done"` / `"verified"` | v2.0 |
| `assignment` | `containment` + `task-status="picked"` | v2.0 |
| `dependency` | `blocks` | v2.0 |
| `knowledge` | `hypothesis` | pre-v1 |
| `connections` | `path` | pre-v1 |
| `node` | `unit` / `actor` | pre-v1 |
| `scent` | `strength` | pre-v1 |
| `alarm` | `resistance` | pre-v1 |
| `trail` | `path` | pre-v1 |
| `Colony` (Move) | `Group` | pending upgrade |

---

## See Also

| Doc | Owns |
|-----|------|
| `one-ontology.md` | 6 dimensions defined, TypeQL schema |
| `dictionary.md` | Complete naming guide — every primitive named |
| `patterns.md` | 6 ant lessons, pheromone loop, routing patterns |
| `rubrics.md` | Quality scoring — agent (fit/form/truth/taste) + code (sec/sta/sim/spd) |
| `lifecycle.md` | 14 stage tags, agent journey |
| `routing.md` | L1-L7 loops, signal flow, priority formula |
| `agents.md` | 4 authority patterns, safety floor, agent onboarding |
| `passkeys.md` | Wallet 5-state lifecycle, WebAuthn PRF, BIP39 break-glass |

*6 dimensions. 6 verbs. 7 loops. 4 patterns. 3 rules. One signal.*
