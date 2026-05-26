# generate-from-tql

> **Position:** infrastructure plan — `.tql` becomes the single source of truth from which TypeScript types, Zod schemas, OpenAPI components, pattern bindings, and D1 mirrors are derived.
> **Owns:** the codegen pipeline at `schema/codegen/`. Consumers (`packages/sdk/`, `one.ie/web/`, `api/`) read generated files; nobody hand-writes entity types again.
> **Mode:** full. Variance is real (parser choice, IR shape, phase order are decisions, not transcription). Exit scalar exists per wave. Files known in this plan.
> **Lifecycle:** evolution. Existing hand-written types are replaced gradually, file-by-file. No flag-day cutover.

`.tql` already knows: every entity, every attribute with its value type, every relation's roles, every constraint (`@key`, `@card`, `@unique`), and every callable function with its signature. Today we re-state that knowledge in four other places (TS types, Zod schemas, OpenAPI yaml, D1 SQL). The four drift. This plan says: state it once.

---

## Why `.tql` is the right source

Four properties that OpenAPI / hand-rolled types can't match:

| Property | What it gives codegen |
|---|---|
| **Plays-roles** | `actor plays signal:sender, signal:receiver, membership:member` captures *what an entity can do*, not just its shape. Generated TS gets typed role unions for free. |
| **First-class functions** | `fun ancestors-of($g: group) -> { group }` is part of the schema, callable across consumers. Codegen wraps each `fun` as a typed SDK method + a `/api/fn/:name` route. |
| **Constraint annotations** | `@key`, `@card(0..)`, `@unique` are first-class. Generated Zod gets `.uuid()`-equivalent constraints without humans transcribing them. |
| **Skins / overlays** | `skins/engineering.tql` adds `task-type="story"` and aliases `group → sprint`. Generated TS produces `Sprint = Group<{ groupType: "sprint" }>` — domain DSL on top of substrate, typed end-to-end. |

OpenAPI describes a wire format. `.tql` describes the world. Wire format derives from world; the inverse doesn't work.

---

## Two decisions that drive everything

### Decision 1 — Parser, not introspection

Earlier draft proposed running TypeDB in Docker, loading `.tql`, introspecting via driver. **Wrong call.** Replacing with:

**Hand-written parser** — ~300 lines, recursive descent, parses the DEFINE-level grammar only.

| Approach | Verdict | Why |
|---|---|---|
| Hand-written parser | ✅ chosen | Pure function `(string) → IR`. No Docker, no network, no credentials, no flakiness. Skin merging is AST manipulation; we have the AST anyway. The DEFINE-grammar subset is ~12 productions. |
| Introspection (boot TypeDB, query driver) | ❌ rejected | Adds Docker dep to every CI run, every dev machine. Codegen depending on a running database creates circular bootstrap problem. Tracking schema changes via DB query is slower than reading the file. |
| Existing TypeQL parsers (npm) | ⚪ deferred | None are production-quality for TypeQL 3.x. Revisit when Vaticle ships an official JS parser. |

Function bodies (the `match ... return ...` clauses) are **opaque strings** in the IR — we extract signatures, not body semantics. The SDK wrapper for `ancestors-of` calls `/api/fn/ancestors-of` which the gateway executes against TypeDB. Codegen never needs to understand `match`.

### Decision 2 — Layout, and where outputs land

Add `schema/codegen/` subdir **now**. Do not reorganize existing `schema/` contents (`patterns/`, `seeds/`, `skins/`, `migrations/`, `archive/` stay put).

```
schema/
├── one.tql                    ← source
├── patterns/*.tql             ← fun definitions
├── seeds/*.tql                ← initial data
├── skins/*.tql                ← domain overlays
├── migrations/*.tql           ← TypeDB schema migrations
└── codegen/                   ← NEW
    ├── parse.ts               → .tql → AST
    ├── ir.ts                  → AST → IR (canonical JSON shape)
    ├── ir.json                ← committed; diff-able; the contract
    ├── targets/
    │   ├── zod-schemas.ts     → packages/sdk/src/generated/schemas.ts
    │   ├── openapi.ts         → one.ie/web/public/openapi.generated.yaml
    │   ├── pattern-bindings.ts → packages/sdk/src/generated/patterns.ts
    │   ├── d1-mirror.ts       → one.ie/web/migrations/_candidates/
    │   └── skin-types.ts      → packages/sdk/src/generated/skins/<name>.ts
    └── codegen.ts             ← orchestrator (`bun run codegen`)
```

**Generated files commit into consumer repos** (Option A — chosen over publishing `@oneie/schema` as an npm package). Reasons:

- Sibling repos build without schema present (no runtime/build-time dep)
- Generated diffs are reviewed at PR time — accidental changes catch the eye
- No npm-version-pinning headache between schema and consumers
- Codegen is a deliberate human-initiated step, not an opaque build phase

The workflow is one command from `schema/`:
```bash
bun run codegen  # touches files in ../packages, ../one.ie/web, ../api
```
Each consumer then commits its own diff in its own repo.

---

## The IR — the keystone

Everything downstream is a template walk over IR JSON. Get the IR right, and adding generators is trivial.

> **Grammar source:** TypeDB 3.0 — verified against `/typedb` skill. Value types, annotation set, function return variants, and subtyping behavior are 3.x-authoritative.

```typescript
type IR = {
  version: string                  // schema/one.tql content hash
  generatedAt: string              // ISO timestamp (stripped for diff)
  structs: Struct[]                // 3.x compound value types
  attributes: Attribute[]
  entities: Entity[]
  relations: Relation[]
  functions: Fn[]
}

type Struct = {                    // 3.x: struct address { street: string, ... }
  name: string
  fields: { name: string; type: string }[]
}

type ValueType =                   // 3.0 attribute value types — exhaustive
  | "boolean" | "integer" | "double" | "decimal"
  | "string"  | "date"    | "datetime" | "datetime-tz" | "duration"
  | { struct: string }             // user-defined struct
type AttrValueType = {
  type: ValueType
  list: boolean                    // 3.x: `value string[]` → list:true
}

type Attribute = {
  name: string                     // "aid"
  abstract: boolean                // @abstract — declares a base attribute hierarchy
  sub?: string                     // 3.x: attributes form their own hierarchy (e.g. `attribute email sub id`)
  valueType?: AttrValueType        // optional only when @abstract (parent declares type)
  annotations: AttrAnnotation[]    // typed list — see below
  comment?: string
}

type AttrAnnotation =
  | { kind: "key" }                                // @key
  | { kind: "unique" }                             // @unique
  | { kind: "subkey"; group: string }              // @subkey("composite")
  | { kind: "card"; min: number; max: number|null }// @card(N..M); null = unbounded
  | { kind: "values"; values: string[] }           // @values("a","b","c") → TS enum
  | { kind: "range"; min: number; max: number }    // @range(0..100) → Zod min/max
  | { kind: "regex"; pattern: string }             // @regex("...")    → Zod regex
  | { kind: "distinct" }                           // @distinct (list owns)
  | { kind: "independent" }                        // @independent (attr survives unowned)
  | { kind: "cascade" }                            // @cascade (delete behavior on relations)
  | { kind: "index" }                              // @index (planner hint; no codegen impact)
  | { kind: "abstract" }                           // @abstract

type AttrOwnership = {             // how an entity/relation owns an attribute
  attribute: string
  annotations: AttrAnnotation[]    // ownership-site annotations (@key, @card on the owns line)
}

type Entity = {
  name: string                     // "actor"
  abstract: boolean                // @abstract
  sub?: string                     // parent entity — 3.x: subtypes inherit owns + plays
  owns: AttrOwnership[]
  plays: RoleRef[]                 // { relation: "signal", role: "sender" }
  comment?: string
}

type Relation = {
  name: string
  abstract: boolean
  sub?: string                     // parent relation; subrelation can role-alias
  roles: Role[]
  owns: AttrOwnership[]
  comment?: string
}

type Role = {
  name: string                     // "sender"
  cardinality?: { min: number; max: number|null }  // @card on the relates line
  cascade: boolean                 // @cascade on the role
  index: boolean                   // @index on the role
  alias?: { of: string }           // 3.x: `relates author as subject` → alias.of = "subject"
}

type Fn = {
  name: string                     // "ancestors-of"
  params: { name: string; type: string }[]
  returnType:
    | { kind: "scalar"; types: string[] }          // -> integer:  | -> boolean: | -> unit:
    | { kind: "stream"; types: string[] }          // -> { user }:                  (single type in {})
    | { kind: "tuple";  types: string[] }          // -> string, integer:           (multiple scalars)
  body: string                     // opaque — used only to detect changes
  file: string                     // "patterns/substrate.tql"
}
```

Notes on the IR:

- **No `Skin` type.** Skins use plain `sub` — `entity sprint sub group` produces a normal entity in IR with `sub: "group"`. Codegen reads the inheritance chain to generate `Sprint extends Group` in TypeScript. This is much cleaner than my first draft's "skin extends" merge logic, and it matches what `schema/skins/engineering.tql` actually does.
- **Attributes can be abstract and form hierarchies.** `attribute id @abstract, value string;` followed by `attribute email sub id;` means a polymorphic fetch on `$x.id` returns email values too. Codegen generates a `id` union type covering all subtypes.
- **Cross-file entity extension.** `engineering.tql` does have lines like `entity actor, owns engineering-level;` referring to an entity defined in `one.tql`. TypeDB merges these additively when both files are loaded into the same schema; parser unions the `owns` lists across all files for the same entity name. This is the rarer mechanism; subtyping is preferred.

`ir.json` is committed. Two runs of `parse → ir` on unchanged input must produce byte-equal output (after stripping `generatedAt`). This is the deterministic contract that makes CI drift-checking meaningful.

---

## Annotations — most codegen mappings are NATIVE TypeQL

Earlier draft proposed `# @zod:`, `# @discriminator:` comment directives. **Most of these were unnecessary** — TypeQL 3.0 already has the annotations. Use them directly.

| Codegen need | Use this TypeQL 3.0 annotation | Generated Zod | Generated TS |
|---|---|---|---|
| Enum values | `@values("skill","task","token","service")` | `z.enum([...])` | string literal union |
| Numeric range | `@range(0..100)` | `z.number().min(0).max(100)` | `number` |
| Regex constraint | `@regex("^...")` | `z.string().regex(...)` | `string` |
| Required, primary key | `@key` | `.uuid()` if hint says so, otherwise required string | required field |
| Optional, unique | `@unique` | optional + unique-in-context note | `T \| undefined` |
| Multi-cardinality | `@card(0..)`, `@card(1..3)` | `z.array(T).min(N).max(M)` | `T[]` |
| Cannot instantiate | `@abstract` | no `.parse()` factory exposed | `abstract class` / type alias only |
| Survives unowned | `@independent` | regular schema | D1: separate table |
| Composite key | `@subkey("group_name")` | builds tuple key in IR | tagged in generated docs |

**Three minimal comment directives remain** (for codegen-only concerns TypeQL can't express):

```typeql
# @doc: docstring captured verbatim into the generated type's JSDoc
attribute auth-hash, value string;

# @discriminator
# Marks the attribute as the discriminator for a polymorphic entity. Codegen
# uses this + @values on the same attribute to emit a discriminated union.
attribute thing-type, value string @values("skill","task","token","service");

# @d1-skip
# Exclude this attribute from generated D1 mirror DDL. Use for large blobs (prompt
# bodies, embeddings) that should stay in TypeDB only.
attribute prompt, value string;
```

That's the entire directive surface. Three directives total. Everything else is native TypeQL.

Codegen ignores any unrecognized `#` line. Unknown directives are passed through silently — `.tql` stays portable to any TypeQL 3.0 consumer.

---

## The 6 waves

Each wave has: deliverable, exit scalar, what gets deleted.

### Wave 0 — Parser + IR (the keystone)

**Deliverable:**
- `schema/codegen/parse.ts` — recursive-descent parser for the full TypeDB 3.0 DEFINE-level grammar (see *Appendix A* for exhaustive feature list)
- `schema/codegen/ir.ts` — AST → IR transformer
- `schema/codegen/ir.json` — committed snapshot
- `schema/package.json` — `bun run codegen` script

**Exit scalar:**
1. `bun run codegen` produces `ir.json` byte-equal to committed copy (modulo `generatedAt`).
2. Two consecutive runs identical.
3. Parser handles every `.tql` file currently in `schema/` without throwing (1 base + 7 supporting + 10 patterns + 3 skin/skins files + 2 migrations — verify with `find schema -name "*.tql" | xargs ...`).
4. Round-trip: re-emitting IR as canonical TypeQL produces a file that re-parses to byte-equal IR (catches lossy fields early).

**Deletes:** nothing yet — parser is purely additive.

**Files:** `schema/codegen/parse.ts`, `ir.ts`, `codegen.ts`, `ir.json`, `package.json` (new), `tsconfig.json` (new), `parse.test.ts` (every `.tql` fixture as a test case).

---

### Wave 1 — Zod schemas + TS types (one stone, two birds)

**Deliverable:**
- `schema/codegen/targets/zod-schemas.ts` — IR → Zod schemas
- Generated output at `packages/sdk/src/generated/schemas.ts`
- TS types come free via `z.infer<typeof GroupSchema>`
- Each entity gets: `<Name>Schema` (runtime), `<Name>` (inferred type)
- Constraints from `@key`, `@card`, `@unique`, `# @zod:` hints are applied

Example generated output:
```typescript
// AUTO — schema/codegen/targets/zod-schemas.ts — do not edit
import { z } from "zod";

export const GroupSchema = z.object({
  gid: z.string().uuid(),                  // @key + @zod: .uuid()
  name: z.string(),
  groupType: z.enum(["world","friends","team","community","org","dao","personal"]),
  // ... 8 more
});
export type Group = z.infer<typeof GroupSchema>;
```

**Exit scalar:**
1. `cd schema && bun run codegen` produces `packages/sdk/src/generated/schemas.ts` byte-equal across runs.
2. `cd packages && bun run build` green — no type errors when SDK code switches one import (e.g. `Group`) from `src/types.ts` to `src/generated/schemas.ts`.
3. Round-trip test: parse a real Group object with generated schema → succeeds.

**Deletes:** the hand-written `Group`, `Actor`, `Thing`, `Signal` interfaces from `packages/sdk/src/types.ts`. Wrapper types like `SignalResponse`, `MarkResponse`, `Outcome<T>` stay hand-written (they describe wire shapes, not entities).

**Files:** `schema/codegen/targets/zod-schemas.ts`, `packages/sdk/src/generated/schemas.ts`, edits to `packages/sdk/src/index.ts` (re-export from generated).

---

### Wave 2 — OpenAPI components

**Deliverable:**
- `schema/codegen/targets/openapi.ts` — IR → OpenAPI `components.schemas`
- Generated at `one.ie/web/public/openapi.generated.yaml`
- `one.ie/web/public/openapi.paths.yaml` — hand-written paths only (NEW; split from current openapi.yaml)
- Build step merges `paths` + generated `components` → `openapi.yaml` (current consumer path unchanged)

The split honors the architectural truth: **what types exist** comes from `.tql`; **which endpoints exist** is a curated API surface decision humans make.

**Exit scalar:** Build merger produces the current `openapi.yaml` byte-equal (modulo formatting) when paths are unchanged. Existing `openapi-typescript` consumers see no API change.

**Deletes:** component-schema sections in the hand-written openapi.yaml. Paths block extracted to `openapi.paths.yaml`.

**Files:** `schema/codegen/targets/openapi.ts`, `one.ie/web/public/openapi.generated.yaml` (new), `one.ie/web/public/openapi.paths.yaml` (new, extracted), `one.ie/web/scripts/merge-openapi.ts` (new).

---

### Wave 3 — Pattern bindings

**Deliverable:**
- `schema/codegen/targets/pattern-bindings.ts` — IR → typed SDK methods, one per `fun`
- Generated at `packages/sdk/src/generated/patterns.ts`
- `api/src/routes/fn.ts` — generic `/api/fn/:name` handler executes named TypeQL function with typed inputs

Example generated output:
```typescript
// AUTO — schema/codegen/targets/pattern-bindings.ts
import type { SubstrateClient } from "../client.js";
import type { Group, Hypothesis } from "./schemas.js";

export async function ancestorsOf(
  client: SubstrateClient,
  g: string                            // gid
): Promise<Group[]> {
  return client.fn("ancestors-of", { g });
}

export async function actionableHypotheses(
  client: SubstrateClient
): Promise<Hypothesis[]> {
  return client.fn("actionable-hypotheses", {});
}
// ... ~50 more (everything in patterns/*.tql)
```

**Exit scalar:** All 50+ `fun` signatures in `schema/patterns/` and `schema/one.tql` produce typed SDK wrappers. `/api/fn/:name` route returns the typed shape declared in the `fun`'s `-> {T}` return clause for at least 3 representative patterns (a single-return, a set-return, a scalar-return).

**Deletes:** nothing — patterns are net-new SDK surface.

**Files:** `schema/codegen/targets/pattern-bindings.ts`, `packages/sdk/src/generated/patterns.ts`, `api/src/routes/fn.ts`, `api/src/typedb/exec-fn.ts`.

**Return-type mapping (3.0 → TS):**

| TypeQL 3.0 return | Generated TS |
|---|---|
| `-> integer:` (with `return first $x;`) | `Promise<number>` |
| `-> double:` / `-> decimal:` | `Promise<number>` |
| `-> boolean:` | `Promise<boolean>` |
| `-> string:` | `Promise<string>` |
| `-> { user }:` (with `return { $x };`) | `Promise<User[]>` |
| `-> string, integer:` (tuple) | `Promise<[string, number]>` |
| `-> { string, integer }:` (tuple stream — `world.tql:actual_workflow`) | `Promise<[string, number][]>` |

---

### Wave 4 — D1 mirror migrations (CANDIDATE generator only)

**Deliverable:**
- `schema/codegen/targets/d1-mirror.ts` — IR → SQL DDL candidates
- Output: `one.ie/web/migrations/_candidates/<timestamp>_<entity>.sql`

**Critical:** the generator emits **candidates marked `-- AUTO from schema vX`**, not migrations. Humans review, rename to a numbered slot (e.g. `0049_actor_mirror.sql`), and apply. Existing 48 migrations stay hand-written history.

Why not full automation: D1 is an operational mirror with append-only event tables, indices on hot read paths, and operational concerns (rate limit counters, billing state) that have no analog in `.tql`. Schema-driven generation produces table shapes; humans add the indices and event tables.

**Exit scalar:** generator produces SQL for at least 3 entities (actor, thing, group) that, applied to a fresh D1, materializes the schema's value-types correctly. Hand-written existing migrations untouched.

**Deletes:** nothing.

**Files:** `schema/codegen/targets/d1-mirror.ts`, `one.ie/web/migrations/_candidates/.gitignore` (ignore SQL until renamed).

---

### Wave 5 — Skin support (where this pays for itself)

**Deliverable:**
- `schema/codegen/targets/skin-types.ts` — IR + skin overlays → per-skin TS modules
- Generated at `packages/sdk/src/generated/skins/<name>.ts`

Example (engineering skin):
```typescript
// AUTO — from schema/skins/engineering.tql
import type { Group, Thing, Actor } from "../schemas.js";

export type Sprint = Group & { groupType: "sprint" };
export type Epic = Group & { groupType: "epic" };
export type Story = Thing & { thingType: "task"; taskType: "story" };
export type Bug = Thing & { thingType: "task"; taskType: "bug" };

export function asSprint(g: Group): Sprint | null {
  return g.groupType === "sprint" ? (g as Sprint) : null;
}
// ... per-skin functions from skin's `fun` blocks
```

**Exit scalar:** `skins/engineering.tql` and `skins/marketing.tql` each produce a generated module that compiles. A consumer can write:
```typescript
import { Sprint, asSprint } from "@oneie/sdk/generated/skins/engineering";
const sprint = asSprint(group); // null if not a sprint
```

**Deletes:** any hand-written domain-vocabulary types that duplicate skin definitions.

**Files:** `schema/codegen/targets/skin-types.ts`, `packages/sdk/src/generated/skins/engineering.ts` (and per skin).

---

## Workflow — what changes for contributors

**Today:** edit `.tql`, separately edit `sdk/types.ts`, separately edit `openapi.yaml`. Hope they agree.

**After Wave 1:**
```bash
# 1. Edit the schema
$EDITOR schema/one.tql

# 2. Regenerate (one command, touches sibling repos)
cd schema && bun run codegen

# 3. Review diffs in each repo, commit
cd ../packages && git diff && git add -A && git commit -m "regen from schema v$X"
cd ../one.ie    && git diff && git add -A && git commit
cd ../api       && git diff && git add -A && git commit
cd ../schema    && git add -A && git commit -m "feat: <what>"
```

**CI gate in each consumer repo:**
```bash
# fails PR if committed generated files have drifted
cd ../schema && bun run codegen && cd - && git diff --exit-code packages/sdk/src/generated/
```

This catches: "I edited `schema/one.tql` but forgot to regen" AND "I hand-edited a generated file."

---

## Hardest parts (honest)

1. **Discriminated unions.** `thing` has `thing-type` ∈ {`skill`, `task`, `token`, `service`} with task-only fields (`task-status`, `task-effort`). TypeDB models these as nullable attributes; TypeScript wants `Skill | Task | Token | Service`. Solution: `# @discriminator: thing-type` annotation, plus `# @when: thing-type=task` on task-specific attributes. Codegen produces a union type.

2. **Function return-type binding.** `fun ancestors-of($g: group) -> { group }` returns a set of groups. Easy. But `-> double` returns a scalar — codegen must emit `Promise<number>`. And `-> integer` → `Promise<number>` (TypeScript has no integer). Mapping table in the generator.

3. **Skin merging.** When `skins/engineering.tql` says `entity actor, owns engineering-level`, this must MERGE into base actor in IR — not be a separate type. TypeDB's `define` syntax allows redefinition; parser must collect all `entity actor, ...` blocks across files and union their `owns` lists.

4. **The `openapi.yaml` split.** Current openapi.yaml is one file containing both paths and components. Wave 2 splits it. The merger script must produce byte-equal output for the unchanged case, or every existing test that compares the file breaks. Mitigation: format normalization step.

5. **Function body change detection.** The IR stores `fun.body` as an opaque string. If a body changes (e.g. `ancestors-of` logic edited), should that count as a "schema change"? Answer: yes, version it. The IR's `version` field is a content hash of all input `.tql` files — body changes bump it; consumers see drift and review.

---

## What we explicitly DON'T generate

| Thing | Why hand-written |
|---|---|
| API path handlers in `one.ie/web/src/pages/api/*` | Business logic. Generators produce types; humans wire routes. |
| API path *list* in OpenAPI | Curated public surface. Not every entity is exposed; not every endpoint matches one entity. |
| Existing D1 migrations | History. Past is past. |
| D1 event tables, rate-limit counters, billing state | Operational, not graph-shaped. No `.tql` analog. |
| UI components | Far downstream of types. |
| Test fixtures | Hand-written; can reference generated schemas. |
| The wire format itself (response wrappers like `SignalResponse`, `Outcome<T>`) | Wire shape decisions live in SDK, not schema. |

---

## Risks

| Risk | Mitigation |
|---|---|
| Parser misses a TypeQL 3.x grammar feature we use | Add to `schema/codegen/parse.test.ts` per feature. Fixture every `.tql` file in the repo as a parser-must-handle case. |
| Generated files drift silently when humans hand-edit them | CI gate: regen and `git diff --exit-code`. Generated file headers say `do not edit by hand`. |
| Skin merge order ambiguity (which file wins?) | Deterministic order: `one.tql` first, then `skins/*.tql` alphabetical, then `migrations/*.tql` numerical. Document in `schema/codegen/README.md`. |
| Annotation directives become a parallel grammar | Keep them minimal — `@zod`, `@discriminator`, `@when`, `@d1` only. Adding a 5th requires a plan amendment. |
| Generated `pattern-bindings.ts` becomes huge as `fun` count grows | Split per source file: `generated/patterns/substrate.ts`, `generated/patterns/hypothesis-lifecycle.ts`, etc. Wave 3.1. |

---

## Success — what "this is done" looks like

After all 5 waves:

- `schema/one.tql` + `schema/skins/*.tql` + `schema/patterns/*.tql` are the **only** places humans declare data shapes
- `packages/sdk/src/generated/` is 100% machine-output, version-controlled, never hand-edited
- `one.ie/web/public/openapi.yaml` is `openapi.paths.yaml` (curated) + generated components
- New entity / attribute / function: edit one `.tql` file, run `bun run codegen`, commit the diff fan-out across sibling repos
- Domain customers (engineering, marketing, education) get typed DSLs via skins without touching SDK source
- CI prevents drift in every consumer repo

**A measurable cutover indicator:** `wc -l packages/sdk/src/types.ts` drops from 560 → <100 (only wire-format wrappers remain). Today: 560. Wave 1 target: ≤200. Final: ≤80.

---

## Next action

Wave 0 — parser + IR. Two-file build (`parse.ts`, `ir.ts`) + committed `ir.json`. No consumer touched. Lands in `schema/` only.

When Wave 0 passes its exit scalar, the rest is template walks over a stable IR.

---

## See also

- [dictionary.md](dictionary.md) — canonical names for everything `.tql` declares
- [aisdk.md](aisdk.md) — style template for this plan's structure
- `schema/one.tql` — current source
- `schema/patterns/` — every `fun` we'll wrap in Wave 3
- `schema/skins/engineering.tql` — the DSL pattern that makes Wave 5 the point of the whole thing
- `packages/sdk/scripts/generate-types.ts` — the existing generator (OpenAPI-based) that this plan retires
- `.claude/skills/typedb/SKILL.md` — TypeDB 3.0 reference; the source of grammar truth for Appendix A

---

## Appendix A — TypeQL 3.0 DEFINE-level grammar surface

Exhaustive list of features the parser must handle. Sourced from `/typedb` skill (verified TypeDB 3.0). Anything not in this list is out of scope — the parser may reject, but should never silently mis-parse.

### Top-level statements

```typeql
define   ...               # add to schema
undefine ...               # remove from schema (Wave 0 parser: recognize, IR-record)
redefine ...               # modify single element  (Wave 0 parser: recognize, IR-record)
```

### Type declarations

```typeql
entity NAME [@abstract] [sub PARENT] [, OWNS_CLAUSE | PLAYS_CLAUSE]* ;
relation NAME [@abstract] [sub PARENT] [, RELATES_CLAUSE | OWNS_CLAUSE]* ;
attribute NAME [@abstract] [sub PARENT] [, value TYPE] [, ATTR_ANN]* ;
struct NAME { FIELD: TYPE, FIELD: TYPE, ... } ;
fun NAME(PARAMS) -> RETURN_TYPE : BODY                # BODY is opaque to parser
```

### Owns/plays/relates clauses

```typeql
owns ATTR_NAME [ATTR_ANN]*          # attribute ownership; site-level annotations
plays REL_NAME : ROLE_NAME          # role playing
relates ROLE_NAME [as PARENT_ROLE] [ROLE_ANN]*   # role definition; supports aliasing
```

### Value types (3.0 — exhaustive)

| Token | TS mapping |
|---|---|
| `boolean` | `boolean` |
| `integer` | `number` (note: 2.x had `long` — gone) |
| `double` | `number` |
| `decimal` | `number` (or string if precision matters; codegen flag) |
| `string` | `string` |
| `date` | `string` (ISO `YYYY-MM-DD`) |
| `datetime` | `string` (ISO `YYYY-MM-DDTHH:MM:SS`) |
| `datetime-tz` | `string` (ISO with offset) |
| `duration` | `string` (ISO 8601 duration) |
| `TYPE[]` | `T[]` — list attribute (3.x only) |
| `<struct-name>` | generated struct type |

### Attribute annotations (exhaustive — all 12)

| Annotation | Where | Codegen behavior |
|---|---|---|
| `@abstract` | attribute decl | mark hierarchy parent; cannot directly own value |
| `@key` | owns line | required, primary unique key |
| `@unique` | owns line | optional, unique across owners |
| `@subkey("group")` | owns line | composite key participant |
| `@card(N..M)` | owns line | cardinality bounds → array shape |
| `@values("a","b",...)` | attribute decl | enum / string literal union |
| `@range(N..M)` | attribute decl | numeric bounds |
| `@regex("...")` | attribute decl | string pattern |
| `@distinct` | owns line (list) | unique-elements list |
| `@independent` | attribute decl | survives without owner — D1: own table |
| `@cascade` | relates role | delete cascades to relation |
| `@index` | relates role | planner hint; no codegen |

### Function return-type grammar (3.0)

```
fun NAME(...) -> integer:           # scalar (single value)
fun NAME(...) -> { user }:          # stream (set)
fun NAME(...) -> string, integer:   # tuple (multiple scalars)
fun NAME(...) -> { string, integer }: # tuple stream (set of tuples)
```

Body uses `return first $x;` (scalar), `return { $x };` (set), or `return first $a, $b;` (tuple). Parser does NOT interpret the body — captures it as opaque string for change detection.

### Inheritance behaviors (3.0)

- **Entities**: `entity B sub A` inherits A's `owns` and `plays`. B can add more.
- **Relations**: `relation B sub A` inherits A's `relates`. B can add roles AND alias inherited roles via `as`.
- **Attributes**: `attribute email sub id` puts email under id's hierarchy. Polymorphic fetch on `$x.id` returns email values.
- **Cross-file extension**: when two files both `define entity actor, owns ...`, TypeDB unions the `owns` lists. Parser must support this (parse each file independently, IR merger unions across files).

### What the parser does NOT touch

Per Decision 1 — parser stops at the function-body boundary. These are passed through as opaque strings:

- `match ... select ...` clauses
- `match ... insert ...` clauses
- `match ... delete ...` clauses
- `fetch { ... }` clauses
- `reduce`, `sort`, `limit`, `offset`, `distinct` stages
- Pipeline chains in function bodies

The parser captures every `fun`'s signature (name, params, return type) and stores the body text. Body changes bump the IR version hash; that's the only "interpretation" needed.

### Out of scope for Wave 0 (revisit in later waves)

- `with fun ...` ad-hoc function definitions (query-level, not schema-level)
- TypeDB Cloud authentication / connection config (`.env`, secrets) — codegen reads files, not the DB

---

## Appendix B — Verification log

Each plan claim independently checked against the `/typedb` skill (TypeDB 3.0 reference):

| Claim | Status | Notes |
|---|---|---|
| Value types include `string|long|...|json` | ❌ corrected | 3.0 uses `integer` not `long`; no `json` (have `struct` and lists instead) |
| Annotation set is `@key, @card, @unique` only | ❌ corrected | 12 annotations exist; many replace custom `# @zod:` hacks |
| Function returns are set OR single | ❌ corrected | Three variants: scalar, stream, tuple — plus tuple-stream |
| Skin merge requires custom additive logic | ❌ simplified | Skins use plain `sub` (subtyping). `engineering.tql` confirmed via `entity sprint sub group` |
| Subtyping works on entities only | ❌ corrected | Works on entities, relations, AND attributes |
| Subrelations can rename roles via `as` | ✅ added | `relates author as subject` is a real 3.x feature |
| Parser ignores function bodies | ✅ kept | Correct decision; bodies are opaque |
| Hand-written parser is the right choice | ✅ kept | The DEFINE-grammar subset is bounded and stable |
| `# @directive:` hints needed for codegen | ⚪ reduced | Three directives kept (`@doc`, `@discriminator`, `@d1-skip`); rest replaced by native annotations |
