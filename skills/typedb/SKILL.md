---
name: typedb
description: Write, debug, and deploy TypeQL against the ONE substrate on TypeDB 3.12.1. Use when editing any `.tql` file under `schema/` (one.tql, roles.tql, do.tql, reason.tql, router.tql, factory.tql, work-contract.tql, migrations/), writing a `fun`, composing a match/insert/update/put pipeline, reading or writing through the `/v1/` HTTP API, or diagnosing a TypeDB error code (TQL0, REP1, REP4, REP44, FIN4, FUN5, SVL2, COW5, WCP4, INF11) or a query that hangs. ALSO covers the gateway door every query here goes through — the 10000-row cap, the 10s timeout and the circuit breaker, NO_WRITE_RETRY, read-after-write lag, and the request-path rule. Triggers — "write a TypeQL query", "add a fun", "change the schema", "deploy the schema", "this TypeDB query times out", "why is this .tql rejected", "match/fetch/reduce syntax", "TypeDB 2.x vs 3.x", "my query returns exactly 10000 rows", "why is truncated always false", "how do I count rows in TypeDB", "TypeDB 500 aborted due to timeout", "TypeDB circuit open / 503", "400 on a valid insert", "CNT5 card violation", "can I retry a failed write", "should this read go through the snapshot".
---

# TypeDB 3.x Complete Reference Skill

> **Version**: TypeDB **3.12.1** — prod (TypeDB Cloud) AND the local OrbStack
> container both run 3.12.1 as of 2026-07-29. Profiles: `.claude/typedb/{dev,prod}.env`,
> switched by `.claude/scripts/typedb-env.sh`. Never assume 3.0 or 3.8.x behaviour.
> **Last Updated**: 2026-09-21 — added *The door: what changes because you go through a gateway*
> (the row cap, the request-path rule, the timeout/breaker, `NO_WRITE_RETRY`, read-after-write,
> two concurrency defects, and the `fun`-read-by-two-engines constraint coming with `tql-edge`).
> Syntax claims last re-probed read-only against live 3.12.1 on 2026-08-02.
> **Purpose**: Comprehensive TypeDB/TypeQL reference for Claude Code
> **Primary sources**: TypeQL paper (Dorn & Pribadi, PACMMOD 2024, *Best Newcomer Award* at SIGMOD/PODS 2024) · TypeDB lecture series (Vaticle YouTube, 2023–2024) · "Inside TypeDB: The Next Chapter" (Dec 2025) · TypeDB 3.0 roadmap ([GitHub #6764](https://github.com/typedb/typedb/issues/6764))
>
> **In-repo canon is `schema/`, not this file.** `schema/one.tql` (480 lines) is the
> locked ontology; `schema/CLAUDE.md` says which files load, in what order, and which
> must never co-load. When this skill and a `.tql` disagree, the `.tql` wins.
>
> **How this repo actually talks to TypeDB: the `/v1/` HTTP API.** No driver package
> is installed anywhere in the monorepo. TypeScript goes through
> `one.ie/web/src/lib/substrate.ts` → the gateway in `api/src/index.ts` → `POST
> {TYPEDB_URL}/v1/query`; the Python scripts in `backup/scripts/typedb/` use
> `urllib` against the same endpoint. The *Python Driver* section below is
> background for reading upstream docs — it is not the path any code here takes.
>
> **Do not mock TypeDB in tests.** Real TypeDB or skip (root `CLAUDE.md`).

---

## Table of Contents

1. [Overview](#overview) — includes *Fourth Category of Database* and *Queries as Types* framing
2. [Critical Syntax Rules](#critical-syntax-rules)
3. [Schema Definition](#schema-definition)
4. [Data Pipelines](#data-pipelines)
5. [Query Operations](#query-operations)
6. [Functions](#functions)
7. [Patterns](#patterns)
8. [Annotations](#annotations)
9. [Value Types](#value-types)
10. [Python Driver](#python-driver)
11. [Transaction Management](#transaction-management)
12. [The door: what changes because you go through a gateway](#the-door-what-changes-because-you-go-through-a-gateway) — **repo-specific; the row cap, the breaker, `NO_WRITE_RETRY`**
13. [Best Practices](#best-practices)
13. [Query Optimization](#query-optimization)
14. [Complete Keyword Reference](#complete-keyword-reference)
15. [Mental Models (Type Theory, Polymorphism, Dependent Types)](#mental-models-type-theory-polymorphism-dependent-types)
16. [Canonical Polymorphic Example: Filesystem + Ownership](#canonical-polymorphic-example-filesystem--ownership)
17. [TypeDB 3.x Feature Deep Dive](#typedb-3x-feature-deep-dive) — cascade, structs, list attrs, `@index`, functions, MVCC
18. [Production Deployment & Scaling](#production-deployment--scaling)
19. [Development Tools & Ecosystem](#development-tools--ecosystem) — Studio, Vibe Querying, Cloud, LSP
20. [SQL → TypeQL: Concrete Contrasts](#sql--typeql-concrete-contrasts)
21. [Works With /sui](#works-with-sui--the-same-ontology-two-deterministic-fires)
22. [Production Patterns: Classifier Functions, Thing Collapse, Symmetric Routing](#production-patterns-classifier-functions-thing-collapse-symmetric-routing) — from `schema/world.tql`
23. [Project-Specific Patterns](#project-specific-patterns)

---

## Overview

TypeDB is a strongly-typed, polymorphic, transactional database using the **Polymorphic Entity-Relation-Attribute (PERA)** data model. TypeQL is its declarative query language. The **PERA model** and its **Queries as Types** principle were published at SIGMOD/PODS 2024 (Dorn & Pribadi, PACMMOD 2024, Article 110, *Best Newcomer Award*) — DOI [10.1145/3651611](https://dl.acm.org/doi/10.1145/3651611).

### The Fourth Category of Database

TypeDB is positioned as a **fourth category of database**, generalizing the first three:

1. **Relational** — tables, rows, foreign keys
2. **Graph** — nodes, edges, labels
3. **Document** — nested JSON-like trees, flexible schema
4. **Polymorphic (TypeDB)** — entities, relations, attributes with type polymorphism, interface-based role playing, and type-theoretic query semantics

TypeDB 3.x is written in **Rust** (rewritten from Java in 2024–2025) and is "competitive and surpassing Neo4j" on their first Rust optimization pass (per "Inside TypeDB: The Next Chapter", Dec 2025). It's especially aimed at:
- **Knowledge graphs** and semantic-driven applications
- **Intelligent / agentic systems** that need polymorphic reasoning
- **Complex domain models** where inheritance, role-based access, and multi-value constraints matter

### Queries as Types (the core mental model)

TypeQL's design inverts SQL's operational worldview. In SQL you write a *plan* (scan, filter, project). In TypeQL you describe a **type** — and that type *is* the query:

```typeql
# This pattern describes a type: "(user, name) pairs where user owns name"
match
  $u isa user, has name $n;
select $u, $n;
```

This is a generalization of Wadler's *Propositions as Types* into **Queries as Types**. Consequences:
- **Composability** — types compose (dependent types), queries stay concise as schemas grow.
- **Polymorphism by default** — `$x isa vehicle` matches cars, bikes, drones without rewriting.
- **Planner freedom** — declarative intent lets the optimizer reorder, parallelize, index freely.

### Core Concepts

- **Entity Types**: Independent objects that exist without dependencies
- **Relation Types**: **Dependent types** — their instances depend on instances of other types (role players). Explicit n-ary dependency makes integrity, cascade, and indexing explicit.
- **Attribute Types**: Store primitive values, identified by their value. Immutable by identity.
- **Roles**: **Interfaces** that types implement to participate in relations (think typeclasses / traits).
- **Ownership**: Types declare what attributes they own. `plays` declares roles they fulfill.
- **Type Hierarchies**: Single-inheritance subtyping with `sub`. Works on entities, relations, AND attributes.
- **Type Functions**: `fun` declarations replace 2.x `rule`; dependent-type subtyping generalizes Datalog-like reasoning.

### Connection Details (this repo — the `/v1/` HTTP API)

Two endpoints, both 3.12.1, both database `one`, credentials in
`.claude/typedb/{dev,prod}.env`:

```
prod  https://flsiu1-0.cluster.typedb.com:1729   (TypeDB Cloud)
dev   http://127.0.0.1:8000                      (local OrbStack container)
```

`bash .claude/scripts/typedb-env.sh {dev|prod|status|up|down}` rewrites the four
`TYPEDB_*` lines in `one.ie/web/.env`. Every call is two HTTP requests:

```bash
TOKEN=$(curl -s -X POST "$TYPEDB_URL/v1/signin" \
  -H 'content-type: application/json' \
  -d "{\"username\":\"$TYPEDB_USERNAME\",\"password\":\"$TYPEDB_PASSWORD\"}" \
  | jq -r .token)

curl -s -X POST "$TYPEDB_URL/v1/query" \
  -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"query":"match $g isa group; reduce $c = count($g);",
       "databaseName":"one","transactionType":"read","commit":false}'
```

`transactionType` is `read` | `write` | `schema`; `commit` must be `true` for
anything but `read`. `GET /v1/databases/one/schema` dumps the live schema —
the fastest way to answer "is this fun actually deployed?". `GET /v1/version`
returns the running build.

**A timeout arrives as HTTP 500, not 408 or 503.** The body carries
`"The operation was aborted due to timeout"` — and that string was absent from
`RETRYABLE` in `one.ie/web/src/lib/substrate.ts` until 2026-09-14, so every timed-out
read failed hard on the first try. Reads now retry it; **writes deliberately do
not** — a write that timed out may already have committed, so retrying it is a
duplicate, not a recovery. Classify by the message, never by the status code.

The Python driver (`TypeDB.driver(...)`, `driver.transaction(...)`) is covered in
the *Python Driver* section for reading upstream docs. **No code in this repo
uses it** — there is no `typedb-driver` dependency in any `package.json` or
`requirements.txt`.

---

## Critical Syntax Rules

### MUST-KNOW RULES

| Feature | Correct TypeDB 3.x (verified on 3.12.1) |
|---------|-------------------|
| Sessions | **NO SESSIONS** - transactions directly on driver |
| Concept API | **DROPPED** — all operations go through TypeQL queries |
| Query syntax | `match ... select` |
| Delete syntax | `delete $attr;` (NOT `delete $e has attr $attr;`) |
| Value type: integer | `integer` (NOT `long`) |
| Value type: float | `double` |
| Type declaration | `entity person` (root types) or `entity employee sub person` (subtypes) |
| Variables | All use `$` |
| Functions | `fun name() -> type:` (replaces rules) |
| Attributes | **CANNOT** own attributes. **CANNOT** play roles. Model as entities if you need either. |
| Role aliasing | `relates group as owned` — a subtype relation can rename an inherited role |
| List attributes | `attribute emails, value string[];` — 3.x-only syntax for list-valued attributes |
| Struct values | `struct address { street: string, city: string };` — 3.x compound values |

### VERIFIED against the live cluster (flsiu1-0.cluster.typedb.com)

These override anything else in this file — each was probed against the prod
TypeDB Cloud build (`commit:false` schema txs, or read txs with `with fun`).
Rows are dated: **2026-07-07** was probed on the pre-bump build; the syntax rows
marked **re-probed 2026-08-02** were re-run against live **3.12.1** and still
hold. `with fun … match …` in a `read` transaction is the cheap way to test
function syntax without touching the schema.

| Claim elsewhere in this file | What the live cluster ACTUALLY accepts |
|---|---|
| `return first if (...) then X else Y` conditional returns | **REJECTED — re-probed 2026-08-02 on 3.12.1, still rejected.** `match let $x = if (true) then 1 else 2;` → `[TQL0] [TQL03] syntax error: expected PLUS, MINUS, TIMES, DIVIDE, POWER, or MODULO`. There is no conditional *expression* in TypeQL. Encode classifiers as an exhaustive disjunction that binds a `let` per branch, then `return first $var`: `{ $st == "halted"; let $stage = "halted"; } or { … };` — this is exactly what the deployed `do_stage` and `path_status` do. **Beware:** `schema/world.tql`, `schema/sui.tql` and `schema/skins.tql` in this repo are written in the `if/then/else` form and are therefore NOT deployable to the main `one` database — see the note in *Production Patterns* below. `schema/reason.tql` carries the deployable rewrite of `path_status`. |
| `return $x;` for scalar functions | **REJECTED** — scalar returns require a selector: `return first $x;` (`expected return_single_selector or return_reduce_reduction`) |
| `fun f() -> { $to: city }` — naming the returned variable in the signature | **REJECTED** (re-probed 2026-08-02) — `[TQL0] syntax error: expected named_type_any`. A stream return type is types only: `-> { city }`, `-> { actor }`, `-> { thing, string }`. Tuple returns without braces (`-> string, integer`) are valid. |
| stream membership via `contains` — `my_stream_fun($x) contains $y;` | **REJECTED** (re-probed 2026-08-02) — `[REP44] The variable 'y' is required to be bound to a value before it's used`. `contains` is *substring* matching on strings. Iterate a stream with `let $y in my_stream_fun($x);` — the only form the deployed schema uses. |
| calling a `fun` and then reading attributes off the returned rows | **Works, but it is the wrong tool and it is slow.** Functions are for **COUNTS and scalars** — `return count($x)`, `return first $status`. When you need **rows plus their attributes**, do NOT call the fun and then `has` the results: **inline the fun's body** into your match and select the attributes there. This is the single most common cause of a query that "works locally, hangs in prod". |
| a `\uXXXX` escape inside a TypeQL string literal | **Killed the server process on 3.8.3** (a PANIC, not an error) — reproducer at `.claude/scripts/typedb-probes/panic-probe.py`, and the reason `backup/scripts/typedb/dump.py` renders every literal with `ensure_ascii=False`. Prod and local moved to **3.12.1 on 2026-07-29 and this has not been re-probed since.** Treat as unresolved: keep emitting raw UTF-8, never `\uXXXX`. The same build also panicked on the same variable used in two roles. |
| `fun f(threshold: double = 10.0)` default params | **REJECTED** — params need `$` and no defaults: `fun f($threshold: double)` |
| `define fun` re-applies like types | **REJECTED** (`FUN5 already exists`) — an existing function needs `redefine fun …` (one per tx); `define` is idempotent for types only |
| `redefine attribute x, value string @values(…)` | Syntax is `redefine x value string @values(…);` — no `attribute` keyword, no comma |
| value param binding an attribute: `has tag $axis` ($axis: string param) | **REJECTED** (`REP1`) — bind then compare: `has tag $t; $t == $axis;` |
| role named `as` (e.g. `relates as`) | **REJECTED** — `as` is reserved (role aliasing). A relation using it makes the whole file unparseable |
| labels are per-kind | Labels are **global across kinds** — `entity channel` cannot coexist with `attribute channel` (`SVL2`) |
| a fun calling a not-yet-defined fun validates | Cross-fun references only resolve against **committed** functions (`REP4` on commit:false) — commit dependencies first, or define both in one tx. This is why `schema/factory.tql` is one file: a partial multi-file deploy produced prod's `[REP4] Could not resolve function with name 'gaps'` on 2026-07-29. |
| a fun body that type-checks in isolation deploys | **`FIN4` / `QUA2`** — "The types inferred for the return statement of function 'f' did not match those declared in the signature. Mismatching index: 0". The return type is checked against what the body actually binds, so `-> string` with a body binding an attribute concept fails. Fix the signature or bind a value with `let`. |
| reading an attribute off a variable the planner infers as a *union* of owner types | **`INF11`** — the union has no member that can own the attribute, and the **whole schema transaction is rejected** at function type-check. This is why the three `*-schema.tql` domain files are absent from prod (`schema/CLAUDE.md`). Constrain the variable's type before reading the attribute. |
| `return first true` (boolean literal) | **REJECTED — re-probed 2026-08-02 on 3.12.1, still rejected** (`[TQL0] syntax error: expected var`) — bind first: `let $ok = true; return first $ok;`. The live schema contains **zero** `return first <literal>`; every one of its nine distinct return-first forms returns a bound variable (`$ok`, `$stage`, `$status`, `$toxic`, …). The deployed existence-check idiom is `match <the predicate>; let $ok = true; return first $ok;` — see `route_exists`. |
| `put` with non-key attributes is idempotent | **CRASHES on keyed entities** (`COW5` duplicate-key) when any non-key attribute differs from the existing row — the whole pattern fails to match, put inserts a duplicate @key. Put by key only, then put each invariant attribute as its own stage: `put $m isa actor, has aid "X"; put $m has actor-type "agent";` Never put attributes that vary (e.g. `name`) |
| `delete $attr of $e;` removes an ownership | **REJECTED** (`REP1 Object vs ThingType`) — and `delete has $attr of $e;` parses but can't feed a computed re-insert. There is NO in-database increment on this build |
| computed values in writes: `insert $e has strength ($s + 1)` or `has strength $ns` (value var) | **REJECTED** (`REP1 Attribute vs Value`) — writes take LITERALS only. The increment pattern is read-then-write: read current values, compute in the caller, write back with `update $e has strength 7.0;` (update = replace-or-add on card 0..1, no delete needed). See substrate.ts readPathWeights/updatePathWeights |
| relation insert/match+update: `insert $r (role: $x) isa rel-type, has attr val;` (role-list before `isa`) | **INSERT: REJECTED** (`WCP4 Could not determine the type of the insert variable '_anonymous'`). **MATCH-then-UPDATE: REJECTED** (`REP1 variable cannot be declared as both Object/Thing and ThingType`) the moment that same match feeds an `update`/`delete` stage — a plain match+select with this shape is fine. Verified 2026-07-12 while shipping `path-context` writes (`substrate.ts` `upsertPathContext`, `fade()`, `follow()`). Fix: declare `isa` first, `links` second — `insert $r isa rel-type, links (role: $x), has attr val;` and `match $r isa rel-type, links (role: $x), has attr val; update $r has attr val2;` both work for insert, match, AND update. Only pure match+select tolerates the role-first shorthand; treat isa-first as the universal safe form. |
| re-asserting `isa <type>` on a variable whose type is already implied by a role constraint elsewhere in the same match (e.g. `$e isa path, links(...)` after `$pc isa path-context, links(followed: $e)` already implies `$e` is a `path` via the schema's `path plays path-context:followed`) | **NOT rejected, but silently forces a full unbound scan** of the re-asserted type before the join — on a relation with real production volume (e.g. `path`, thousands of rows) this reliably **times out** (`"The operation was aborted due to timeout"`) even though the equivalent query with the redundant `isa` dropped returns instantly. Verified 2026-07-12: `match $e isa path, links(source:$a,target:$b); $pc isa path-context, links(followed:$e), has context-tag $ct, has context-strength $cs; ...` timed out; `match $pc isa path-context, has context-tag $ct, has context-strength $cs, links(followed:$e); $e links(source:$a,target:$b); ...` (path-context first, no re-`isa` on `$e`) returned instantly with identical results. Rule: **start the match from the smallest/most-selective relation, and never re-declare a type TypeDB can already infer from a role constraint.** |
| joining `has <attr> $x` on BOTH role players of the same two-role relation in one match (e.g. `(container: $p, contained: $c) isa containment; $c has tid $id; $p has tid $parent;`) | **NOT rejected, but reliably TIMES OUT** (10s, `"The operation was aborted due to timeout"`) — even on relation types with single-digit row counts platform-wide (`containment`: 9 rows, `blocks`: 2 rows). Reproduced consistently regardless of `limit`, statement order, or dropping a redundant `isa thing` on the role players — this is a distinct defect from the row above (that one is about a *redundant* `isa`; this one triggers even with the minimal, non-redundant `has` shape). Verified 2026-07-16 in `one.ie/web/src/pages/api/things/index.ts` (task board's subtask-parent + blocked-by lookups) — the query had been silently swallowing this 10s hang via `.catch(() => [])` on every single page load. **Each half in isolation is fast** (`$c has tid $id;` alone: ~0.7s; `$p has tid $parent;` alone: ~1s) — it's specifically resolving an attribute on **both** sides in the same query that's poisonous. Fix: split into two queries — (1) `match (container: $p, contained: $c) isa containment; limit N; select $p, $c;` with NO attribute join at all (returns raw entity `iid`s, sub-second), then (2) batch-resolve every involved `iid` to its attribute in ONE disjunction query: `match { $x iid 0x1e...; } or { $x iid 0x1e...; }; $x has tid $id; select $x, $id;` (also sub-second, confirmed via `flattenAnswers` — an entity concept with no `value`/`label` flattens to its bare `iid` string, so `row['p']`/`row['c']` from step 1 are directly usable as iid literals in step 2, no re-quoting). |

Deploy path: `POST {TYPEDB_URL}/v1/signin` → `POST /v1/query` with `transactionType:"schema"`, validate `commit:false` first. Working deployer pattern: `one.ie/web/scripts/deploy-chat-schema.ts`.

### Transaction Pattern (No Sessions!)

```python
# CORRECT - Direct transaction on driver
with driver.transaction("database", TransactionType.READ) as tx:
    result = tx.query("match $p isa person; select $p;").resolve()
```

### Delete Syntax (CRITICAL!)

```typeql
# CORRECT: Delete the attribute itself
match $p isa person, has name $n;
delete $n;

# CORRECT: Delete ownership (keep attribute, remove from owner)
delete has $n of $p;
```

### Schema Declaration

```typeql
# Root type declaration
entity person;
relation friendship;
attribute name, value string;

# Subtype declaration (uses sub)
entity employee sub person;
```

---

## Schema Definition

### Entity Types

```typeql
define

# Basic entity
entity person;

# Entity with ownership
entity user,
    owns username @key,
    owns email @unique,
    owns age;

# Abstract entity (cannot be instantiated)
entity content @abstract;

# Entity with role playing
entity company,
    plays employment:employer,
    plays ownership:owner;

# Subtype inheritance
entity employee sub person,
    owns employee-id @key,
    plays employment:employee;
```

### Relation Types

```typeql
define

# Basic relation with roles
relation friendship,
    relates friend @card(2);  # Exactly 2 friends

# Relation with different roles
relation employment,
    relates employer @card(1),     # One employer
    relates employee @card(1..);   # One or more employees

# Relation with attributes
relation transaction,
    relates buyer,
    relates seller,
    owns amount,
    owns timestamp;

# Abstract relation
relation interaction @abstract,
    relates subject,
    relates content;

# Relation with role specialization
relation content-engagement sub interaction,
    relates author as subject;  # 'author' specializes 'subject'
```

### Attribute Types

```typeql
define

# Basic attributes with value types
attribute name, value string;
attribute age, value integer;          # NOT 'long'
attribute score, value double;         # NOT 'float'
attribute balance, value decimal;
attribute active, value boolean;
attribute birth-date, value date;
attribute created-at, value datetime;
attribute created-with-tz, value datetime-tz;
attribute duration, value duration;

# Attribute with regex constraint
attribute email, value string @regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$");

# Attribute with value constraint
attribute status, value string @values("pending", "active", "completed", "cancelled");

# Attribute with range constraint
attribute percentage, value double @range(0.0..100.0);

# Independent attribute (survives without owner)
attribute log-entry, value string @independent;

# Attribute subtype
attribute full-name sub name;
```

### Ownership Declarations

```typeql
define

entity person,
    owns name @card(1..3),      # 1 to 3 names
    owns email @key,            # Unique identifier
    owns phone @unique,         # Unique but optional
    owns nickname @card(0..);   # Any number

# Ownership with ordering
entity playlist,
    owns song @card(0..) @distinct;  # Unique songs only
```

### Complete Schema Example

```typeql
define

# Attributes
attribute id, value string;
attribute name, value string;
attribute email, value string @regex("^.*@.*\\..*$");
attribute age, value integer @range(0..150);
attribute balance, value decimal;
attribute timestamp, value datetime-tz;
attribute status, value string @values("active", "inactive", "pending");

# Entities
entity person @abstract,
    owns id @key,
    owns name @card(1),
    owns email @unique,
    owns age;

entity user sub person,
    owns balance,
    plays friendship:friend,
    plays employment:employee;

entity company,
    owns id @key,
    owns name,
    plays employment:employer;

# Relations
relation friendship,
    relates friend @card(2);

relation employment,
    relates employer @card(1),
    relates employee @card(1..),
    owns timestamp,
    owns status;
```

### Undefine (Remove Schema Elements)

```typeql
# Remove a type
undefine user;

# Remove ownership from a type
undefine owns email from user;

# Remove role playing from a type
undefine plays friendship:friend from user;

# Remove a role from a relation
undefine relates employee from employment;

# Remove an annotation
undefine @unique from user owns email;

# Remove a function
undefine fun calculate_score;
```

### Redefine (Modify Schema Elements)

```typeql
# Redefine type hierarchy (one change per query)
redefine user sub page;

# Redefine attribute value type
redefine karma value integer;

# Redefine annotation
redefine email value string @regex("^.*@typedb\\.com$");

# Redefine role specialization
redefine fathership relates father as parent;
```

---

## Data Pipelines

TypeQL queries are **pipelines** of stages. Each stage accepts a stream of answers and outputs a stream.

### Pipeline Categories

- **Write Pipelines**: Contain insert, delete, update, or put stages
- **Read Pipelines**: Only retrieve data (match, fetch, select)

### Pipeline Stages

| Stage | Purpose | Transaction Type |
|-------|---------|------------------|
| `match` | Find existing data | READ, WRITE, SCHEMA |
| `insert` | Create new data | WRITE |
| `delete` | Remove data | WRITE |
| `update` | Modify single-cardinality data | WRITE |
| `put` | Insert if not exists | WRITE |
| `fetch` | Format output as JSON | READ |
| `select` | Keep specified variables | READ |
| `reduce` | Aggregate results | READ |
| `sort` | Order results | READ |
| `limit` | Restrict result count | READ |
| `offset` | Skip initial results | READ |
| `distinct` | Remove duplicates | READ |
| `require` | Filter elements with variables | READ |
| `with` | Define ad-hoc functions | READ |

---

## Query Operations

### Match (Read Data)

```typeql
# Basic match
match $u isa user;
select $u;

# Match with attributes
match
    $u isa user,
        has name $n,
        has age $a;
select $u, $n, $a;

# Match with conditions
match
    $u isa user, has age $a;
    $a >= 18;
select $u;

# Match relations
match
    $f isa friendship,
        links (friend: $u1, friend: $u2);
    $u1 has name "Alice";
select $u2;

# Match with negation
match
    $u isa user;
    not { $u has status "inactive"; };
select $u;

# Match with disjunction (OR)
match
    $u isa user;
    { $u has status "active"; } or { $u has status "pending"; };
select $u;

# Match with optional
match
    $u isa user, has name $n;
    try { $u has email $e; };  # Optional email
select $n, $e;
```

### Insert (Create Data)

```typeql
# Insert entity with attributes
insert $u isa user,
    has id "user-001",
    has name "Alice",
    has age 30;

# Insert multiple entities
insert
    $u1 isa user, has id "u1", has name "Alice";
    $u2 isa user, has id "u2", has name "Bob";

# Match-Insert (create based on existing data)
match
    $u1 isa user, has name "Alice";
    $u2 isa user, has name "Bob";
insert
    $f isa friendship, links (friend: $u1, friend: $u2);

# Insert relation with attributes
insert
    $e isa employment,
        links (employer: $company, employee: $person),
        has timestamp 2025-01-15T10:00:00,
        has status "active";
```

### Delete (Remove Data)

```typeql
# Delete an entity (cascades to relations and owned attributes)
match $u isa user, has id "user-001";
delete $u;

# Delete an attribute (the attribute value itself)
match
    $u isa user, has id "user-001";
    $u has email $e;
delete $e;

# Delete ownership (keep attribute, remove from owner)
match
    $u isa user, has id "user-001";
    $u has nickname $n;
delete has $n of $u;

# Delete role player from relation
match
    $f isa friendship, links (friend: $u);
    $u has id "user-001";
delete links (friend: $u) of $f;

# Delete relation
match $f isa friendship;
delete $f;
```

### Update (Modify Single-Cardinality Data)

```typeql
# Update works ONLY for @card(0..1) or @card(1)
match $u isa user, has id "user-001";
update $u has status "inactive";

# Update replaces the value or adds if none exists
match $u isa user, has name "Alice";
update $u has age 31;
```

### Put (Upsert - Insert if Not Exists)

```typeql
# Put entire pattern
put $u isa user, has id "user-001", has name "Alice";

# Put is all-or-nothing
# If ANY part doesn't match, entire pattern is inserted
put
    $u isa user, has id "user-001";
    $u has status "active";
```

### Select (Project Variables)

```typeql
# Select specific variables
match $u isa user, has name $n, has age $a;
select $n, $a;

# Select with expressions
match
    $u isa user, has age $a;
    let $next_year = $a + 1;
select $u, $next_year;
```

### Fetch (JSON Output)

```typeql
# Basic fetch
match $u isa user;
fetch {
    "name": $u.name,
    "email": $u.email
};

# Fetch with subquery
match $u isa user;
fetch {
    "user": $u.name,
    "friends": [
        match ($u, $friend) isa friendship;
        fetch { "friend_name": $friend.name };
    ]
};

# Fetch all attributes
match $u isa user;
fetch {
    "user_data": { $u.* }
};
```

### Reduce (Aggregations)

```typeql
# Count
match $u isa user;
reduce $count = count;

# Multiple aggregations
match $u isa user, has age $a;
reduce
    $count = count,
    $avg_age = mean($a),
    $max_age = max($a),
    $min_age = min($a),
    $total_age = sum($a);

# Group by
match
    $u isa user, has status $s, has age $a;
reduce $count = count, $avg = mean($a) groupby $s;

# Available aggregation functions:
# count, sum, mean, median, min, max, std, list
```

### Sort, Limit, Offset

```typeql
# Sort ascending (default)
match $u isa user, has age $a;
select $u, $a;
sort $a;

# Sort descending
match $u isa user, has score $s;
select $u, $s;
sort $s desc;

# Multiple sort keys
match $u isa user, has name $n, has age $a;
select $n, $a;
sort $a desc, $n asc;

# Pagination
match $u isa user;
select $u;
sort $u;
offset 20;
limit 10;
```

### Distinct

```typeql
# Remove duplicate results
match
    $f isa friendship, links (friend: $u);
select $u;
distinct;
```

---

## Functions

Functions replace rules from TypeDB 2.x. They are **read-only** query abstractions.

### Function Syntax

```typeql
define

# Scalar function (returns single value)
fun user_age($user: user) -> integer:
    match $user has age $a;
    return first $a;

# Stream function (returns multiple values)
fun user_friends($user: user) -> { user }:
    match ($user, $friend) isa friendship;
    return { $friend };

# Tuple function (returns multiple values per row)
fun user_info($user: user) -> string, integer:
    match $user has name $n, has age $a;
    return first $n, $a;

# Aggregation function
fun friend_count($user: user) -> integer:
    match ($user, $friend) isa friendship;
    return count($friend);

# Recursive function (transitive closure).
# `node` is a DEAD NAME in this repo — use the real domain type.
fun reachable($from: city) -> { city }:
    match
        { $_ isa flight, links (from: $from, to: $to); }
        or {
            let $mid in reachable($from);
            $_ isa flight, links (from: $mid, to: $to);
        };
    return { $to };
```

### Using Functions in Queries

```typeql
# Using scalar function
match
    $u isa user;
    let $age = user_age($u);
    $age > 18;
select $u;

# Using stream function
match
    $u isa user, has name "Alice";
    let $friend in user_friends($u);
select $friend;

# Using tuple function
match
    $u isa user;
    let $name, $age = user_info($u);
select $name, $age;
```

### Ad-hoc Functions with `with`

```typeql
with
    fun is_adult($u: user) -> boolean:
        match $u has age $a; $a >= 18;
        let $ok = true;              # bind — `return first true` is a TQL0 syntax error
        return first $ok;
match
    $u isa user;
    let $adult = is_adult($u);
    $adult == true;
select $u;
```

A `with fun` block runs inside a plain **read** transaction, which makes it the
cheapest way to test function syntax against a live server without opening a
schema transaction. Every re-probe in the VERIFIED table above was done this way.

Each ad-hoc function needs **its own `with`** — `with fun a(…): …; fun b(…): …;`
is a parse error (`expected query_pipeline or WITH`). Write
`with fun a(…): …; with fun b(…): …; match …` and `b` may call `a`.

---

## Inference Rules (Emergence Patterns)

**There are no rules in TypeDB 3.x.** The `rule <name>: when { … } then { … };`
construct was removed with the 2.x line, and the live 3.12.1 schema dump contains
zero of them. Everything this section used to show as a rule is written as a
`fun` today. The translation is mechanical and lossy in exactly one place:

| 2.x rule | 3.x function |
|---|---|
| `when { … }` | the `match` body |
| `then { $e has tier "elite"; }` | a `let $tier = "elite";` binding + `return first $tier` |
| fires automatically, writes derived facts into the graph | evaluated **on call**; derives nothing until something calls it |
| chained rules (rule B reads rule A's output) | function composition — B calls A, or (faster) B inlines A's body |
| rule firing order / priority | the top-down order of the disjunction branches, visible in the source |
| `?val = $a / $b` value variables | `let $val = $a / $b;` — all variables use `$` |

The loss is the automatic part: a rule *materialised* derived facts, a function
*computes* them per query. Nothing in the graph changes until a caller asks.

### Basic classification

The 2.x "elite pattern" rule becomes a classifier that returns the tier. Note the
shape: **an exhaustive disjunction, each branch binding the same `let`, closed by
`return first $var`.** There is no `if/then/else` expression in TypeQL — see the
VERIFIED table.

```typeql
define

fun edge_tier($e: path) -> string:
    match
        $e has strength $s, has resistance $r, has traversals $t;
        { $s >= 70.0; $t >= 50;
          let $tier = "elite"; }
        or { $r >= 25.0; not { $s >= 70.0; $t >= 50; };
          let $tier = "danger"; }
        or { not { $s >= 70.0; $t >= 50; };
             not { $r >= 25.0; };
             let $tier = "active"; };
    return first $tier;
```

Every branch after the first must **negate the earlier branches' conditions**.
A disjunction is not a cascade: without the `not { … }` guards, a path matching
two branches yields two rows and `return first` picks an arbitrary one. This is
the single most common bug when porting a chained rule set. `path_status` in
`schema/reason.tql:63` is the deployed five-branch example — read it before
writing your own.

### Chained rules become composition

A rule that read another rule's derived fact becomes a function that calls it:

```typeql
define

fun hardening_ready($e: path) -> boolean:
    match
        $e has traversals $t, has strength $s;
        $t >= 100; $s >= 80.0;
        let $tier = edge_tier($e);
        $tier == "elite";
        let $ok = true;
    return first $ok;
```

For anything hot, **inline the body instead of calling** — a call is an
optimisation barrier, and the deployed `preflight` inlines its three pre-checks
rather than calling `can_receive`/`is_safe`/`within_budget` for exactly this
reason.

### Disjunction over a single value

```typeql
define

fun path_pressure($p: path) -> string:
    match
        $p has resistance $r;
        { $r > 25.0;  let $sev = "high"; }
        or { $r <= 25.0; let $sev = "normal"; };
    return first $sev;
```

### Computed values

`?acc = $cp / $tp` becomes `let $acc = $cp / $tp;`. The result is returned, not
written back to the instance — **a function cannot write.**

```typeql
define

fun delivery_rate($p: path) -> double:
    match
        $p has attempts $a, has deliveries $d;
        $a >= 20;
        let $rate = $d / $a;
    return first $rate;
```

### Querying derived values

In 2.x you matched the materialised fact. In 3.x you call the function and
compare its result:

```typeql
# 2.x: match $e isa signal-edge, has tier "elite";   <- the fact was written
# 3.x: the tier is computed at query time
match
    $e isa path;
    let $tier = edge_tier($e);
    $tier == "elite";
select $e;
```

**If you need the derived value to persist** — because you want to index it,
sort a large set by it, or hand it to a non-TypeQL consumer — compute it in the
caller and write it back with `update`. The substrate does this for path weights
(`readPathWeights` / `updatePathWeights` in `one.ie/web/src/lib/substrate.ts`),
because there is no in-database increment on this build (VERIFIED table).

---

## Patterns

### Conjunctions (AND)

```typeql
# Statements separated by semicolons form conjunctions
match
    $u isa user;
    $u has name "Alice";
    $u has age $a;
    $a > 18;
select $u;
```

### Disjunctions (OR)

```typeql
match
    $u isa user;
    { $u has status "active"; } or { $u has status "pending"; };
select $u;

# Multiple branches
match
    $u isa user;
    { $u has role "admin"; }
    or { $u has role "moderator"; }
    or { $u has role "editor"; };
select $u;
```

### Negations (NOT)

```typeql
match
    $u isa user;
    not { $u has status "deleted"; };
select $u;

# Negation with relations
match
    $u isa user;
    not { ($u) isa ban; };
select $u;
```

### Optionals (TRY)

```typeql
# Optional attribute
match
    $u isa user, has name $n;
    try { $u has email $e; };
select $n, $e;  # $e may be null

# Optional relation
match
    $u isa user;
    try { ($u, $manager) isa management; };
select $u, $manager;
```

### Variable Scope

- Variables have scope within their block `{ ... }` or the entire pattern
- Variables in ALL branches of a disjunction are in parent scope
- Variables in negations are scoped to the negation block

---

## Annotations

### Cardinality Annotations

```typeql
# Exact count
relates friend @card(2);        # Exactly 2

# Range
owns email @card(0..1);         # 0 or 1
owns phone @card(1..);          # 1 or more
owns nickname @card(0..);       # Any number (default for owns)

# Unlimited
plays role @card(0..);          # Default for plays
```

### Uniqueness Annotations

```typeql
# @key: Every owner has exactly one, unique across all owners
owns username @key;

# @unique: Unique across owners, but optional
owns email @unique;

# @subkey: Composite key from multiple attributes
owns first_name @subkey("full_name");
owns last_name @subkey("full_name");
```

### Value Constraint Annotations

```typeql
# @values: Enumerated values
attribute status, value string @values("active", "inactive", "pending");

# @range: Numeric/date range
attribute age, value integer @range(0..150);
attribute score, value double @range(0.0..100.0);

# @regex: String pattern
attribute email, value string @regex("^[^@]+@[^@]+\\.[^@]+$");

# @distinct: Unique values in owned list
owns tag @card(0..) @distinct;
```

### Behavioral Annotations

```typeql
# @abstract: Cannot be instantiated
entity content @abstract;

# @independent: Attribute survives without owners
attribute log_entry, value string @independent;

# @cascade: Delete behavior for relations
relation ownership,
    relates owner @cascade,      # Delete relation when owner deleted
    relates owned;
```

---

## Value Types

| Type | Description | Example |
|------|-------------|---------|
| `boolean` | true/false | `true`, `false` |
| `integer` | 64-bit signed | `42`, `-100` |
| `double` | IEEE 754 double | `3.14`, `1e-10` |
| `decimal` | Fixed-point | `123.456` |
| `string` | UTF-8 text | `"Hello"` |
| `date` | ISO 8601 date | `2025-01-15` |
| `datetime` | Date + time | `2025-01-15T10:30:00` |
| `datetime-tz` | With timezone | `2025-01-15T10:30:00+08:00` |
| `duration` | ISO 8601 duration | `P1Y2M3DT4H5M6S` |

### Value Literals in Queries

```typeql
insert $u isa user,
    has active true,
    has age 30,
    has score 95.5,
    has balance 1234.56,
    has name "Alice",
    has birth_date 1994-05-15,
    has created_at 2025-01-15T10:30:00,
    has created_with_tz 2025-01-15T10:30:00+08:00;
```

---

## Python Driver

### Installation

```bash
pip install typedb-driver
```

### Connection

```python
from typedb.driver import TypeDB, Credentials, DriverOptions, TransactionType

# Community Edition (no auth, no TLS)
driver = TypeDB.driver("localhost:1729")

# TypeDB Cloud / Enterprise
credentials = Credentials("username", "password")
options = DriverOptions(
    is_tls_enabled=True,
    tls_root_ca_path="/path/to/ca.pem"  # Optional for custom CA
)
driver = TypeDB.driver(
    "https://cluster.typedb.com:80",
    credentials,
    options
)

# Context manager recommended
with TypeDB.driver(address, credentials, options) as driver:
    # Operations here
    pass
```

### Database Management

```python
# List databases
databases = driver.databases.all()

# Check if exists
exists = driver.databases.contains("my-database")

# Create database
driver.databases.create("my-database")

# Get database
db = driver.databases.get("my-database")

# Delete database
db.delete()

# Get schema
schema_str = db.schema()
```

### Transaction Types

```python
from typedb.driver import TransactionType

# READ: Read-only queries, concurrent
TransactionType.READ

# WRITE: Data modifications (insert, delete, update, put)
TransactionType.WRITE

# SCHEMA: Schema modifications (define, undefine, redefine)
TransactionType.SCHEMA
```

### Query Execution

```python
# Read transaction
with driver.transaction("my-database", TransactionType.READ) as tx:
    # Execute query
    promise = tx.query("match $u isa user; select $u; limit 10;")
    result = promise.resolve()

    # Process results
    for row in result.as_concept_rows():
        user = row.get("u")
        print(f"User: {user.get_iid()}")

        # Get attributes
        if user.is_entity():
            entity = user.as_entity()
            # Access via subsequent queries

# Write transaction
with driver.transaction("my-database", TransactionType.WRITE) as tx:
    tx.query('insert $u isa user, has name "Alice";').resolve()
    tx.commit()  # MUST commit!

# Schema transaction
with driver.transaction("my-database", TransactionType.SCHEMA) as tx:
    tx.query("define entity new_type;").resolve()
    tx.commit()
```

### Result Processing

```python
# Concept Rows (for select queries)
result = tx.query("match $u isa user, has name $n; select $u, $n;").resolve()
for row in result.as_concept_rows():
    user = row.get("u")           # Get by variable name
    name = row.get("n")

    # Type checking
    if user.is_entity():
        entity = user.as_entity()
        iid = entity.get_iid()

    if name.is_attribute():
        attr = name.as_attribute()
        value = attr.get_string()  # or get_integer(), get_double(), etc.

# Concept Documents (for fetch queries)
result = tx.query("""
    match $u isa user;
    fetch { "name": $u.name, "age": $u.age };
""").resolve()
for doc in result.as_concept_documents():
    print(doc["name"])
    print(doc["age"])

# Schema queries (define/undefine/redefine)
result = tx.query("define entity new_entity;").resolve()
if result.is_ok():
    print("Schema updated successfully")
```

### Type Checking and Casting

```python
# Type checks
concept.is_entity()
concept.is_relation()
concept.is_attribute()
concept.is_entity_type()
concept.is_relation_type()
concept.is_attribute_type()
concept.is_type()
concept.is_instance()
concept.is_value()

# Type casting
entity = concept.as_entity()
relation = concept.as_relation()
attribute = concept.as_attribute()

# Value extraction
attr.get_string()
attr.get_integer()
attr.get_double()
attr.get_decimal()
attr.get_boolean()
attr.get_date()
attr.get_datetime()
attr.get_datetime_tz()
attr.get_duration()

# Safe extraction (returns None if wrong type)
attr.try_get_string()
attr.try_get_integer()
```

### Transaction Options

```python
from typedb.driver import TransactionOptions

# Set transaction timeout (default 5 minutes)
options = TransactionOptions(transaction_timeout_millis=120_000)  # 2 minutes

# Set schema lock timeout (default 30 seconds)
options = TransactionOptions(schema_lock_acquire_timeout_millis=60_000)

with driver.transaction("db", TransactionType.WRITE, options=options) as tx:
    # ...
```

### Error Handling

```python
from typedb.driver import TypeDBDriverException

try:
    with driver.transaction("db", TransactionType.WRITE) as tx:
        tx.query("insert $u isa user, has name 'Alice';").resolve()
        tx.commit()
except TypeDBDriverException as e:
    if "QEX" in str(e).upper():
        print("Query execution error")
    elif "TQL" in str(e).upper():
        print("TypeQL parsing error")
    else:
        print(f"Driver error: {e}")
```

### Batch Operations

```python
# Batch insert with concurrent promises
with driver.transaction("db", TransactionType.WRITE) as tx:
    promises = []
    for item in items:
        query = f"insert $x isa item, has name '{item}';"
        promises.append(tx.query(query))

    # Resolve all
    for p in promises:
        p.resolve()

    tx.commit()

# Chunked batch processing
def insert_batch(driver, items, chunk_size=100):
    for i in range(0, len(items), chunk_size):
        chunk = items[i:i + chunk_size]
        with driver.transaction("db", TransactionType.WRITE) as tx:
            for item in chunk:
                tx.query(f"insert $x isa item, has name '{item}';").resolve()
            tx.commit()
```

---

## Transaction Management

### Transaction Characteristics

| Type | Reads | Data Writes | Schema Writes | Concurrency |
|------|-------|-------------|---------------|-------------|
| READ | Yes | No | No | Fully concurrent |
| WRITE | Yes | Yes | No | May conflict on commit |
| SCHEMA | Yes | Yes | Yes | Exclusive (blocks writes) |

### Snapshot Isolation

- Transactions operate on snapshots taken at open time
- Changes visible within transaction, not to others until commit
- ACID guarantees up to snapshot isolation

### Commit Behavior

```python
# Write transactions MUST commit
with driver.transaction("db", TransactionType.WRITE) as tx:
    tx.query("insert ...").resolve()
    tx.commit()  # Required!

# Read transactions auto-close, no commit needed
with driver.transaction("db", TransactionType.READ) as tx:
    result = tx.query("match ...").resolve()
    # Auto-closes when exiting context

# Explicit rollback
with driver.transaction("db", TransactionType.WRITE) as tx:
    try:
        tx.query("insert ...").resolve()
        if something_wrong:
            tx.rollback()  # Discard changes
            return
        tx.commit()
    except:
        # Transaction auto-rollbacks on exception
        raise
```

### Conflict Handling

```python
import time
import random

def write_with_retry(driver, query, max_retries=3):
    for attempt in range(max_retries):
        try:
            with driver.transaction("db", TransactionType.WRITE) as tx:
                tx.query(query).resolve()
                tx.commit()
                return True
        except TypeDBDriverException as e:
            if "conflict" in str(e).lower() and attempt < max_retries - 1:
                wait_time = 0.1 * (2 ** attempt) + random.uniform(0, 0.1)
                time.sleep(wait_time)
                continue
            raise
    return False
```

---

## The door: what changes because you go through a gateway

Everything above this line is TypeQL — true of any TypeDB. This section is true
only *here*, and it is the part that costs days. **No code in this monorepo talks
to TypeDB. It talks to a gateway that talks to TypeDB** (`one.ie/web/src/lib/
substrate.ts` → `api/src/index.ts` → `POST {TYPEDB_URL}/v1/query`). Every rule
below is a property of that door, not of the language.

### The row cap: `limit` is a request, 10000 is the answer

`GATEWAY_ROW_CAP` (`substrate.ts:54`) is **10000**, and the gateway returns at most
that many rows whatever your TypeQL says. Measured 2026-09-15 against api.one.ie,
same query, only the limit changed: 9000 → 9000, 10000 → 10000, 12000 → 10000,
20000 → 10000, 50000 → 10000.

Two rules follow, and the second is the one that cost a day (`substrate.ts:40-53`):

1. **A `limit` above the cap buys nothing.** It is not a bigger budget, it is decoration.
2. **A truncation check of the form `rows.length >= MY_LIMIT` is BLIND** whenever
   `MY_LIMIT` exceeds the cap, because the length can never reach it. Compare
   against `effectiveRowLimit(myLimit)` (`substrate.ts:57`) or the check silently
   always says "clean".

What rule 2 actually did, in the repo's own words: `readTasksNarrow` asked for
20000 and `tasks:board` asks for 100000, and **both of their truncation flags were
unreachable**. The tag branch was being cut at 10000 of 10034 rows; TypeDB
truncates at the **tail**, so the NEWEST tasks came back with `tags: []` — and a
task with no `workspace:` tag reads as belonging to the PLATFORM workspace and is
hidden from its own owner behind a cheerful `{ok:true, truncated:false, tasks:[]}`.

**`reduce` is not row-capped, and is therefore the only honest way to size a read
through this door.** The same query that returned 10000 rows answered `10034` under
`reduce $n = count`. Size first, then decide whether you can page it.

```typeql
# Sizing a read — NOT capped
match $t isa thing, has thing-type "task";
reduce $n = count;
```

Never hardcode the number: import `GATEWAY_ROW_CAP` / `effectiveRowLimit`. It lives
on the door for exactly one reason — this is the second receiver it blinded, and a
third copy of the number is how the first two drifted.

### Do not query on the request path

`../CLAUDE.md § The brain and the edge` is the standing rule: TypeDB is the brain of
record and it is in Virginia, so a receiver reads the **snapshot** (KV / BrainDO JSON),
and TypeDB takes writes and the sync. A live query from Thailand is **1.2–1.6 s**; the
same answer from the isolate memo is **26–58 ms**.

This is not advice about speed. `bash .claude/scripts/signal-watch.sh` reads a
receiver that reaches for the brain as **red**, and `one.ie/web/scripts/edge-read-ratchet.mjs`
gates it in three directions — a per-file ceiling, a collapse check (a snapshot read may
not answer `[]` on failure), and a **floor** for `mustStayLive` files whose reads GUARD
writes and must stay live (`membership.ts` counts a group's owners before a demotion; on
a 30s-stale snapshot two concurrent demotions both read "two owners" and leave none).

Why it matters when you are writing TypeQL: a query you add to a resolver is a
ratchet rise. Write it against the snapshot, or put it behind a memo the way
`src/lib/tasks/board.ts` does — the repo calls that one "the one to copy".

### The timeout, the breaker, and why a valid query returns 500

| what | value | where |
|---|---|---|
| gateway per-request bound | **10 s** | `TYPEDB_TIMEOUT_MS`, `api/src/index.ts:26` |
| breaker opens after | **5 failures in 10 s** | `threshold` / `windowMs`, `api/src/security.ts:37-38` |
| breaker stays open | **30 s** | `cooldownMs`, `api/src/security.ts:39` |

A 500 carrying `The operation was aborted due to timeout` is the gateway's own 10 s
bound, not a bad query. Measured the same day against production, a keyed point lookup
or a one-row insert answered in **0.32–0.34 s** every time, while a `like`-regex scan
hit the bound cold (0.4–0.6 s warm). **The cluster has slow windows; a correct query
meets them.**

Two consequences worth designing around:

- **A retry loop is a load generator.** Five 5xx in ten seconds opens the breaker for
  thirty, and a poll cadence tighter than the cooldown can never recover inside its own
  budget. Poll while the substrate is *answering*; stop adding load the moment it refuses.
- **Prefer a keyed point lookup to a scan.** `like`-regex over a growing corpus is the
  shape that finds the bound first.

### Writes: `NO_WRITE_RETRY`, and idempotency by observation

`RETRYABLE` includes 500, but `NO_WRITE_RETRY = {404, 500}` (`substrate.ts:101`) refuses
to retry a **write** on 500 — because a timed-out write may already have COMMITTED, and a
blind second attempt inserts it twice. That rule is right and production code must not
work around it.

A **fixture** may do what production may not, because it knows exactly which row it
creates: it can LOOK before it retries. Pass a `landed` read — a point lookup for what the
write creates — and after an infra failure ask the substrate whether the write landed
anyway. Landed → done. Not landed → wait and write again. That is idempotency by
observation, not by assumption. `one.ie/web/tests/helpers/real-typedb-fixtures.ts` is the
implementation; `mustWrite` is the entry point.

It also covers the leftover race: if the first attempt committed but was not yet readable,
the retry of a keyed insert (`tid`/`aid`/`gid` are all `@key`) is refused as a key
violation, and the `landed` re-check after ANY refusal then finds the row.

### Read-after-write is not consistent

A committed plain insert took **516 ms to become readable** on an IDLE cluster (measured
2026-08-02). Anything that writes and then asserts must wait for visibility, not assume
it — `waitVisible` in `tests/helpers/probe-sweep.ts`. A test that claims and then reads
without waiting races the substrate and gets a *correct* `not_found`.

### Two concurrency defects that read as bad TypeQL

Both are real, both look like your query is wrong, and neither is:

- **Concurrent transactions racing to create the same attribute.** Two inserts that each
  introduce the same new attribute value (`member-role "member"`) race, and the loser is
  rejected with a **400 on a valid insert**. The fix is shape, not retry: **one transaction
  per group that shares a new attribute or entity** — never `Promise.all` over them.
- **`CNT5` card violation on a `put`.** A `put` of an actor as `actor-type "agent"` collides
  with an actor already carrying `actor-type "human"` on a `@card(0..1)` attribute. Seen
  where a helper auto-creates a twin for an actor a test had already made by hand; the fix
  is to leave the auto-created one uncreated rather than to loosen the card.

### Coming with `tql-edge`: a `fun` will be read by two engines

**Not in force yet — C2 and C3 of `text/tql-edge-todo.md` are unstarted and the solver does
not exist.** Written here because it changes how a `fun` should be designed from now on, and
because discovering it at codegen is worse than reading it here.

Today a `fun` is executed only by TypeDB. After `tql-edge`, `schema/codegen/parse.ts` will
emit each fun's body as a `Stmt[]` pattern and a pure solver will execute the same pattern
over JSON in RAM at the edge — so a fun becomes the **single** definition of a rule, run by
two engines. The census of all 317 funs (`text/tql-edge-plan.md § What TypeQL maps to`) found
twelve constructs cover every one of them, and that **`fetch`, `try`, `isa!`, `sub` and `iid`
are at zero uses**. The plan's contract is that a fun introducing one of those will fail
codegen by name rather than silently dropping out of the edge.

The practical read for anyone writing a `fun` before that lands: stay inside what the 317
already use — `isa` / `has` / role patterns, comparisons, `let` value and stream calls,
`or`, `not`, arithmetic, `sort` / `limit` / `offset`, `contains`, `is`, `reduce
count|sum|max`. A fun written that way needs no migration. One that reaches for `fetch` will.

The second-order reason to care: the funs are also the **manifest of what RAM must hold** —
they reach at least 22 of 63 entities and 158 of 717 attributes, so four fifths of the
attribute surface is never read by any question the substrate can be asked. `text/ram-docs.md`
is why, and `can` reaching three attributes is the number that makes it concrete.

---

## Best Practices

### Connection Management

```python
# DO: Use context managers
with TypeDB.driver(address, credentials, options) as driver:
    with driver.transaction("db", TransactionType.READ) as tx:
        # ...

# DO: Reuse single driver instance
class DatabaseClient:
    def __init__(self):
        self.driver = TypeDB.driver(address, credentials, options)

    def close(self):
        self.driver.close()

# DON'T: Create new drivers per query
def bad_query():
    driver = TypeDB.driver(...)  # Expensive!
    # ...
    driver.close()
```

### Query Patterns

```python
# DO: Batch operations
with driver.transaction("db", TransactionType.WRITE) as tx:
    for item in items:
        tx.query(f"insert $x isa item, has name '{item}';")
    tx.commit()

# DON'T: One transaction per insert
for item in items:
    with driver.transaction("db", TransactionType.WRITE) as tx:
        tx.query(f"insert $x isa item, has name '{item}';").resolve()
        tx.commit()  # Too many commits!
```

### Security

```python
# DO: Use environment variables for credentials
import os
credentials = Credentials("admin", os.environ["TYPEDB_PASSWORD"])

# DO: Enable TLS in production
options = DriverOptions(is_tls_enabled=True)

# DON'T: Hardcode credentials
credentials = Credentials("admin", "password123")  # Bad!
```

---

## Query Optimization

### Predicate Pushdown

```typeql
# FAST: Constraints in single match stage
match
    $u isa user;
    $u has username "john_1";
select $u;

# SLOW: Constraints across stages
match $u isa user;
match $u has username "john_1";  # Large intermediate result!
select $u;
```

### Type Specificity

```typeql
# FAST: Use specific type
match $s isa scout, has fitness $f;
select $s, $f;

# SLOW: Generic type with late filtering
match
    $a isa ant, has fitness $f;  # Scans all ants
    $a isa scout;  # Late type restriction
select $a, $f;
```

### Avoid Cartesian Products

```typeql
# BAD: N x M combinations
match
    $a isa agent;
    $b isa agent;
select $a, $b;

# GOOD: Connected through relation
match
    $a isa agent;
    $b isa agent;
    (parent: $a, child: $b) isa reproduction;
select $a, $b;
```

### Use Limits for Exploration

```typeql
# GOOD: Limit exploratory queries
match $u isa user;
select $u;
limit 10;

# BAD: No limit on large datasets
match $u isa user;
select $u;  # Could return millions
```

### Batch Inserts

```typeql
# GOOD: Single transaction
insert
    $a1 isa agent, has id "a1";
    $a2 isa agent, has id "a2";
    $a3 isa agent, has id "a3";

# BAD: Multiple transactions
insert $a1 isa agent, has id "a1";
-- commit --
insert $a2 isa agent, has id "a2";
-- commit --
```

### Existence Checks

```typeql
# Efficient existence check
match $x isa user, has email "test@example.com";
reduce $exists = count;
-- Check if $exists > 0

# Or with early exit
match $x isa user, has email "test@example.com";
limit 1;
```

---

## Complete Keyword Reference

### Schema Keywords

| Keyword | Purpose | Example |
|---------|---------|---------|
| `define` | Begin schema definition | `define entity user;` |
| `undefine` | Remove schema element | `undefine user;` |
| `redefine` | Modify schema element | `redefine user sub page;` |
| `entity` | Define entity type | `entity person;` |
| `relation` | Define relation type | `relation friendship;` |
| `attribute` | Define attribute type | `attribute name, value string;` |
| `struct` | Define struct type | `struct address;` |
| `sub` | Define subtype | `entity employee sub person;` |
| `relates` | Define relation role | `relates friend;` |
| `plays` | Type plays role | `plays friendship:friend;` |
| `owns` | Type owns attribute | `owns name;` |
| `value` | Attribute value type | `value string;` |
| `as` | Role specialization | `relates author as subject;` |
| `fun` | Define function | `fun name() -> type:` |

### Data Pipeline Keywords

| Keyword | Purpose | Example |
|---------|---------|---------|
| `match` | Find existing data | `match $u isa user;` |
| `insert` | Create data | `insert $u isa user;` |
| `delete` | Remove data | `delete $u;` |
| `update` | Modify data | `update $u has age 31;` |
| `put` | Insert if not exists | `put $u isa user;` |
| `fetch` | JSON output | `fetch { "name": $u.name };` |
| `select` | Project variables | `select $u, $n;` |
| `reduce` | Aggregate | `reduce $count = count;` |
| `sort` | Order results | `sort $a desc;` |
| `limit` | Restrict count | `limit 10;` |
| `offset` | Skip results | `offset 20;` |
| `distinct` | Remove duplicates | `distinct;` |
| `require` | Filter nulls | `require $optional;` |
| `with` | Ad-hoc functions | `with fun f() -> ...` |

### Pattern Keywords

| Keyword | Purpose | Example |
|---------|---------|---------|
| `or` | Disjunction | `{ ... } or { ... };` |
| `not` | Negation | `not { $u has status "deleted"; };` |
| `try` | Optional | `try { $u has email $e; };` |
| `isa` | Type constraint | `$u isa user;` |
| `has` | Attribute ownership | `$u has name "Alice";` |
| `links` | Relation role | `links (friend: $u);` |
| `is` | Variable equality | `$a is $b;` |
| `let` | Assign expression | `let $x = $a + $b;` |
| `in` | Iterate stream | `let $x in function();` |
| `contains` | Substring match | `$s contains "test";` |
| `like` | Regex match | `$s like "^test.*";` |

### Aggregation Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `count` | Count items | `reduce $c = count;` |
| `sum` | Sum values | `reduce $s = sum($val);` |
| `mean` | Average | `reduce $avg = mean($val);` |
| `median` | Median | `reduce $med = median($val);` |
| `min` | Minimum | `reduce $min = min($val);` |
| `max` | Maximum | `reduce $max = max($val);` |
| `std` | Std deviation | `reduce $std = std($val);` |
| `list` | Collect to list | `reduce $items = list($item);` |

### Annotations

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@abstract` | Cannot instantiate | `entity content @abstract;` |
| `@key` | Unique identifier | `owns id @key;` |
| `@unique` | Unique optional | `owns email @unique;` |
| `@subkey` | Composite key | `owns part @subkey("composite");` |
| `@card` | Cardinality | `owns name @card(1..3);` |
| `@values` | Enum values | `@values("a", "b", "c");` |
| `@range` | Value range | `@range(0..100);` |
| `@regex` | String pattern | `@regex("^[a-z]+$");` |
| `@distinct` | Unique in list | `owns tag @distinct;` |
| `@independent` | Survives unowned | `@independent;` |
| `@cascade` | Delete behavior | `relates owner @cascade;` |

---

## Mental Models (Type Theory, Polymorphism, Dependent Types)

These are the ideas that make TypeQL feel inevitable rather than arbitrary. They're the difference between writing valid TypeQL and writing *idiomatic* TypeQL. Sources: the 2024 PACMMOD paper and TypeDB's 2023–2024 lecture series (`MF2vaEo3o58`, `2S0zPXQCy0U`, `IJomvpKbevk`, `LMzZoq6fUqg` on the Vaticle YouTube channel).

### Queries as Types

SQL view: a query is a *plan* — an operational recipe of joins, filters, projections that transforms tables into tables.

TypeQL view: a query is a *type* — a declarative description of the domain of data you want. The pattern **is** the type.

```typeql
# Reads as: "the type of (u, n) pairs where u is a user and u owns name n"
match $u isa user, has name $n;
```

The planner is free to reorder, parallelize, index, push predicates — it just has to preserve the type. This is why TypeQL schemas stay small as systems grow: you don't need a new query for every shape of question, because polymorphism is baked into the type system.

### Relations as Dependent Types

A relation in TypeDB is a **dependent type**: its instances depend on instances of its role players. Formally, `friendship` is parameterized by two `person`s; you cannot instantiate it without them.

```typeql
define
relation friendship,
  relates friend @card(2);
```

Consequences:
- **Integrity** — you can't create a relation pointing at nothing (contrast: SQL allows NULL foreign keys, graph DBs allow dangling edges).
- **Cascade** — deleting a role player can trigger deletion of the relation (`@cascade`), because the relation *depends* on the player.
- **n-ary** — relations aren't stuck at binary (unlike property graphs' edges). `relation meeting, relates organizer, relates attendee, relates venue;`

### Interface Polymorphism (Role Playing)

Roles are **interfaces**. Multiple unrelated types can implement the same role, and relations referencing that role automatically work for all implementers.

```typeql
define
entity person, plays adoption:parent, plays adoption:child;
entity company, plays adoption:parent;   # companies can adopt (projects, subsidiaries)
entity organization, plays adoption:parent;
relation adoption,
  relates parent,
  relates child;
```

A single query works for every combination — person→person, company→person, organization→person — with no rewriting. When a new type joins (`entity foundation, plays adoption:parent;`), existing queries automatically include it.

This is why Haskell calls them *typeclasses*, Rust calls them *traits*, and TypeDB calls them *roles*. Same idea, applied to a database.

### Abstract Types and Subtyping

Entities, relations, AND attributes can be abstract and subtyped — this is richer than any of the three classical database paradigms.

```typeql
define
entity resource @abstract, owns id, plays ownership:resource;
entity file sub resource, owns path;
entity directory sub resource, owns path;

attribute id @abstract, value string;
attribute email sub id;
attribute path sub id;
```

A query against `$r isa resource` returns files AND directories. A query against `$x has id` returns anything with *any* subtype of `id` — email, path, anything added later.

---

## Canonical Polymorphic Example: Filesystem + Ownership

This schema (from the TypeDB Fundamentals docs) is the canonical teaching example for polymorphism. It demonstrates abstract entities, role aliasing in subrelations, abstract attribute hierarchies, and polymorphic fetch.

```typeql
define

# Actors
entity user,
    owns email,
    owns password-hash,
    owns created-timestamp,
    owns active,
    plays resource-ownership:resource-owner;

entity admin sub user,
    plays group-ownership:group-owner;

entity user-group,
    owns name,
    owns created-timestamp,
    plays group-ownership:group,
    plays resource-ownership:resource-owner;

# Abstract base + concrete resources
entity resource @abstract,
    owns id,
    owns created-timestamp,
    owns modified-timestamp,
    plays resource-ownership:resource;

entity file sub resource,
    owns path;

entity directory sub resource,
    owns path;

# Abstract relation + role aliasing in subrelations
relation ownership @abstract,
    relates owned,
    relates owner;

relation group-ownership sub ownership,
    relates group as owned,            # subrelation renames the inherited role
    relates group-owner as owner;

relation resource-ownership sub ownership,
    relates resource as owned,
    relates resource-owner as owner;

# Abstract attribute hierarchy
attribute id @abstract, value string;
attribute email sub id;
attribute name sub id;
attribute path sub id;
attribute password-hash, value string;

attribute event-timestamp @abstract, value datetime;
attribute created-timestamp sub event-timestamp;
attribute modified-timestamp sub event-timestamp;
attribute active, value boolean;
```

### Polymorphic fetch over this schema

```typeql
# Returns every resource of every subtype (files AND directories)
# with all their timestamps (created AND modified, since both sub event-timestamp).
match
  $resource isa resource;
fetch {
  "resource": {
    "id": $resource.id,
    "event-timestamp": [ $resource.event-timestamp ],
  }
};
```

The `[...]` brackets around `$resource.event-timestamp` tell `fetch` this is a multi-valued projection. Because the resource owns `created-timestamp` and `modified-timestamp` (both subtypes of `event-timestamp`), the polymorphic fetch returns both.

---

## TypeDB 3.x Feature Deep Dive

These are 3.0+ features that change how you model data. Previously unavailable in 2.x.

> **Three of these are UNVERIFIED here.** `struct`, list value types
> (`value string[]`) and `@index` have **zero occurrences** in `schema/*.tql`
> and **zero** in the live `GET /v1/databases/one/schema` dump, and confirming
> them needs a schema transaction, which is a write. Treat the `struct`, *List
> Attributes* and *Relation Indexing* subsections below as upstream-documentation
> summaries, not as things known to work on 3.12.1. Probe with a `commit:false`
> schema tx before relying on any of them. `@cascade` and `@subkey` are in the
> same position.

### Cascading Delete

Delete semantics are explicit via `@cascade` on relation roles. When the annotated role player is deleted, the relation itself is also deleted.

```typeql
define
relation ownership,
    relates owner @cascade,   # if owner deleted → delete relation
    relates owned;

# A single delete of $folder cascades to all ownership relations
# where $folder plays owner.
match $folder isa directory, has path "/tmp/old";
delete $folder;
```

Use case: cleaning up role-based access control (RBAC) — delete a user, their ownership edges go too.

### Struct Value Types

Compose multi-field values without reifying them as entities.

```typeql
define

struct address {
    street:      string,
    city:        string,
    postal-code: string,
    country:     string,
}

attribute home-address, value address;

entity person, owns home-address @card(0..1);

# Insert
insert $p isa person,
    has home-address (
        street: "123 Main St",
        city: "Portland",
        postal-code: "97214",
        country: "USA"
    );

# Match by a struct field (project from the struct)
match
  $p isa person, has home-address $addr;
  $addr.city == "Portland";
select $p;
```

Use structs for values that are always copied together and have no identity of their own — otherwise, prefer an entity + relation.

### List Attributes

3.x native list-valued attributes are distinct from multi-cardinality ownership.

```typeql
define
attribute tags, value string[];        # list value type
entity article, owns tags;

insert $a isa article,
    has tags ["typedb", "polymorphism", "type-theory"];

match $a isa article, has tags $ts;
select $ts;                            # returns the list as one value
```

Rule of thumb: use a **list attribute** when order matters or the collection is consumed atomically. Use `@card(0..)` multi-ownership when each element is independently queryable (e.g., multiple emails where you want to match on any one).

### Relation Indexing

Mark high-cardinality lookup roles with `@index` for planner hints.

```typeql
define
relation friendship,
    relates friend @card(2) @index;

# Planner prioritizes indexed-role lookup for:
match $f isa friendship, links (friend: $alice, friend: $other);
  $alice has name "Alice";
select $other;
```

### Functions (replace 2.x `rule`)

Rules are gone. Functions are the only way to express derivation logic in 3.x.
See *Inference Rules (Emergence Patterns)* above for the full rule→fun
translation table.

```typeql
define
# Return type names TYPES ONLY. `-> { $to: city }` is a TQL0 syntax error
# ("expected named_type_any").
fun reachable-cities($from: city) -> { city }:
  match ($from, $to) isa flight;
  return { $to };

# Transitively: fun with recursive call (bounded by the type system).
# Iterate a stream with `let $x in f(...)` — NOT `f(...) contains $x`,
# which is substring matching and fails with REP44.
fun reachable-transitively($from: city) -> { city }:
  match
    { ($from, $direct) isa flight; }
    or
    { let $mid in reachable-cities($from);
      let $direct in reachable-transitively($mid); };
  return { $direct };

# Use in a query — `in`, not `=`, for a stream
match
  $nyc isa city, has name "New York";
  let $dest in reachable-transitively($nyc);
select $dest;
```

This is exactly the shape of the deployed `descendants-of` and `reachable`
functions — see `schema/reason.tql` and `schema/roles.tql`:

```typeql
fun descendants-of($g: group) -> { group }:
    match
        { (parent: $g, child: $descendant) isa hierarchy; }
        or
        { (parent: $g, child: $mid) isa hierarchy;
          let $descendant in descendants-of($mid); };
    return { $descendant };
```

Functions can return streams (`{ ... }`), single values (`scalar`), or structs. They compose in pipelines and let the planner see through the abstraction.

### MVCC + Temporal (under the hood)

TypeDB 3.x uses **MVCC** internally. Every transaction is tagged with a version; old versions are retained for a configurable TTL. The API to read-at-version is **not yet exposed** (per "Inside TypeDB: The Next Chapter", Dec 2025 — "probably not more than a day or two of work to expose"). Track:

```
# When exposed, expected surface:
with driver.transaction(db, TransactionType.READ, at_version=42) as tx:
    ...
```

Design implication: you can already treat your data as time-travelable for audit/testing purposes; the exposure is a driver-level unlock, not a storage migration.

---

## Production Deployment & Scaling

### Architecture (3.x)

- **Core**: Rewritten in Rust (2024–2025). Old Java codebase retired; Rust rewrite is GA as of TypeDB 3.0.
- **Storage**: RocksDB as the key-value layer; TypeDB's type-level indexing built on top.
- **Cluster**: Highly-available cluster mode (Raft-replicated) — single writer, multiple readers. Rust HA cluster was in final preview as of Dec 2025 (`LS6C4Gl9ldU`).

### Scale markers (from Dec 2025 all-hands)

| Metric | Status |
|--------|--------|
| Single-server data size | Tested beyond 1 TB |
| Benchmark comparison | Competitive with and surpassing Neo4j on first Rust-optimization pass |
| Read scaling | Horizontal via Raft cluster replicas |
| Write scaling | Single master; partitioned writes on roadmap |
| Cloud free tier | Always available, no credit card |

### Operational checklist

- Set **transaction timeout** explicitly if you query long ranges — default is 5 minutes, which bites large migrations.
- Set **schema lock timeout** only in schema transactions — default 30 seconds is usually fine.
- Prefer **TypeDB Cloud** or HA cluster for anything user-facing — a single server is for dev, demos, and embedded use.
- **Snapshot isolation** is the model. Reads never block writes and vice versa; conflicts surface at commit time → catch `ConflictException` and retry (exponential backoff — see "Error Handling" section).

---

## Development Tools & Ecosystem

### TypeDB Studio (web-based)

Web IDE for TypeDB, also downloadable as a local package. Connects to any local TypeDB server, TypeDB Cloud, or any HTTP-accessible endpoint. Schema visualization, query runner, result graph view.

- Hosted: https://studio.typedb.com
- Local download: https://typedb.com/downloads

Migration note: older docs reference the **Kotlin desktop** Studio — that's retired. Current Studio is browser-native.

### Vibe Querying (alpha — agentic TypeQL)

LLM-powered natural-language → TypeQL, currently running on GPT-5. Available in TypeDB Studio and the docs chatbot.

- Good for: exploration, scaffolding, "show me something like X".
- Not good for: production queries without review. It still makes mistakes on domain-specific type names.
- Recommended pattern: generate → paste into Studio → adjust → commit the TypeQL, not the prompt.

### TypeDB Cloud

- **Free tier**: always available, 1 GB storage, no credit card.
- **Security Center** + **MFA** + configurable **backups** since 2025.
- Python connection (same code works for self-hosted, Cloud, or HA cluster):

```python
from typedb.driver import TypeDB, Credentials, DriverOptions, TransactionType
import os

credentials = Credentials("admin", os.environ["TYPEDB_PASSWORD"])
options = DriverOptions(is_tls_enabled=True)
driver = TypeDB.driver(
    "https://my-cluster.typedb.cloud:1729",   # Cloud
    credentials,
    options,
)
```

**Port 1729** is canonical — not 80, not 443. The HTTP API prefix is `/v1/`.

### Language Server Protocol (on roadmap)

TypeDB team announced (Dec 2025) an incoming **`analyze`** endpoint — returns type annotations for a query without executing it — plus LSP support for VS Code, JetBrains, Vim. Expected through 2025. Until then, the console and Studio's inline diagnostics are the fastest feedback loop.

### Ecosystem libraries (community-maintained)

- **Pydantic** integration for model (de)serialization.
- **CSV / JSON loaders** for bulk import.
- **IDE syntax plugins** for VS Code, IntelliJ (before the LSP ships).

---

## SQL → TypeQL: Concrete Contrasts

### Simple filter + projection

```sql
-- SQL
SELECT p.product_name, p.unit_price
FROM   products p
JOIN   categories c ON p.category_id = c.category_id
WHERE  c.category_name = 'Beverages';
```

```typeql
# TypeQL — the relation (category-assignment) IS the join
match
  $cat isa category, has name "Beverages";
  $prod isa product, has product-name $pname, has unit-price $price;
  (assigned: $prod, category: $cat) isa category-assignment;
select $pname, $price;
```

Differences:
- **Relation is first-class** — no foreign-key column, no `JOIN ON`. The relation `category-assignment` models the membership explicitly.
- **Polymorphic by default** — if later you add `entity beverage sub product;`, this query returns beverages automatically.
- **No nullable join columns** — a relation either exists between role players or it doesn't. No NULL tri-state.

### Reachability (graph-style)

```cypher
// Neo4j
MATCH path = (c1:City {name: "New York"})-[:FLIGHT*1..3]->(c2:City {name: "London"})
RETURN path
```

```typeql
# TypeQL — reachability is a type function, not a path operator
define
fun flight-reachable($from: city, $hops: integer) -> { city }:
  match
    { $hops == 1; ($from, $to) isa flight; }
    or
    { $hops > 1;
      ($from, $mid) isa flight;
      let $next = $hops - 1;
      let $to in flight-reachable($mid, $next); };
  return { $to };

match
  $nyc isa city, has name "New York";
  let $city in flight-reachable($nyc, 3);
  $city has name "London";
select $city;
```

In Neo4j, variable-length path is a query-language primitive. In TypeQL, it's a **user-definable function** — which means any reachability logic (weighted, filtered by attribute, cross-type) is equally expressible without new syntax.

---

## Works With /sui — The Same Ontology, Two Deterministic Fires

> **STALE — this section describes a layout the repo no longer has. Verify
> before acting on any path or function name in it (checked 2026-08-02).**
> `src/engine/bridge.ts`, `src/move/one/sources/one.move` and `src/lib/sui.ts`
> **do not exist**, and no file in the monorepo defines `mirrorMark`,
> `mirrorHarden` or `absorb`. The Move sources live under `pay/contracts/sui/`
> and the Sui runtime under `pay/backend/src/chains/sui.ts` +
> `one.ie/web/src/lib/resolvers/sui.ts`. `struct Colony` is **not** in the
> current `one.move`. The *conceptual* crosswalk below (Move struct ⇌ TQL
> attribute, shared `strength`/`resistance` names) still holds and is why the
> section is kept; the file/function inventory does not.

**"The same ontology. Two deterministic fires."** TypeDB is the learning, classification fire (hypotheses, frontiers, tags — cheap to write, rich to query). Move is the permanent, economic fire (path revenue, escrow, treasury — expensive to write, cheap to trust). The runtime is the fast nervous system between them. Both skills speak the same vocabulary by design — `strength`, `resistance`, `revenue`, `path`, `actor` — so the bridge is a **1:1 rename, not a translation**.

### Canonical crosswalk

`schema/sui.tql` (475 lines) is the Rosetta Stone — every Move struct has a matching TQL entity, every Move function has a matching TQL `fun`. Read it when names or shapes drift. **It is codegen input, not a loadable schema** — `schema/codegen/codegen.ts` parses it standalone to emit Move; it is never loaded into TypeDB, and it is written in the `if/then/else` form the server rejects. The canonical ontology (6 dimensions, stable) is `schema/one.tql` (480 lines).

### Attribute mapping (Move struct ⇌ TypeDB attribute)

| Move field (`one.move`)         | TQL attribute (`world.tql`)    | Move type   | TQL type | Direction                     |
|---------------------------------|--------------------------------|-------------|----------|-------------------------------|
| `Unit.id` (address)             | `actor.sui-unit-id`             | address     | string   | Sui → TQL on `mirrorActor()`  |
| *derived by* `addressFor(uid)`  | `actor.wallet`                  | address     | string   | Runtime → TQL on agent sync   |
| `Unit.name`                     | `unit.name`                    | String      | string   | bidirectional                 |
| `Unit.balance`                  | `actor.balance`                 | u64         | double   | Sui → TQL via `absorb()`      |
| **`Path.strength`**             | **`path.strength`**            | u64         | double   | bidirectional — load-bearing  |
| **`Path.resistance`**           | **`path.resistance`**          | u64         | double   | bidirectional — load-bearing  |
| `Path.revenue`                  | `path.revenue`                 | u64         | double   | Sui → TQL via `absorb()`      |
| `Path.id` (address)             | `path.sui-path-id`             | address     | string   | Sui → TQL on mirror           |
| `Highway.id` (address)          | `path.sui-highway-id`          | address     | string   | Sui → TQL on `mirrorHarden()` |
| `Signal.payload` (vector<u8>)   | `signal.data`                  | bytes       | string   | one-way, usually TQL-only     |

**Name drift to know about:** older Move sources carried a `struct Colony`; TypeDB moved to `entity group` per `text/dictionary.md`. `colony` is a **dead name** (root `CLAUDE.md`) and is **no longer present** in `pay/contracts/sui/.../one.move` (checked 2026-08-02). If you meet it in an old artifact, read it as TQL `group`.

**Load-bearing invariant:** `strength` and `resistance` share the same name in both layers. If you rename one, rename both — `bridge.ts` is a pass-through, there's no translation logic. Type-width (`u64` ↔ `double`) is handled by JSON serialization at the bridge; don't write TQL queries that assume sub-integer precision on these columns.

### Bridge contract (module no longer present — shape reference only)

| Function                          | Fires when                  | Maps                                                                   |
|-----------------------------------|-----------------------------|------------------------------------------------------------------------|
| `mirrorMark(from, to, amount?)`   | every `persist.mark()`       | Runtime strength++ → Sui `mark_path()`                                   |
| `mirrorWarn(from, to, amount?)`   | every `persist.warn()`       | Runtime resistance++ → Sui `warn_path()`                                 |
| `mirrorPay(from, to, amount)`     | L4 payment signal            | Runtime payment → Sui `pay()` → `Path.revenue +=`                        |
| `mirrorHarden(from, to)`          | L6 highway promotion         | TQL harden → Sui `harden_path()` → Highway object created                |
| `mirrorActor(uid, name)`          | `/api/agents/register`       | `addressFor(uid)` + `createUnit()` → writes `wallet` + `sui-unit-id` back |
| `resolve(uid)`                    | before any outbound Sui call | TQL lookup → `{ wallet, unitId }` — no on-chain twin? dissolve           |
| `resolvePath(from, to)`           | on-chain path ops            | TQL `sui-path-id` lookup — memoized via edge cache                       |
| `absorb(cursor?)`                 | `/api/absorb` cron (1 min)   | Sui events → TQL writes: UnitCreated, Marked, Warned, Paid, Hardened     |
| `settleEscrow(...)` *(Phase 3)*   | `releaseEscrow()` succeeds   | on-chain settlement → TQL `path.revenue` + `path.strength` mark          |

**Guarantee:** `mirror*` functions are fire-and-forget. They never block the TypeDB write or the runtime signal loop. If Sui is down, TypeDB still learns; pheromone re-converges when `absorb()` catches up. That's why it's safe to use `writeSilent()` / `writeTracked()` semantics at the TypeDB layer — the bridge can always replay.

### TQL queries that read on-chain state

```typeql
# Find actors with an on-chain twin
match $u isa actor, has wallet $w, has sui-unit-id $s;
select $u, $w, $s;

# Paths that accumulated real revenue on-chain
match $p isa path, has revenue $r, has sui-path-id $id;
$r > 0.0;
select $p, $r, $id;
sort $r desc;

# Hardened highways (frozen on-chain)
match $p isa path, has sui-highway-id $hw;
select $p, $hw;
```

### When to load /sui alongside this skill

- Adding a field to a Move struct that needs off-chain query — the TQL attribute must match
- Touching Move path/signal logic under `pay/contracts/sui/` — `schema/one.tql` and `text/dictionary.md` are the source of truth for names
- Debugging why an on-chain absorb isn't writing to TypeDB — check the loaded schema accepts the attribute type
- Writing a TQL `fun` that needs an on-chain twin — see `schema/sui.tql` for parallel function signatures
- Querying `actor.wallet` values — they're derived from the Sui resolvers (`one.ie/web/src/lib/resolvers/sui.ts`), not always stored

---

## Production Patterns: Classifier Functions, Thing Collapse, Symmetric Routing

These patterns come from **`schema/world.tql`** and are worth learning because they turn abstract ideas ("Queries as Types", polymorphism, role interfaces) into code that's actually short, composable, and fast to query.

> **Read the code below for the *shape*, and never paste it.** Two corrections
> that this section got wrong for a long time:
>
> 1. **`world.tql` is not the live runtime schema of the main database.** Per
>    `schema/CLAUDE.md` it is the **brain schema for the standalone `api/`
>    BrainDO database only** — it declares `task-value`/`task-effort` as strings
>    where `one.tql` declares doubles, so co-loading the two fails on a
>    value-type conflict. The main `one` database's canon is
>    `one.tql` + `roles.tql` + `do.tql` + `reason.tql` + `router.tql` +
>    `factory.tql` + `work-contract.tql` + `chat.tql`.
> 2. **`world.tql` is written in `return first if … then … else …`, which the
>    live 3.12.1 server rejects with `TQL0`** (VERIFIED table). It is therefore
>    not deployable as written. `schema/reason.tql` carries the rewrite that
>    *is* deployed. Below, every function is shown in the **deployable**
>    disjunction form, with the `world.tql` original noted where it differs.
>
> Attribute names differ across the two too: `success-rate`, `sample-count` and
> `activity-score` exist in `world.tql` and **not** in the live `one` database.
> Check `GET /v1/databases/one/schema` before assuming an attribute is there.

### Pattern 1 — The Deterministic Sandwich as a Function Chain

A **deterministic sandwich** wraps a probabilistic operation (usually an LLM call) in a pre-check and a post-check, so the indeterminism is bounded on both sides. In TypeQL 3.x, every slice of the sandwich is a **typed function** returning either a bound boolean or a stream.

```typeql
# schema/world.tql:586–614 — shape only; signatures corrected to `actor`
# (world.tql says `actor`, an older draft of this skill said `unit`, a dead name)

# PRE: Can this receiver handle this skill? (capability check)
fun can_receive($u: actor, $sk: skill) -> boolean:
    match (provider: $u, offered: $sk) isa capability;
    let $ok = true;
    return first $ok;

# PRE: Is the path to this receiver safe? (not toxic)
fun is_safe($from: actor, $to: actor) -> boolean:
    match
        (source: $from, target: $to) isa path,
            has strength $s, has resistance $r;
        { $r > $s; $r >= 10.0;        let $ok = false; }
        or { not { $r > $s; $r >= 10.0; }; let $ok = true; };
    return first $ok;

# PRE: Is the signal within budget?
fun within_budget($u: actor, $sk: skill, $amount: double) -> boolean:
    match
        (provider: $u, offered: $sk) isa capability, has price $p;
        { $amount >= $p;   let $ok = true; }
        or { $amount < $p; let $ok = false; };
    return first $ok;

# POST: Does the referenced actor still exist?
fun unit_exists($uid: string) -> boolean:
    match $u isa actor, has aid $uid;
    let $ok = true;
    return first $ok;

# COMPOSED: All the PRE checks as a single type assertion
fun preflight($from: actor, $to: actor, $sk: skill) -> boolean:
    match
        (provider: $to, offered: $sk) isa capability;
        (source: $from, target: $to) isa path,
            has strength $s, has resistance $r;
        { $r > $s; $r >= 10.0;        let $ok = false; }
        or { not { $r > $s; $r >= 10.0; }; let $ok = true; };
    return first $ok;
```

**Why this is elegant:**

1. **Each check is a type, not a subroutine.** `is_safe($from, $to)` declares the type "this path is safe". The planner decides whether to evaluate it by scanning strength/resistance, by checking an index, or by proving it vacuously. You never write "first look up strength, then compare".

2. **An exhaustive disjunction binding one `let` per branch, closed by `return first $var`,** is the TypeDB 3.x idiom for boolean and string classifiers — there is no conditional expression in the language. Each branch after the first must negate the earlier ones, or a row matching two branches makes `return first` arbitrary.

3. **Composition is just another function.** `preflight()` inlines the match patterns of its children rather than calling them — this lets the planner see the whole constraint set and pick the cheapest plan. (Calling three separate functions would force three sequential lookups.) This is the same "inline the body" rule as *functions are for counts*.

4. **Negative space stays declarative.** A trust check that passes when `success-rate >= 0.50 OR sample-count < 10` trusts new agents by default, because there is no evidence against them. That's a domain rule encoded as a type, not as a runtime `if`. (`is_trustworthy` reads `success-rate`/`sample-count` — BrainDO-only attributes, so it is a `world.tql` function and has no counterpart in the main database.)

### Pattern 2 — The `thing` Collapse (Polymorphism as Entity-Level Union)

Instead of modeling plan, cycle, task, and skill as four separate entities, the canonical ontology (`schema/one.tql:96+`) **collapses them into one `thing` entity** discriminated by a `thing-type` attribute. Attributes specific to each kind (`task-status`, `cycles-planned`, `goal`) live on the shared entity, unused for non-matching kinds.

```typeql
# Abridged — schema/one.tql is the source, and it is much longer than this.
entity thing,
    owns tid @key,
    owns name,
    owns thing-type,     # skill|task|token|service|plan|step|corpus|
                         # creative-asset|do-cycle|do-plan — see @values
    owns price,
    owns tag @card(0..),
    # Task-only (meaningful when thing-type='task')
    owns task-status,    # open/blocked/picked/done/verified/failed/dissolved
    owns task-effort,
    owns task-value,
    owns exit-condition,
    # Workflow steps (meaningful when thing-type='step')
    owns step-kind,      # trigger|tool|skill|agent|condition|human|delay|sell
    owns step-config,
    # Plan-only (meaningful when thing-type='plan')
    owns goal,
    owns cycles-planned,
    owns escape-condition,
    # Agent rubric (trade lifecycle VERIFY — LLM response quality)
    owns rubric-fit,
    owns rubric-form,
    owns rubric-truth,
    owns rubric-taste,
    # Code rubric (/do W4 — security/stability/simplicity/speed)
    owns rubric-security,
    owns rubric-stability,
    owns rubric-simplicity,
    owns rubric-speed,
    owns rubric-composite,
    plays capability:offered,
    plays blocks:blocker,
    plays blocks:blocked,
    plays containment:container,
    plays containment:contained,
    plays production:producer,
    plays production:produced;
```

**Vocabulary law:** every `@values` enum lives in `one.tql` AND must be mirrored
by a migration before prod writes rely on a new value. Adding a convention value
in a doc or a `.ts` without widening the deployed `@values` means the write is
rejected at the constraint (`schema/CLAUDE.md`).

**When to use it:**

- The concepts share >50% of their attributes and all their relations.
- You want polymorphic queries that span all kinds (`match $t isa thing, has tag "P0";` returns tasks AND plans AND skills tagged P0).
- The kinds aren't large enough to warrant physical partitioning.

**When to avoid it:**

- A concept has strict invariants enforced by NOT NULL (TypeDB doesn't enforce attribute presence by `thing-type`; you'd need a function to validate).
- You need compile-time guarantees that "only tasks have `task-status`". The collapse is dynamic typing inside a static system.

**Filter pattern (the "discriminated fetch"):**

```typeql
# Only things that are tasks AND open
fun open_tasks() -> { thing } :
    match
        $t isa thing, has thing-type "task", has task-status "open";
    return { $t };

# Polymorphic priority: works across kinds because all own task-priority
fun top_by_priority($kind: string) -> { thing } :
    match
        $t isa thing, has thing-type $kind, has task-priority $p;
    sort $p desc; limit 10;
    return { $t };
```

Compare this with the maximalist `schema/world.tql` (844 lines, separate `task` entity with its own `task-id`, `task-status`, priority formula, etc.). The **skinny ontology** (`one.tql`, 480 lines) uses the collapse for flexibility; the **BrainDO schema** (`world.tql`) uses separate entities for performance and strict typing. Both are valid — the choice depends on how much schema change you expect. They cannot be loaded into the same database.

### Pattern 3 — Symmetric Routing via Shared-Variable Unification

When you have a relation "X matches Y on tag", you usually need both directions — "what Y's match this X" AND "what X's match this Y". In SQL this is two separate queries. In TypeQL, both queries share the same match pattern; only the return changes.

```typeql
# schema/world.tql:805–822 — verbatim symmetric pair.
# Note every signature says `actor`, never `unit` (a dead name).

# "What tasks can this actor work on?" (actor → tasks)
fun tasks_for_unit($u: actor) -> { task }:
    match $u has tag $tag;
          $t isa task, has tag $tag, has done false, has task-status "open";
    return { $t };

# "Which actors can do this task?" (task → actors)
fun actors_for_task($t: task) -> { actor }:
    match $t has tag $tag;
          $u isa actor, has tag $tag, has status "active";
    return { $u };

# "Best actor for this task": tag overlap × path strength
fun best_unit_for_task($t: task) -> actor:
    match $t has tag $tag;
          $u isa actor, has tag $tag, has status "active";
          (source: $any, target: $u) isa path, has strength $s;
    sort $s desc; limit 1;
    return $u;
```

**Why this is "Queries as Types" at its cleanest:**

- The `$tag` variable is shared between `$u has tag $tag` and `$t has tag $tag`. TypeQL **unifies** these — there must exist at least one tag value that both sides agree on. No `JOIN ON` clause, no foreign key; the type constraint IS the join.

- The pattern is symmetric because the *type* of "actor-task matches on tag" doesn't care about direction. Only the *projection* (`return { $t }` vs `return { $u }`) picks a side.

- `best_unit_for_task` composes the matching pattern with a *third* constraint (pheromone strength on an incoming path). Notice `(source: $any, target: $u)` — `$any` is bound but unconstrained; we don't care WHO marked the path, only that SOMEONE marked it. That's a free variable in the type.

### Pattern 4 — Classification by Cascade (the `path_status` function)

One more worth lifting out. The substrate labels every path with one of five statuses using a single function whose body is a nested conditional:

`schema/world.tql:570–577` writes it as an `if/then/else` cascade. **That form does
not parse on the live server** — this is the deployed rewrite, and it is the
single best worked example of translating a cascade into TypeQL:

```typeql
# schema/reason.tql:63–79 — the DEPLOYED five-branch classifier
fun path_status($p: path) -> string:
    match
        $p has strength $s, has resistance $r, has traversals $t;
        { $r > $s; $r >= 10.0;
          let $status = "toxic"; }
        or { $s >= 50.0; not { $r > $s; $r >= 10.0; };
          let $status = "highway"; }
        or { $s >= 10.0; $s < 50.0; $t < 10;
             not { $r > $s; $r >= 10.0; };
          let $status = "fresh"; }
        or { $s > 0.0; $s < 5.0; not { $r > $s; $r >= 10.0; };
          let $status = "fading"; }
        or { not { $r > $s; $r >= 10.0; };
             not { $s >= 50.0; };
             not { $s >= 10.0; $s < 50.0; $t < 10; };
             not { $s > 0.0; $s < 5.0; };
          let $status = "active"; };
    return first $status;
```

The precedence that `else if` gave you for free — `toxic` beats `highway`,
`highway` beats `fresh` — **you now write by hand** as a `not { … }` guard in
every later branch. That verbosity is the whole cost of the missing conditional
expression, and skipping a guard is a silent bug: a path matching two branches
produces two rows and `return first` picks one arbitrarily. In 2.x this was five
chained `rule`s with priority annotations; the cascade order is at least still
visible in the source.

**Adjacent pattern — reading the label:**

```typeql
match
    $p isa path, has strength $s;
    let $status = path_status($p);
    $status == "highway";
select $p, $s;
```

The result reads like English: "paths whose status is highway". The function is a verb (`path_status(p)`) that returns a type-tagged string — classification without explicit rule firing.

This is also the boundary where **functions are for counts** bites. `path_status`
returns a scalar, so calling it per row is what it is for. If instead you wanted
*the paths and their strengths and their tags*, do not call a stream fun and then
`has` the results — inline the fun's match body and select the attributes in one
pipeline. The call form is what turns a sub-second query into a 10-second timeout.

---

## Project-Specific Patterns

> **These examples are from a trading prototype, not from this repo.**
> `signal-edge`, `live-prediction`, `edge-trail-level`, `win-count`,
> `from-state-id`, `prediction-id` and friends exist in **no** `.tql` file here
> and in **no** live database. `trail` is also a dead name (root `CLAUDE.md`).
> They are kept as generic modelling shapes; for a real query against the ONE
> substrate use `path` / `strength` / `resistance` / `traversals` and the
> functions listed in `schema/CLAUDE.md`.
>
> **The read-modify-write examples below are the rejected pattern.** Writes take
> **literals only** — `insert $e has strength ($s + 1)` and `insert $e has
> strength $ns` (a value variable) both fail with `REP1 Attribute vs Value`, and
> there is no in-database increment on this build. The shape that works is:
> read the current value, compute it in the caller, write it back with
> `update $e has strength 7.0;` (`update` is replace-or-add on `@card(0..1)` —
> no delete needed). See `readPathWeights` / `updatePathWeights` in
> `one.ie/web/src/lib/substrate.ts`.

### Signal-Edge Operations (Trading)

```typeql
# Define signal-edge
define
attribute edge-id, value string;
attribute from-state-id, value string;
attribute to-signal-direction, value string;
attribute win-count, value integer;
attribute loss-count, value integer;
attribute total-pnl, value double;
attribute edge-trail-level, value double;

entity signal-edge,
    owns edge-id @key,
    owns from-state-id,
    owns to-signal-direction,
    owns win-count,
    owns loss-count,
    owns total-pnl,
    owns edge-trail-level;

# Query high-performing edges
match
    $e isa signal-edge,
        has edge-id $id,
        has edge-trail-level $level,
        has total-pnl $pnl;
    $level >= 20.0;
    $pnl > 0;
select $id, $level, $pnl;
sort $pnl desc;
limit 20;

# Update edge statistics — literal only, and `update` needs no delete
match $e isa signal-edge, has edge-id "edge-001";
update $e has win-count 15;
```

### Weighted-Path Patterns (prototype names — see the section note above)

```typeql
# Deposit pheromone
match $e isa signal-edge, has edge-id "edge-001";
update $e has edge-trail-level 25.5;

# Find superhighways (high-pheromone trails)
match
    $e isa signal-edge,
        has edge-id $id,
        has edge-trail-level $level;
    $level >= 20.0;
select $id, $level;
sort $level desc;
limit 10;

# Decay by 10% — THERE IS NO IN-DATABASE FORM OF THIS.
# `let $new = $old * 0.9; delete $old; insert $e has edge-trail-level $new;`
# is REJECTED (REP1 Attribute vs Value): writes take literals only.
# Step 1 — read the current values:
match $e isa signal-edge, has edge-id $id, has edge-trail-level $old;
select $id, $old;

# Step 2 — multiply in the caller, then write one literal per row:
#   update $e has edge-trail-level 22.95;
```

### Live Prediction Tracking

```typeql
define
attribute prediction-id, value string;
attribute pattern-name, value string;
attribute predicted-direction, value string;
attribute verified-1m, value boolean;
attribute verified-5m, value boolean;
attribute verified-1h, value boolean;

entity live-prediction,
    owns prediction-id @key,
    owns pattern-name,
    owns predicted-direction,
    owns verified-1m,
    owns verified-5m,
    owns verified-1h;

# Insert prediction
insert $p isa live-prediction,
    has prediction-id "pred-001",
    has pattern-name "volume_breakout",
    has predicted-direction "long";

# Update verification
match $p isa live-prediction, has prediction-id "pred-001";
update $p has verified-1m true;

# Query pattern accuracy
match
    $p isa live-prediction,
        has pattern-name $name,
        has verified-1h $correct;
    $correct == true;
reduce $wins = count groupby $name;
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│  TypeDB 3.12.1 Quick Reference                              │
├─────────────────────────────────────────────────────────────┤
│  CONNECT (this repo: HTTP, no driver)                       │
│  POST /v1/signin  -> token                                  │
│  POST /v1/query   {query, databaseName,                     │
│                    transactionType, commit}                 │
│  GET  /v1/version · GET /v1/databases/one/schema            │
│                                                             │
│  TRANSACTION TYPES                                          │
│  READ   - read only, concurrent                             │
│  WRITE  - data modifications                                │
│  SCHEMA - schema changes                                    │
│                                                             │
│  SCHEMA: define / undefine / redefine                       │
│  DATA:   match / insert / delete / update / put             │
│  OUTPUT: select / fetch / reduce                            │
│  STREAM: sort / limit / offset / distinct                   │
│                                                             │
│  VALUE TYPES                                                │
│  integer (not long!), double, decimal, boolean              │
│  string, date, datetime, datetime-tz, duration              │
│                                                             │
│  DELETE SYNTAX (3.x)                                        │
│  delete $attr;           # delete attribute                 │
│  delete has $attr of $e; # delete ownership                 │
│  delete $e;              # delete entity/relation           │
│                                                             │
│  ANNOTATIONS                                                │
│  @key, @unique, @card(n..m), @abstract                      │
│  @values(), @range(), @regex(), @independent                │
└─────────────────────────────────────────────────────────────┘
```

---

## References

### External

- [TypeDB Documentation](https://typedb.com/docs)
- [TypeQL Reference](https://typedb.com/docs/typeql-reference/)
- [Python Driver Reference](https://typedb.com/docs/reference/typedb-grpc-drivers/python/)
- [TypeDB 2.x to 3.x Migration](https://typedb.com/docs/reference/typedb-2-vs-3/)
- [Query Optimization Guide](https://typedb.com/docs/maintenance-operation/troubleshooting/optimizing-queries/)
- [TypeQL Paper · Dorn & Pribadi · PACMMOD 2024](https://dl.acm.org/doi/10.1145/3651611) — Best Newcomer Award, SIGMOD/PODS 2024
- [Vaticle YouTube Channel](https://www.youtube.com/c/vaticle) — lecture series on type theory and polymorphic modeling

### In-repo

- **`schema/CLAUDE.md` — read this first.** It is the authority on which `.tql` files load, in what order, which must never co-load, the `@values` vocabulary law, and the codegen pipeline. It outranks this skill on all of that.
- `schema/one.tql` (480 lines) — canonical 6-dimension ontology, locked. See *Pattern 2 — The `thing` Collapse*.
- `schema/roles.tql` (184) — the authority walk: `self-or-ancestors-of` · `open-ancestors-of` · `controls` · `can` · `funding-of` · `brand-of`. All six are live in prod.
- `schema/reason.tql` — inference layer, functions only. **The deployable `path_status`** and the recursive-closure examples (`reachable`, `strong-reach`, `route_exists`).
- `schema/do.tql` — build-engine layer, functions only. `do_stage` is the reference disjunction classifier.
- `schema/router.tql` (206) — universal signal router; `receivers-reachable-by` is live in prod.
- `schema/factory.tql` (993) — the factory ladder. **One file is one schema transaction on purpose:** a fun may only reference *committed* funs (`REP4`), so a partial deploy breaks it. Prod carried 39 of 43 funs as of 2026-07-30; `next` + the cost trio ship in `migrations/0045_factory_next.tql` and are **not yet live** (confirmed absent 2026-08-02).
- `schema/world.tql` (844 lines) — **standalone BrainDO schema, not the main database, and not deployable as written** (`if/then/else`). Source for *Production Patterns* above; read for shape only.
- `schema/sui.tql` (475 lines) — Move mirror. Codegen input, never loaded.
- `schema/migrations/` — 24 entries. Migration numbering is live through `0045`.
- `one.ie/web/src/lib/substrate.ts` — how TypeScript actually queries: gateway → `POST /v1/query`. `readPathWeights` / `updatePathWeights` are the read-compute-write increment pattern.
- `backup/scripts/typedb/dump.py` · `replay.py` — Python against `/v1/` via `urllib`, no driver. Also the source of the `(?![\w-])` role-matching fix and the `ensure_ascii=False` rule.
- `.claude/scripts/typedb-env.sh` · `.claude/typedb/{dev,prod}.env` — the dev/prod switch and the version pin.
- `.claude/scripts/typedb-probes/` — the 3.8.3 server-panic reproducers.
- `.claude/skills/typedb/reference/research-notes-2026-04.md` — source notes behind this skill's 2026-04 refinement: PACMMOD paper, 3.0 roadmap, Vaticle lectures, "Inside TypeDB: The Next Chapter".
- `.claude/skills/typedb/reference/migration-2x-3x.md` — mechanical 2.x→3.x translations (sessions, Concept API, rule→fun, long→integer, delete syntax).
- `.claude/skills/typedb/reference/python-driver.md` — deeper Python-driver reference than the summary in this file.
- `.claude/skills/typedb/examples/` — working TQL files: schema-patterns, query-patterns, python-patterns.
