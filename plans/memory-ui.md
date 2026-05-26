how# Memory UI

How humans add, edit, and curate memory that agents will use.

The substrate already remembers what *happened* — every signal, every `mark`,
every `warn`. This document is about the smaller, sharper thing: the memory
a human deliberately writes down so that every future chat starts knowing it.

> **One sentence:** A client company adds three facts about itself; from that
> moment, every agent in the world greets, routes, prices, and refuses
> conversations differently — without anyone touching a prompt.

---

## The premise

> **The simplest version of this whole document:** a person (or an agent)
> types a fact about the company into a box. Every chat in that world
> uses it from the next turn. That's it.

Everything else in this doc — namespaces, scrape, role gates, agent
appetite — is just how that one promise stays true as the world grows.

---

## Memories are signals

Look at `schema/one.tql`. There is no `memory` relation. There is `signal`
and there is `hypothesis`. Memory is what happens when a signal addressed
to `memory:assert` lands a typed `hypothesis` in the brain.

```
   add memory      =      signal {
   (UI click)              sender:   <whoever wrote it>
   (agent emit)            receiver: "memory:assert"
   (scrape accept)         payload:  { namespace, statement, tags, scope }
                           ts:       now
                           scope:    "group" | "private" | "public"
                         }
                              │
                              ▼
                    unit('memory:assert').on('signal', insertHypothesis)
                              │
                              ▼
                    hypothesis {
                       hid, statement, confidence: 0.30,
                       observations: 1, scope, source: "asserted",
                       valid-from: now
                    }
```

That is the whole write path. One signal. One unit. One row in TypeDB.
Every UI affordance in this doc resolves to that same signal — just with
a different `sender` and `payload`.

Three consequences fall out of treating memory as a signal:

1. **Memory writes are auditable for free.** Every assertion is an event
   on the immutable tape, sender included. `reveal()` of a group already
   shows them; no new audit log to build.
2. **Memory writes route through paths.** A signal addressed to
   `memory:assert` `mark`s the path `<sender> → memory:assert`. Frequent
   curators (humans or agents) build pheromone toward the assert unit
   the same way any other path does.
3. **Memory writes can fail.** `memory:assert` is a unit with a `.on()`
   handler — it can validate, dedupe, reject. Schema violations close
   the loop with `warn()`, just like any other signal.

The UI does **not** add a new memory store. It is a single button that
fires a signal.

---

## No RAG. No vector store. No extraction pipeline.

The substrate is typed. We do not need RAG.

| Concern most "memory" products solve | Why it doesn't apply here |
|--------------------------------------|---------------------------|
| Chunk size, overlap, re-rank | There are no chunks. There are typed `hypothesis` rows. |
| Vector DB sync, hybrid stores | One store: TypeDB. One snapshot: KV. |
| Extraction pass on every message | The signal is already typed. Nothing to extract. |
| "Importance scoring" via LLM | `mark`/`warn` from outcomes. Math, not vibes. |
| Embedding drift on schema change | There's no embedding to drift. |
| Retrieval relevance tuning | The `ContextPack` reads by namespace + tag + confidence. No `top-k`. |

The Memory UI is the **direct expression of this elegance**: one input,
one signal, one row, one prompt injection. If at any point in this
design we find ourselves drawing the "vector store" box, we have failed
the substrate.

> Three things to ban from the UI on principle: a search box that says
> "semantic search", a sidebar called "Embeddings", any setting named
> "chunk size". The substrate has none of these. Neither does the UI.

---

## Who writes memory

Five emitters. Same signal. Different `sender`.

| Emitter | When | Sender | Default source / confidence |
|---------|------|--------|------------------------------|
| **Operator in Inbox** | Curating | human actor | `asserted` · 0.30 |
| **Operator clicks Verify** | Promotion | human actor (operator+) | `verified` · 0.85 |
| **End user in chat** | "remember that I prefer X" | end-user actor | `asserted` · 0.30 (private scope) |
| **Agent during turn** | "I learned something about this customer" | agent actor | `asserted` · 0.30, awaiting corroboration |
| **Scrape acceptance** | URL → staging → accept | operator (on behalf of scraper) | `verified` · 0.85 |
| **L6 / outcome handlers** | Highway promotion, valence detection | system (`uid: substrate`) | `observed` · 0.50–0.95 |

The key entry that older drafts of this doc missed: **agents emit memory
signals themselves**. A support agent that resolves a tricky case ends
its turn by sending `signal({ receiver: 'memory:assert', payload: {
namespace: 'customer', statement: 'alice prefers email follow-ups',
... } })`. The next turn that involves alice reads that hypothesis from
the pack. No human in the loop.

This is what makes the substrate **work** while the human sleeps — the
agents fill `customer.*` and `company.*` on their own, and humans
review and verify in batch through the Inbox. The UI is the curation
surface; the substrate is the production line.

> Confidence and source rules stay honest: a self-asserted agent fact
> caps at 0.30 until either an operator verifies it or L6 corroborates
> it. An agent cannot promote its own memory any more than a chat user
> can. The signal is open; the trust gate is not.

---

## Paste anything

The single most important affordance in this whole UI: **one drop zone
that accepts anything.** A client doesn't think in "facts" — they think
in documents, web pages, FAQs, spreadsheets. The substrate accepts all
four shapes and routes them through one pipeline.

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│   Drop a file, paste text, or share a URL.            │
│   Or type one sentence and press Enter.                │
│                                                        │
│   _________________________________________⏎          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

One control. Four input shapes. Detected by content:

| What lands in the input | Detected as | Pipeline | Result |
|---|---|---|---|
| `< 200 chars`, no URL, Enter | single sentence | `memory:classify` → `memory:assert` | 1 row at 0.30 |
| `≥ 200 chars` of free text | blob | `memory:extract` → stage → operator accepts | N rows at 0.85 |
| starts with `http(s)://` | URL | `memory:scrape` → `memory:extract` → stage | N rows at 0.85 |
| drag-drop of `.pdf .docx .md .txt .csv .json` | file | parse → `memory:extract` → stage | N rows at 0.85 |

Same destination for all four: typed hypothesis rows in the active
namespace. The user does not pick the path — the substrate picks.

### Why operator paste auto-verifies

The current design caps asserted memory at 0.30 to defend against
prompt injection. But an operator with `operator+` role **is the trust
gate**. When they click `[Accept all]` on a tray of staged rows, that
click is the signature — the rows promote to `verified · 0.85` in one
action, not 20.

```
operator action      what it signs                       rows promoted
─────────────────    ──────────────────────────────────  ────────────
[Accept all]         "these N rows are about my company"  N at 0.85
[Edit] + [Accept]    "this one row, with corrections"     1 at 0.85
[Skip]               "not interesting"                    0
[Reject]             "this is wrong / spam"               warn() on source path
```

Trust ceiling stays honest: rows never auto-promote past 0.85 without
either L6 corroboration or a third actor's signature. An *agent* paste
still caps at 0.30 (agents can't sign for the company). A *chat user*
paste caps at 0.30 (they're not in the trust chain).

### Time-to-value table

| User starts with | Steps | Wall clock | Verified rows |
|---|---|---|---|
| One fact they want to add | type + Enter + ⋯ → Verify | ~10s | 1 |
| Their About page in browser | copy + paste + Accept all | ~15s | 5–10 |
| Their website URL | paste URL + Accept all | ~30s | 10–25 |
| A brand PDF on disk | drop + Accept all | ~20s | 15–40 |
| Their full corpus (website + 3 PDFs) | URL + 3 file drops + Accept all | ~90s | 40–80 |

A new client should land their first 20 verified rows in **under two
minutes** with no training. That is the bar.

### Connectors: Drive, Notion, Slack — same pipeline, no RAG

A real client doesn't keep their knowledge in one PDF — they have a Notion
vault, a Google Drive folder, a Slack #knowledge channel, a CRM. The
Memory UI treats each as **another fetcher** feeding the same extractor.

```
┌─────────────┐    ┌─────────────┐    ┌──────────────┐
│ Google Drive│    │   Notion    │    │   Slack      │
│ (a folder)  │    │  (a vault)  │    │  (#wiki)     │
└──────┬──────┘    └──────┬──────┘    └──────┬───────┘
       │                  │                  │
       └────────┬─────────┴──────────────────┘
                ▼
   unit('memory:connector:*')   one fetch per doc / page / message
                │
                ▼
   unit('memory:extract')       LLM reads each, emits typed rows
                │
                ▼
   hypothesis rows, tagged src:<connector>:<id> for re-fetch & diff
                │
                ▼
   webhook on update → re-extract that one doc → diff → staging tray
```

The connector is OAuth + paginated fetch + change-subscription. Nothing
else. It does **not** embed, chunk, index, or rank. It hands plain text
to `memory:extract`, which is the same unit the file drop and URL paste
use. One pipeline, many sources.

#### What lands in TypeDB

A 500-page Notion vault produces (in our experience modelling this on
similar typed-extraction systems):

| Source pages | Raw words | Typed rows (`hypothesis`) | Vector chunks (if we used RAG) |
|--------------|-----------|----------------------------|--------------------------------|
| 500 | ~1.5M | ~3k–5k | ~30k–50k |
| Per page | ~3,000 | ~6–10 | ~60–100 |

Most pages collapse to a handful of durable claims; meeting notes,
drafts, and duplicates produce zero. The store stays small because
**noise doesn't crystallize.**

#### Re-extraction on update

Connectors subscribe to update events (Notion `block.updated`, Drive
`changes.watch`, Slack `message.changed`). On event:

```
1. Re-fetch the one updated doc (cheap)
2. Re-extract typed rows
3. Diff against existing rows tagged src:<connector>:<id>:
     • new rows           → staging tray
     • disappeared rows   → propose warn() (fade)
     • changed rows       → bi-temporal: valid-until=now on old, valid-from=now on new
4. Operator [Accept all] in batch
```

A Notion edit at 9:42am produces a staging-tray notification at 9:43am.
No re-indexing. No re-embedding. No "rebuild the vector store" cron.

#### The honest edge case

If a user genuinely needs "find the paragraph where we said X" recall
over raw prose — not a typed claim — the substrate exposes one
optional skill: `memory:fuzzy`, a vector-over-signal-content search,
registered like any other capability and priced. **It is not the
substrate.** It is a fallback the substrate can route to when typed
lookup misses, callable by agents the same way they call a CRM lookup
or a calendar check.

Three reasons this stays honest:

1. It is a `skill`, not the storage layer. Removing it removes one row;
   removing a vector store from a RAG product removes the product.
2. It runs over `signal.content`, not the corpus — that is, only over
   the messages and ingested blobs that the substrate already keeps.
3. Most queries never reach it. After ~50 turns in a world, typed
   recall handles >95% of pack assembly.

The substrate keeps the architecture clean; the skill handles the long
tail. No `vector` in the schema, no `embedding` in the UI, no
`chunk size` in settings — ever.

### Re-fetch and diff

Every source remembers where it came from. The Inbox groups rows by
source:

```
47 facts about your company
  ↳ 12 from your website        [Re-fetch]
  ↳  8 from brand-book.pdf      [Re-upload]
  ↳ 27 typed by you             —
```

`[Re-fetch]` runs the pipeline again, diffs against existing rows:

- New rows → staging tray for accept
- Rows that disappeared from source → propose `warn` (decay)
- Rows that changed → bi-temporal: old gets `valid-until = now`, new gets `valid-from = now`

One button to keep the corpus current. No cron, no integration setup.

---

## One input. The substrate decides the shape.

The UI does **not** ask the user to pick "Fact vs Playbook vs Person vs
Pin vs Note." A user typing about their company should never see those
words. They type a sentence. The substrate classifies it.

```
   user types:  "We don't take same-day appointments"
                       │
                       ▼
   signal → unit('memory:classify')   (Gemma 4, edge, ~80ms)
                       │
                       ▼
   classification: { kind: "fact", namespace: "company",
                     tags: ["scheduling", "refusal-rule"] }
                       │
                       ▼
   signal → unit('memory:assert') → hypothesis row at 0.30
```

The mapping is real but invisible:

| If the sentence sounds like… | …it becomes a | …backed by |
|------------------------------|---------------|------------|
| A statement of truth | semantic memory | `hypothesis` |
| A how-to ("always X before Y") | procedural memory | `skill` row |
| A person ("Sarah is the principal") | social memory | `capability` + `actor` |
| A connection ("X works well for Y") | associative memory | `mark(path)` boost |
| A one-off event ("X happened on Tuesday") | episodic memory | `signal` with scope |

Five primitives. Zero forms. The Inbox shows what the classifier picked
as a small label next to each row — the operator can override with a
single click if wrong, and that override `mark`s the path
`memory:classify → <correct kind>`, making the classifier sharper.

This is the same `memory:classify` and `memory:assert` units already
shipped in `chat-memory-todo.md` Cycle 2 — we are reusing them, not
inventing new ones.

### Source promotion

A user-asserted fact starts at confidence 0.30. It promotes to `verified`
when **any of** these are true:

- An owner-role actor signed it (`role >= operator` for that group)
- L6 independently produced a corroborating `observed` hypothesis
- A third actor in the group signed the same fact (`source: verified`)

The UI shows this transition. A dim fact ("draft — 0.30") brightens to a
bold fact ("verified — 0.92") when corroboration arrives. Memory has a
visible career.

---

## Two owners: company memory and user memory

Every memory entry has an **owner** — a `group` (company) or an `actor`
(user). The owner determines:

| Aspect | Group-owned memory | Actor-owned memory |
|--------|--------------------|--------------------|
| Lives on | the `group` entity | the `actor` entity |
| Visible to | every agent acting on behalf of the group | only that actor and agents they engage |
| Edited by | members with `operator+` role | the actor themselves |
| Survives | until group is dissolved | until actor calls `forget` |
| GDPR delete | `delete-memory` on group | `forget(uid)` |
| Loaded into | every `ContextPack` for that group | only packs where the actor is the user |

**This is the load-bearing claim of the doc:** an agency adds three facts
to a client's **group memory** and every chat in that world begins with
those facts already in the system prompt. No agent code changes. No model
fine-tune. Just three rows.

> Group memory is not one bucket — it is **namespaces** (see below). The
> three facts above land in `company.*`; a strategist's market read lands
> in `market.*`; a support agent's recorded patient pattern lands in
> `customer.*`. Same group, same primitives — different tag prefix and
> different agent appetite.

```
Company "North Dublin Dental" adds:
  ┌────────────────────────────────────────────────────┐
  │ Fact      │ "we don't take same-day appointments"  │
  │ Fact      │ "the principal is Dr. Sarah O'Callaghan"│
  │ Playbook  │ "always offer a Tuesday slot first"     │
  └────────────────────────────────────────────────────┘

Next chat, any agent:
  user:    "can I come in today?"
  agent:   "We don't offer same-day visits, but Tuesday
            opens up nicely — want me to hold one for you?"
```

Nothing else changed. The substrate read three rows during pack assembly
and the system prompt did the rest.

---

## Memory namespaces

Inside a single group, memory splits into **namespaces**. Each namespace
is just a tag prefix on the existing primitives — no new schema. But the
prefix is load-bearing: it determines which agents will load which rows
into their context.

| Namespace | What it holds | Edited by | Primary readers |
|-----------|---------------|-----------|-----------------|
| `company.*` | Self-knowledge: principal, hours, refusal rules, brand voice, pricing | operator | every agent in the world |
| `market.*` | TAM, trends, competitor moves, category dynamics, regulatory shifts | strategist, operator | strategy, positioning, marketing agents |
| `customer.*` | Per-actor facts about end users: preferences, history, channel, value tier | any agent (auto) + operator | support, booking, sales, success agents |
| `competitor.*` | Named competitors, their strengths, gaps, pricing, recent product moves | strategist, sales | strategy, sales, comparison agents |
| `product.*` | What we sell: SKUs, features, prices, availability, change log | product, operator | sales, support, catalog, recommendation agents |
| `industry.*` | Regulation, standards, vocabulary, body-of-knowledge (e.g. HSE, FDA) | operator, scrape | compliance, audit, copy agents |
| `internal.*` | Team rituals, escalation paths, on-call, internal vocab | operator | routing, dispatcher, escalation agents |
| `playbook.*` | How to handle a situation (procedural; maps to `skill`) | operator | every agent (matched by tag) |
| `frontier.*` | Tags the substrate suspects matter but has zero evidence on | L7 (auto) | strategy agents (curiosity prompts) |

A namespace is **a tag prefix on a `hypothesis`** (or `capability` /
`skill`). That is the whole implementation:

```
hypothesis {
  statement: "Invisalign demand grew 40% YoY in Dublin private dental"
  has tag "market"           # ← the namespace prefix
  has tag "invisalign"
  has tag "dublin"
  source: asserted
  confidence: 0.30
  signed-by: <strategist-uid>
}
```

Five practical consequences:

1. **One UI, many lenses.** The Inbox has a namespace selector. The same
   Add-Fact form writes to the active namespace by tagging accordingly.
2. **Agents declare appetite by namespace.** A strategy agent's frontmatter
   says `memory.group: [market, competitor, industry]`. A booking agent
   says `memory.group: [company, customer, playbook]`. The pack builder
   filters by tag prefix.
3. **Scrape pipelines target a namespace.** Pasting a competitor's site
   into `competitor.*`, a regulator's site into `industry.*`, the
   company's own site into `company.*`. The extractor's output schema
   shifts per target.
4. **Confidence ceilings can differ by namespace.** `customer.*` rows
   from observed behaviour can reach 0.95. `market.*` rows from a
   single analyst's read should cap at 0.60 until corroborated.
5. **Memory has reach.** The Inbox shows, per row, "loaded by 4 agents:
   strategy, positioning, sales, compare" — so the curator understands
   what writing one fact actually does.

> Namespaces are how a small UI scales to a real company without
> becoming a CMS. A founder may add five `company.*` rows; a strategist
> may add fifty `market.*` rows monthly; a support agent may auto-emit
> hundreds of `customer.*` rows daily. They all land in the same typed
> store, but agents see only the namespaces they need.

---

## Agents × Skills × Memories

The substrate has three composable primitives. Each does one thing.

```
   AGENTS      ──── who answers ─────  units with a system prompt
                                       routed to by pheromone

   SKILLS      ──── what they can do ─  procedural memory; a callable
                                       handler with price + tags

   MEMORIES    ──── what they know ───  semantic memory + facts
                                       loaded into the ContextPack
```

They compose like this:

```
  user turn  →  router picks agent  →  agent loads memories  →  agent invokes skills
                       ▲                       │                       │
                       │                       ▼                       ▼
                  highways                ContextPack             outcome signal
                  (associative           (semantic +              (mark / warn —
                   memory routes         social memory             feeds back into
                   the turn)             go into prompt)           highways)
```

The triangle in plain English:

- **An agent is empty without memories.** A "strategy agent" with no
  `market.*` rows is a generic LLM call.
- **A memory is silent without an agent.** A `market.*` fact sits in
  TypeDB doing nothing until an agent whose appetite includes
  `market` runs a turn.
- **A skill is the bridge.** When the agent needs to *do* something
  (look up a price, send an email, draft a forecast), it calls a
  skill — and the skill's own outcomes feed `mark/warn` back into
  the substrate, sharpening which skills get picked next time.

### Which memory feeds which agent

Concrete pairings — these are seed defaults; an operator can override
per agent.

| Agent role | Reads namespace | Writes namespace | Typical skills called |
|------------|-----------------|------------------|------------------------|
| **strategy** | `market`, `competitor`, `industry`, `frontier` | `market`, `frontier` | `research`, `summarize`, `forecast` |
| **positioning** | `market`, `company`, `competitor` | `market` | `compare`, `write-positioning` |
| **sales** | `company`, `product`, `customer`, `competitor` | `customer` | `quote`, `email`, `crm-write` |
| **support** | `company`, `product`, `customer`, `playbook` | `customer` | `lookup-order`, `escalate`, `refund` |
| **booking** | `company`, `playbook`, `customer` | `customer` | `calendar`, `confirm`, `remind` |
| **compliance** | `industry`, `company`, `product` | `industry` | `cite`, `redline`, `attest` |
| **copy / marketing** | `company`, `market`, `customer`, `industry` | (none — proposes drafts) | `draft`, `tone-check`, `seo-audit` |
| **dispatcher / routing** | `internal`, `playbook` | (none) | `route`, `escalate` |
| **success / account** | `customer`, `company`, `product` | `customer` | `qbr`, `summarize`, `email` |

Three patterns this table makes obvious:

1. **Strategy agents are market-shaped.** Add five `market.*` facts and
   every strategy chat begins informed. This is the user's example
   working end-to-end.
2. **Customer agents are write-back-heavy.** Support, sales, booking,
   and success all *learn* about the customer as they go — autoemitting
   `customer.*` rows that the next session inherits.
3. **Copy / marketing reads broadly, writes nowhere.** A copywriter
   agent needs the whole world but should not assert facts; its output
   is a draft, not memory.

### How an agent's `.md` declares its memory appetite

```yaml
---
name: strategy
model: anthropic/claude-opus-4-7
memory:
  group:
    read:  [market, competitor, industry, frontier]
    write: [market, frontier]
  actor:
    read:  [preferences, history]
    write: [preferences]
  highways: 10           # top N paths loaded into pack
  cap_tokens: 2000       # memory budget
skills:
  - research
  - summarize
  - forecast
---
```

`buildPack` reads this block and filters TypeDB rows by namespace tag
before assembling the prompt. The cap_tokens prevents a 500-row
`market.*` from drowning the system message — confidence-ranked, top-N
fits the budget, the rest are queryable on demand via a skill.

### The skill–memory feedback loop

Skills are procedural memory. They have prices and outcomes. When a
strategy agent calls `forecast`, the outcome `mark`s the path
`strategy → forecast` and the `mark` updates a `customer.*` row
("this user finds quarterly forecasts useful"). Next turn, the pack
surfaces that hypothesis with confidence ≥ 0.85 and the agent reaches
for `forecast` again. **Skills get sharper because memory gets sharper
because skill outcomes update memory.** Single loop. No coordinator.

---

## Sidebar wiring — where Memory lives

Memory is a **first-class entry under Tools** in the workspace nav, so
that an operator's most-frequent curation surface is one click from any
page. Two changes to `web/src/lib/menu.ts`:

1. Add a top-level `/u/{slug}/memory` route alongside Tools (or as the
   first submenu under Tools — see below).
2. Submenus expose namespaces directly.

```ts
// in getUserMenu, alongside the existing tools item:
{
  href: `${base}/memory`,
  label: 'Memory',
  icon: Brain,
  viewer: ['owner', 'agency', 'client'],
  submenus: [
    { href: `${base}/memory/company`,     label: 'Company' },
    { href: `${base}/memory/market`,      label: 'Market' },
    { href: `${base}/memory/customer`,    label: 'Customers' },
    { href: `${base}/memory/competitor`,  label: 'Competitors' },
    { href: `${base}/memory/product`,     label: 'Products' },
    { href: `${base}/memory/industry`,    label: 'Industry' },
    { href: `${base}/memory/playbook`,    label: 'Playbooks' },
  ],
},
```

The list is **derived from configured namespaces**, not hardcoded — a
group can add or hide namespaces in Settings. The default seven cover
~95% of customer cases.

```
┌─────────────┐
│ Dashboard   │
│ Inbox       │
│ Chat        │
│ Agents    ▸ │
│ Skills      │
│ Tools       │
│ Memory    ▾ │   ← always one click away
│   Company   │
│   Market    │
│   Customers │
│   Competitors│
│   Products  │
│   Industry  │
│   Playbooks │
│ ─────────── │
│ Clients     │
│ Staff       │
│ ─────────── │
│ Settings    │
└─────────────┘
```

Why under Tools and not under Settings: memory is **operational**, not
configurational. It changes every week. Settings are the things you
configure once.

Why a top-level entry and not buried inside `/tools`: because every
seat — owner, agency, client — needs to add and audit memory routinely,
and discoverability matters more than nav purity.

### Route layout

```
/u/[slug]/memory/index.astro              # Inbox (all namespaces)
/u/[slug]/memory/[namespace].astro        # one namespace view
/u/[slug]/memory/[namespace]/[id].astro   # single-row detail
/u/[slug]/memory/scrape.astro             # URL → staging
/u/[slug]/memory/staging.astro            # pending acceptance queue
```

All five pages are React `client:only` islands inside `Layout.astro`,
sharing one `useMemory` hook and one substrate boundary
(`lib/substrate.ts`).

---

## The four UI surfaces

The Memory UI is not one page. It is four surfaces, each tuned to a
moment.

### 1. **Memory Inbox** (`/u/{slug}/memory`)

The single place a human curates everything the world remembers about a
group or themselves. **The default view is `company.*` and the default
action is "type a sentence and press Enter."** Curation should feel
like sending a one-line message, not filling a form.

```
┌─────────────────────────────────────────────────────────────────┐
│  Memory — North Dublin Dental                         Company ▾ │
├─────────────────────────────────────────────────────────────────┤
│  Tell your agents something about your company:                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ We don't take same-day appointments_____________________⏎│  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ★ verified  ◯ asserted   ⬡ observed                            │
│                                                                 │
│  ★ Principal is Dr. Sarah O'Callaghan          company  0.92 ⋯  │
│  ◯ No same-day appointments                    company  0.30 ⋯  │
│  ⬡ Most patients ask about Invisalign          market   0.78 ⋯  │
│  ★ Closed Sundays                              company  0.95 ⋯  │
│  ⬡ alice prefers email follow-ups  ← agent     customer 0.42 ⋯  │
│                                                                 │
│  [Show 8 more]    [Paste a URL to extract more]                 │
└─────────────────────────────────────────────────────────────────┘
```

One input, Enter to add. Behind the box it fires:

```ts
signal({
  receiver: 'memory:assert',
  payload: { namespace: 'company', statement: input, tags: [] },
  scope: 'group',
})
```

The namespace dropdown in the corner switches which namespace Enter
targets. The row appears in the list immediately at confidence 0.30,
then promotes to 0.85 when the operator clicks ⋯ → Verify (one click,
one signal). Most operators never see a form.

The list mixes human-asserted rows and agent-emitted rows transparently.
The "← agent" tag flags rows the operator might want to verify in
batch. Curation is review, not authorship.

### 2. **Inline memory cards in chat**

Mid-conversation, an agent surfaces what it's using:

```
agent: "Booking you in for Tuesday — we don't take same-day visits."
       [memory used: 2 facts, 1 playbook]  ▼
```

Expand the card → see the three rows the agent loaded. **One-click
forget** for any of them (with double-confirm). **One-click verify**
to promote an asserted row to verified.

This is the second-most important surface. It is the place humans
discover what memory exists by seeing it in action — not by browsing
a settings page. Every chat is a memory inspector.

### 3. **Onboarding step "What should your agents know?"**

In `OnboardingFlow.tsx`, after channels and branding, before "go live",
a step that produces the first 3-10 facts about the company:

```
"Tell us three things every agent should know about [Company]."
  ▢ ____________________________________________________
  ▢ ____________________________________________________
  ▢ ____________________________________________________

  Or paste your website URL and we'll extract them.
  [https://__________________________________]  [Extract]
```

The "Extract" path is the **scrape pipeline** below. It is the single
most important conversion mechanic — going from zero memory to ten
verified facts in 30 seconds.

### 4. **The `/memory` chat command + chat paste**

Already shipped (Cycle 4 of `chat-memory-todo.md`). Inside any chat:

- `/memory` — show the user's reveal card
- `/memory company` — show the group's memory (operator+ only)
- `/memory add "fact about X"` — write an asserted hypothesis
- `/memory forget {id}` — soft-delete one row
- `/memory verify {id}` — promote asserted → verified (operator+)
- `/explore` — show frontier tags ("you've never mentioned...")
- `/forget` — full GDPR erasure (double-confirm)

**Chat paste — same pipeline.** An operator in any chat can paste a
URL, drop a file, or paste a long blob, prefixed with `/learn`:

```
/learn https://acme.co/about
/learn
{paste the entire About page here…}
/learn  (then drag-drop brand-book.pdf)
```

The chat composer routes through the same `detect-input` → extract →
stage path as the Inbox. The agent's next reply confirms what was
staged: *"I've extracted 14 facts from your About page. View / accept
in [Memory](/u/{slug}/memory)."* One click to verify. Chat is the
seeding surface; the Inbox is the curation surface. Same pipeline.

The chat command is the power-user surface. The Inbox is the curator's
surface. The inline card is the discovery surface. Onboarding is the
seed surface. Four entry points, one substrate.

---

## Web scrape → memory: the seed engine

The single most magical moment in this UI is pasting `northdublindental.ie`
and getting twelve verified facts the agents will use from the next turn.

```
URL paste
    │
    ▼
┌─────────────────────────────────────────────┐
│ 1. unit('memory:scrape')                    │
│    Fetch page (Cloudflare Browser Rendering)│
│    Parse semantic HTML (h1, h2, p, dl, faq) │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│ 2. unit('memory:extract')                   │
│    LLM extract → typed primitives:          │
│      facts[]      → hypotheses              │
│      people[]     → capabilities            │
│      services[]   → skills                  │
│      hours[]      → schedule attrs on group │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│ 3. Staging view in Inbox                    │
│    All marked source=asserted, conf=0.30    │
│    Each row has [accept] / [edit] / [skip]  │
│    Operator can [accept all] in one click   │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│ 4. On accept by operator role               │
│    source: asserted → verified              │
│    confidence: 0.30 → 0.85                  │
│    signed-by: <operator-uid>                │
│    audit signal emitted                     │
└─────────────────────────────────────────────┘
```

Two notes on the design:

- **The LLM only runs at the edge.** Per the memory doc: embeddings and
  prose-extraction live at the ingest boundary, not inside the substrate.
  Scraping is an ingest path — once typed, the substrate handles the rest.
- **Acceptance is the trust gate.** The LLM proposes; a role-gated human
  disposes. This is what keeps prompt injection from reaching the verified
  tier — a scraped page cannot self-promote.

### What the scraper extracts

| Page section | Extracted as | Example |
|--------------|--------------|---------|
| `<title>`, `<meta>` | Fact | "North Dublin Dental is a private dental practice in Drumcondra" |
| `<h1>`, hero copy | Fact | "Specialists in cosmetic dentistry and Invisalign" |
| FAQ blocks | Fact (per Q→A) | "Same-day appointments: not available; book 48h ahead" |
| Team page | Person + capability | `actor(sarah)`, `capability(sarah, dentistry, price 0)` |
| Services list | Skill | `skill(invisalign)`, `skill(whitening)` |
| Hours table | Group attributes | `group has opening-hours "Mon-Fri 9-5, Sat 9-1"` |
| Reviews | Pin | `mark(path: reviews-source → trust, +5)` |
| Sitemap / nested pages | Frontier tags | unexplored areas the agent can later ask about |

Six row shapes. No free-text dumps into a vector store. Every row is
queryable, fadeable, and forgettable.

### Cadence

A scrape isn't a one-time event. The unit re-fetches monthly (or on
manual `[Re-scrape]`) and **diffs** the extracted facts against existing
hypotheses:

- New rows → staging tray for accept
- Removed rows → propose `warn` on the existing hypothesis (decays)
- Changed rows → bi-temporal: existing row gets `valid-until = now`, new
  row gets `valid-from = now`

The website is treated as one source of evidence, not the truth.

---

## How memory loads into context

This is already implemented in `units/recall.ts` and
`lib/prompt.ts` (Cycle 3 of `chat-memory-todo.md`). The UI must not
re-do it; the UI must let humans **predict** it.

```
turn arrives
    │
    ▼
buildPack({ user, group, recent })
    │
    ▼
3 parallel reads:
  ┌──────────────────────────────────────────────┐
  │ a. group-owned hypotheses (this group)       │
  │    → "every agent here knows this"           │
  │ b. actor-owned hypotheses (this user)        │
  │    → "this user specifically knows / asks X" │
  │ c. highways from actor (top paths by str)    │
  │    → "what's been working for this user"     │
  └──────────────────────────────────────────────┘
    │
    ▼
prompt assembly (tiered confidence):
  ≥ 0.85 → direct fact ("Closed Sundays.")
  0.50..0.85 → hint ("Consider that...")
  < 0.50 → omit (do not surface in prompt; still queryable)
    │
    ▼
LLM call
```

Two visible UX consequences:

1. **A fact at confidence 0.30 will not appear in chat.** This is correct
   — but disorienting if the user just added it and expects an effect.
   The Inbox surfaces this: any asserted-only row shows a small
   *"not yet quoted — verify or wait for the substrate to corroborate"*
   helper. One click promotes.

2. **The agent never sees who added the memory.** Source and signer are
   metadata used for promotion and audit, not surfaced to the model.
   This is deliberate — the LLM should reason from the fact, not from
   the politics of who asserted it.

### Per-agent memory scope

Not every agent needs every fact. Agents declare their pack appetite in
their `.md` frontmatter:

```yaml
---
name: booking-agent
memory:
  group: [hours, services, refusal-rules]   # tag filters
  actor: [preferences, history]
  highways: 5
---
```

The pack builder filters group memory by tag. A booking agent gets the
"no same-day" fact; a marketing agent doesn't (unless tagged
`marketing`). This is how a world with 1000 facts stays inside a 4k
context budget. The Inbox shows, per row, **which agents will use this**
— so curators understand reach.

---

## The "memory determines outcome" demos

Three end-to-end paths, one for each of the namespaces a new operator
is most likely to touch first.

### A. Company memory → support agent

```
1. Operator pastes https://northdublindental.ie → [Extract]
2. 12 company rows appear in staging. [Accept all].
3. End user asks: "can i come in today?"
4. Support agent replies:
     "We don't offer same-day visits. Want a Tuesday slot?"
   [memory used: 2 facts from company.*]
5. URL → memory-aware reply: ≈ 30 seconds.
```

### B. Market memory → strategy agent

```
1. Operator opens /u/dental/memory/market
2. Adds three rows:
     "Invisalign demand grew 40% YoY in Dublin private dental"
     "New entrant 'BrightSmile' opened 3 clinics in 2026"
     "HSE PRSI cover for orthodontics under review (Q2 2026)"
3. Verifies each (operator role).
4. End user asks the strategy agent:
     "should we push Invisalign harder?"
5. Strategy agent replies:
     "Demand is up 40% YoY locally — but BrightSmile is moving on
      the same wedge with three new clinics. The PRSI review could
      reset margin assumptions. Lead with Invisalign, but hedge..."
   [memory used: 3 facts from market.*]
6. Three rows changed every strategy chat in the world. No agent
   code touched. No re-deployment.
```

### C. Customer memory → booking agent (agent writes its own memory)

```
1. End user "alice" books her first appointment via the booking agent.
2. Mid-turn, the booking agent fires:
     signal({
       receiver: 'memory:assert',
       payload: {
         namespace: 'customer',
         statement: "alice prefers Tuesday afternoons; channel: telegram",
         tags: ['alice', 'preference', 'schedule'],
       },
       scope: 'group',
     })
3. Hypothesis lands at confidence 0.30, source: asserted, sender:
   <booking-agent-uid>.
4. Operator sees it in the Inbox the next morning, tagged "← agent",
   clicks Verify. Confidence → 0.85.
5. Six weeks later alice asks: "next available slot?"
6. Booking agent's pack loads the verified hypothesis:
     "Tuesday afternoon at 3:30 — your usual?"
   [memory used: 1 fact from customer.alice.*]
7. No human ever taught the agent anything about alice.
   The signal was the teacher.
```

Three namespaces, three writers (operator / strategist / **agent**), one
substrate. That is the moment.

---

## Component layout (where the code lives)

| Component | Path | Purpose |
|-----------|------|---------|
| `MemoryInbox.tsx` | `one.ie/web/src/components/memory/` | the curator page (surface 1) |
| `MemoryRow.tsx` | same dir | one row per hypothesis/capability/skill |
| `MemoryAddDialog.tsx` | same dir | the "Add fact" / "Add playbook" forms |
| `MemoryScrapeDialog.tsx` | same dir | URL paste → staging tray |
| `MemoryStagingTray.tsx` | same dir | accept/edit/skip extracted rows |
| `MemoryCardInChat.tsx` | `components/chat/` | inline memory used in a reply |
| `OnboardingMemoryStep.tsx` | `components/onboarding/` | step in `OnboardingFlow.tsx` |
| `useMemory.ts` | `packages/react/src/` | React 19 hook over the API |

Existing pieces to extend, not duplicate:

- `pages/api/pii/reveal/[actor].ts` — already returns memory card
- `pages/api/forget/[id].ts` — already does GDPR erasure
- `pages/api/frontiers.ts` — already returns frontier tags
- `lib/substrate.ts` `recallHypotheses()`, `actorHighways()` — pack feeders

Missing API surface to add (5 routes):

| Method | Route | Purpose | Role gate |
|--------|-------|---------|-----------|
| POST | `/api/memory/assert` | add user/group hypothesis | user (own) / operator (group) |
| PATCH | `/api/memory/:id` | edit text, scope, valid-until | author or operator |
| POST | `/api/memory/:id/verify` | promote asserted → verified | operator |
| POST | `/api/memory/scrape` | URL → staging tray | operator |
| POST | `/api/memory/staging/:id/accept` | staging → verified | operator |

All five obey the locked role-permission matrix from `memory-c4-todo.md`.

---

## Elegance, measured

A typed substrate earns the right to a tiny UI. Targets:

| Measurement | Target |
|-------------|--------|
| Time from cold-open Inbox to first verified fact | **< 10 seconds** |
| Clicks to add one company fact | **1** (type, Enter) |
| Form fields visible above the fold | **1** (the sentence) |
| Memory-related words in nav | **1** (`Memory`) |
| Stores the operator can see in the UI | **1** (this one) |
| Memory routes the developer must implement | **1 write path** (`memory:assert` signal) |
| Settings the operator must tune | **0** (no chunk size, no top-k, no embedding model) |

If any of these grows, the UI has stopped being substrate-native and
started becoming a CMS. Stop and delete a control.

> The competitor's product has a memory page with tabs for "Episodic /
> Semantic / Procedural", a settings panel for "Embedding model" and
> "Re-rank threshold", and a debug view for "Vector similarity score".
> Ours has a sentence box and a list. Same five memory types under the
> hood. Theirs is honest about its scaffolding. Ours is honest about
> the substrate underneath.

---

## What the Memory UI must not become

This doc would fail if it produced any of the following:

- **A second memory store.** Everything resolves to existing primitives.
- **A way past the asserted-source ceiling.** Even owner-signed facts
  remain auditable; the audit signal is emitted on every promotion.
- **A vector-DB browser.** The substrate is typed. The UI is typed. The
  embedding edge is internal, not user-facing.
- **A prompt-injection surface.** A scraped page never auto-verifies.
  A chat user can never elevate their own memory. The role gate is the
  only path to verified.
- **Days/weeks/months of "memory management" work.** A good Inbox
  session is under a minute. If a user spends 20 minutes editing memory,
  the agents weren't using it well — and that is a *substrate* problem,
  not a UI problem.

---

## Rollout cycles

| Cycle | Surface | Exit condition |
|-------|---------|----------------|
| **C1 — Inbox v1 + sidebar + namespaces** | `/u/{slug}/memory`, sidebar entry, 7 namespace routes, add/edit/forget | operator writes 3 `company.*` facts and sees them in the next chat |
| **C2 — Scrape** | URL → staging → accept, target-namespace per scrape | 30-second demo: company URL → support agent reply, competitor URL → strategy agent reply |
| **C3 — In-chat card** | `MemoryCardInChat.tsx`, namespace badge per source, one-click verify/forget | every reply with > 0 pack rows shows its namespaces |
| **C4 — Agent appetite blocks** | `memory:` frontmatter in agent `.md`, honored by `buildPack` | strategy agent only sees `market.*`; booking agent only sees `company.* + customer.*` |
| **C5 — Onboarding step** | `OnboardingMemoryStep.tsx`, three-namespace seed (company / market / playbook) | new groups go live with ≥ 10 verified rows across ≥ 2 namespaces |
| **C6 — Skill-memory feedback** | skill outcomes auto-emit `customer.*` rows on confirmed valence | a returning user in week 2 gets a reply that quotes a week-1 hypothesis |

Each cycle uses the W1-W4 wave protocol from `.claude/commands/do.md`.
No cycle expands the schema; every cycle ships against existing
primitives.

---

## Open questions

These are real, not rhetorical — surface in W2 when the matching cycle
begins.

1. **Default scope for asserted facts.** `group` seems right (the company
   added it for its agents), but a chat user adding a personal preference
   probably wants `private`. The form should pick a sensible default and
   make the switch a one-click toggle.

2. **Memory limits per group / per actor.** A vector store sets no limit;
   a typed store probably should. A reasonable starting cap: 500 hypotheses
   per group, 100 per actor, with frontier-based suggestions when full
   ("you have 480 facts — three contradict each other; merge?").

3. **Conflict resolution at edit time.** Editing the *text* of a fact is
   fine. Editing the *meaning* should produce a new row with `valid-from`
   = now and `valid-until` set on the old row. The UI must make this
   distinction visible — "this is a correction" vs "this is a new fact".

4. **Read-only vs editable scraped pages.** Should a row that came from
   a scrape remain bound to its source URL (re-extracting overwrites
   manual edits), or should manual edits permanently fork it? Likely the
   latter — but the staging tray needs to call this out.

---

## See also

- [memory.md](memory.md) — substrate memory model
- [agents-memory.md](agents-memory.md) — per-agent recall
- [world-memory.md](world-memory.md) — collective learning
- [chat-memory-todo.md](chat-memory-todo.md) — shipped chat memory
- [memory-c4-todo.md](memory-c4-todo.md) — role gates (load-bearing for this UI)
- `.claude/rules/engine.md` — three locked rules (closed loop, structural time, deterministic results)

---

*The substrate already remembers what happened. The UI is for the things
you want it to know **before** they happen.*

*One input. One signal. One row. One prompt. No RAG, no chunks, no
vectors, no settings. That is the elegance.*
