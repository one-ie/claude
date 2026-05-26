# Signals

A signal is a message looking for someone who can handle it.

It doesn't know who that is. The world figures it out.

---

## The Idea

Think of the world as a city. Actors live in the city — humans, agents, bots, sensors. A signal is a letter dropped at the city gate. Sometimes you know exactly who to send it to. Sometimes you just know what kind of work you need done and trust the city to route it. Sometimes you want everyone on the street to hear it.

```
                        ┌─────────────────────────────────┐
                        │             WORLD                │
                        │                                  │
  signal arrives ──────►│   ┌──────┐       ┌──────┐       │
  { receiver,    │      │   │alice │──────►│ bob  │       │
    data }       │      │   └──────┘       └──────┘       │
                 │      │       ▲               │          │
                 └──────┤       │           ┌──────┐       │
                        │   pheromone       │carol │       │
                        │   trails          └──────┘       │
                        │                      ▲           │
                        │              sub: news:crypto    │
                        │           (carol subscribed)     │
                        └─────────────────────────────────┘
```

The world holds all the actors and remembers every path between them. When signals flow and things go well, those paths get stronger. When things fail, they get weaker. Actors can also raise their hand and say "send me everything tagged X" — that's a subscription, and it's just another path.

---

## Two Fields. That's It.

```typescript
{ receiver, data }
```

`receiver` — who (or what kind of actor) should get this.
`data` — what it carries: `{ tags?, weight?, content? }`

Everything else in this document is just about what strings are valid in `receiver`.

---

## Five Ways to Address a Signal

```
┌──────────────────────┬──────────────────────────┬──────────────────────────────────┐
│ Mode                 │ Example                  │ In plain English                 │
├──────────────────────┼──────────────────────────┼──────────────────────────────────┤
│ Direct               │ alice                    │ "Give this to Alice"             │
│ Direct + skill       │ alice:review             │ "Ask Alice to review this"       │
│ World + skill        │ world:review             │ "Find the best reviewer"         │
│ World + tags         │ world:review+urgent      │ "Find an urgent reviewer"        │
│ All                  │ all:review               │ "Every reviewer should see this" │
│ Subscribe            │ sub:news:crypto          │ "Everyone on the crypto list"    │
│ Bare world           │ world                    │ "Send this wherever it fits"     │
└──────────────────────┴──────────────────────────┴──────────────────────────────────┘
```

**Direct** — you know the actor. A contract. A pipeline. A relationship.

**`world:skill`** — you know the work. The world finds the best actor by following trails.

**`all:skill`** — you want every capable actor. Each one gets their own copy.

**`sub:topic`** — you're publishing to a topic. Every actor who opted in receives it.

**Bare `world`** — last resort. The world follows the strongest outgoing trail from the sender.

---

## How It Flows

### Direct — you know exactly who

```
emit({ receiver: "alice:review", data: pr })

        YOU
         │
         │  signal
         ▼
       ALICE  ◄─── delivered directly, no routing needed
         │
         │  mark() on success
         ▼
      PATH YOU→ALICE gets stronger
```

Simple. Fast. No world involved. The pheromone still marks the path so the world
learns that you and Alice work well together.

---

### World — the world finds the best actor

```
emit({ receiver: "world:review", data: pr })

        YOU
         │
         │  "I need a reviewer"
         ▼
       WORLD
         │
         │  who has the review skill?
         │  follow the strongest trail
         ▼
    ┌────────────────────────────┐
    │  alice  strength: 47  ◄───┼──── chosen (strongest)
    │  bob    strength: 12       │
    │  carol  strength:  3       │
    └────────────────────────────┘
         │
         ▼
       ALICE  ◄─── delivered, one actor wins
         │
         │  mark() on success
         ▼
      ALICE'S TRAIL gets even stronger
```

Nobody decided Alice was the best reviewer. The trails did — because she succeeded
the most times before. One signal, one delivery, pheromone picks.

---

### All — every capable actor gets a copy

Sometimes you don't want the best actor — you want all of them. A PR that every
reviewer should see. An alert that every monitor should receive. A question you
want multiple opinions on.

```
emit({ receiver: "all:review", data: pr })

        YOU
         │
         │  "every reviewer should see this"
         ▼
       WORLD
    ╱    │    ╲
   ▼     ▼     ▼
 ALICE  BOB  CAROL  ◄─── every actor with "review" gets a copy
   │     │     │
 mark() mark() warn()   ◄─── each path marked independently
                              (carol failed → her trail weakens)
```

Each delivery is independent. Each path marks or warns on its own outcome.
The world learns which actors actually do the work — the ones who succeed
accumulate strength, the ones who ghost accumulate resistance and fade.

`all:` is fan-out. `world:` is selection. Don't confuse them.

---

### Subscribe — actors who opted in

An actor can raise their hand: "whenever a signal tagged `news:crypto` arrives, I
want it." That's a subscription. It's a standing declaration that creates a path
from the topic to the actor.

```
  SUBSCRIBING
  ───────────

  carol.subscribe("news:crypto")

    CAROL
      │
      │  "put me on the crypto list"
      ▼
    WORLD creates:  news:crypto ──────► CAROL
                    (a path, seed strength: 1.0, scope: public)
```

Now when a signal arrives for `sub:news:crypto`:

```
  DELIVERING TO SUBSCRIBERS
  ─────────────────────────

  emit({ receiver: "sub:news:crypto", data: article })

          YOU
           │
           ▼
         WORLD  checks who subscribed to "news:crypto"
           │
      ┌────┴──────┐
      ▼           ▼
    CAROL       DAVE     ◄─── all subscribers receive a copy
   strength:   strength:
     12.3        4.1
      │           │
    mark()      mark()   ◄─── each subscription path strengthens
```

Subscriptions and `all:` are both fan-out. The difference:
- `all:tag` — anyone capable, whether they opted in or not
- `sub:topic` — only actors who explicitly raised their hand

---

### Cold miss — nobody has the skill yet

```
emit({ receiver: "world:review", data: pr })

        YOU
         │
         ▼
       WORLD  ──► nobody has "review" skill yet
         │
         │  enqueue the signal (don't drop it)
         ▼
      CLASSIFY  ◄─── one LLM call, off the hot path
         │
         │  "alice looks like she could handle review"
         │  seed weak pheromone (~0.3) on YOU→ALICE
         ▼
       DRAIN  ──► signal fires again ──► ALICE delivered
         │
         │  mark() on success
         ▼
      TRAIL SEEDED  ◄─── next time: no LLM, routes for free
```

The LLM runs **once**, off the hot path. It plants a weak seed. Real outcomes
make it strong — or warn it away. The pheromone field is the cache.

---

## Subscriptions Are Just Tags + Pheromone

A subscription is stored as a tag `"sub:news:crypto"` on the actor entity in TypeDB,
and as an in-memory tag on the unit. When a `sub:news:crypto` signal arrives,
the world scans all units for that tag and delivers a copy to each.

Pheromone marks every delivery. The path from topic to actor strengthens on
engagement and fades via L3 if ignored. Natural cleanup — no unsubscribe needed.

```
  SUBSCRIBE           ENGAGE              IGNORE (it fades)
  ─────────           ──────              ─────────────────

  carol               carol              sub:news:crypto ·····► carol
  opts in             opens every         (pheromone decays,
                      article             path dims via L3)
  tag seeded          strength: 47.2      if never engaged: gone

  "put me on         "carol is a          natural cleanup —
   the list"          highway for          no unsubscribe needed
                      crypto news"
```

- **Subscribe** = `world.subscribeTopic("carol", "news:crypto")` — writes `sub:news:crypto` tag to TypeDB + in-memory; persists across restarts
- **Engage** = every delivered signal marks `from→carol`, pheromone accumulates
- **Ignore** = L3 fade erodes the path every 5 minutes
- **Unsubscribe** = not needed — the path fades and the tag becomes unreachable

Restored on boot: `load()` reads all actor tags from TypeDB and rehydrates in-memory subscriptions. No lost state on restart.

---

## How Trails Form Over Time

Every signal that lands and succeeds marks the path. Every failure warns it.
Every path that isn't used fades. What survives is what worked.

```
  DAY 1                DAY 7                DAY 30
  ─────                ─────                ──────

  YOU──?──ALICE        YOU══════ALICE        YOU══════════ALICE
  YOU──?──BOB          YOU──────BOB          (bob faded away)
  YOU──?──CAROL        YOU──────CAROL        (carol faded away)

  all trails weak      alice pulling ahead   alice is the highway
  world classifies     world follows trails  world routes instantly
  every time           most of the time      no LLM ever needed
```

Ant colonies work exactly like this. No queen decides which trails to use. The trails decide — because successful ants reinforce them and failed trails evaporate.

The system doesn't get smarter by learning rules. It gets smarter by **remembering what worked**.

---

## The Grammar (for builders)

```
receiver   := actor | world-addr | all-addr | sub-addr
actor      := <aid> [":" <skill>]
world-addr := "world" [":" <tag-expr>]   -- pheromone picks ONE
all-addr   := "all"   ":" <tag-expr>     -- fan-out to ALL capable actors
sub-addr   := "sub"   ":" <tag-expr>     -- fan-out to ALL subscribers
tag-expr   := <tag> ("+" <tag>)*
```

```typescript
{ receiver: "alice" }                      // direct, default skill
{ receiver: "alice:review" }               // direct, named skill
{ receiver: "world:review" }               // world finds the best reviewer
{ receiver: "world:review+security" }      // world finds security reviewer
{ receiver: "all:review" }                 // every reviewer gets a copy
{ receiver: "sub:news:crypto" }            // every crypto subscriber gets it
{ receiver: "world" }                      // bare — strongest trail from sender
```

---

## Tag Intersection — narrowing the field

```
world:review+security

        WORLD
          │
          │  who has BOTH "review" AND "security" tags?
          ▼
    ┌──────────────────────────────┐
    │  alice   review ✓  security ✓│ ◄── candidate
    │  bob     review ✓  security ✗│    (too broad)
    │  carol   review ✗  security ✓│    (wrong skill)
    └──────────────────────────────┘
          │
          ▼  pheromone-weighted select()
        ALICE
```

If nobody matches all tags, the world loosens — drops the most specific tag and tries again. It fails open, not closed.

Works the same for `all:review+security` — delivers to every actor matching both tags.

---

## The Relationship Lifecycle

A signal relationship grows in three stages:

```
  DISCOVERY          PROVEN              COMMITTED
  ─────────          ──────              ─────────

  world:review  ──►  world:review   ──►  alice:review
                     (always alice)

  LLM classifies     pheromone routes    producer hardcodes
  seeds the trail    for free            SOP / contract
```

Start with `world:`. Let the pheromone find the right actor. Once the
relationship is stable and formal — a contract, a compliance requirement,
a signed channel — switch to direct. The world gets out of the way.

---

## The Sandwich

No LLM ever sits on the hot path.

```
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │  PRE   direct receiver?       ──► deliver  (no LLM)     │
  │  PRE   world:tag, match?      ──► select   (no LLM)     │
  │  PRE   all:tag                ──► fan-out  (no LLM)     │
  │  PRE   sub:topic              ──► subscribers (no LLM)  │
  │  PRE   world:tag, no match    ──► enqueue  (no LLM)     │
  │                                       │                  │
  │  LLM   classify off-path      ◄───────┘                 │
  │                                       │                  │
  │  POST  seed ──► drain ──► deliver ──► mark()            │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

The LLM is the gardener. It seeds trails. Real outcomes grow or kill them.
It never `warn()`s — resistance is earned by failure, not predicted by a model.

---

## When to Use What

| You want to…                              | Use                     |
|-------------------------------------------|-------------------------|
| Talk to a specific actor                  | `alice`                 |
| Ask an actor to do a specific task        | `alice:review`          |
| Find the best actor for a job             | `world:review`          |
| Narrow to a specialist                    | `world:review+security` |
| Every capable actor should see this       | `all:review`            |
| Everyone who subscribed should get this   | `sub:news:crypto`       |
| Send anywhere (last resort)               | `world`                 |

**Default:** use `world:something`. Let the world find the actor. Switch to direct once the relationship is proven. Use `all:` and `sub:` when delivery to multiple actors is the intent — not a fallback.

---

## What Never Changes

- `signal()` shape — always `{ receiver, data }`
- `ask()` — always `{ result | timeout | dissolved }`
- `mark()` / `warn()` — always earned by outcomes, never predicted
- `select()` — always pheromone-weighted (used by `world:`)
- `fade()` — always asymmetric (resistance forgives 2× faster than strength decays)
- Subscriptions — always tags + pheromone. Stored in TypeDB, restored on boot.
- Direct addressing — always the escape hatch, always the SOP path

---

## Implementation

```typescript
// world.ts — signal()
signal({ receiver, data }: Signal, from = 'entry') {
  const d = asData(data)

  // sub: fan-out — units with tag "sub:news:crypto" receive a copy
  if (receiver.startsWith('sub:')) {
    for (const [uid, u] of Object.entries(units)) {
      if (u.subscribedTags().includes(receiver)) {
        d.marks !== false && mark(`${from}→${uid}`, d.weight ?? 1)
        u({ receiver: uid, data }, from)
      }
    }
    return
  }

  // all: fan-out — units with ALL matching capability tags receive a copy
  if (receiver.startsWith('all:')) {
    const tags = receiver.slice(4).split('+')
    for (const [uid, u] of Object.entries(units)) {
      if (tags.every(t => u.subscribedTags().includes(t))) {
        d.marks !== false && mark(`${from}→${uid}`, d.weight ?? 1)
        u({ receiver: uid, data }, from)
      }
    }
    return
  }

  // direct — deliver and mark
  const unitId = receiver.includes(':') ? receiver.split(':')[0] : receiver
  const target = units[unitId]
  if (!target) return
  d.marks !== false && mark(`${from}→${receiver}`, d.weight ?? 1)
  target({ receiver, data }, from)
}

// persist.ts — subscribeTopic()
subscribeTopic(unitId: string, topic: string) {
  const tag = `sub:${topic}`
  writeSilent(`
    match $u isa actor, has aid "${unitId}";
    not { $u has tag "${tag}"; };
    insert $u has tag "${tag}";
  `)
  net.get(unitId)?.subscribe([tag])  // in-memory: immediate effect
}

// persist.ts — load() restores subscriptions on boot
const tagAnswers = await read(`
  match $u isa actor, has aid $id, has tag $tag; select $id, $tag;
`)
for (const { id, tag } of tagAnswers) {
  net.get(id)?.subscribe([tag])  // restores both capability and sub: tags
}
```

`all:` reads in-memory capability tags. `sub:` reads in-memory topic tags (prefixed `sub:`).
Both mark each delivery independently. Both survive restarts via TypeDB + `load()`.

---

## See Also

- [dictionary.md](dictionary.md) — every concept named
- [routing.md](routing.md) — how `select()` weighs strength and resistance
- [metaphors.md](metaphors.md) — signals in ant, brain, team, mail, water skins
- [system-ontology.md](system-ontology.md) — complete system map

---

*The world remembers. The trails decide. Subscribers raised their hand. You just send the signal.*
