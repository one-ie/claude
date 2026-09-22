---
paths:
  - "text/**/*.md"
  - "**/*-todo.md"
  - "**/*-plan.md"
  - "**/*-docs.md"
  - ".claude/commands/do*.md"
---

# Documentation Rules

Apply to all TODOs and `/do` workflows.

**Principle:** Docs are the spec, written **first**. The feature's doc set is authored at the **DOCS** stop — *before* any code — in the reader's language, and the tests are drawn from it. The docs are then the **acceptance oracle**: PROVE validates the shipped thing against them, and TEACH reconciles any drift so every doc ends true.

**Upstream of the doc set sits the promise** — `text/<slug>.md`, the genesis contract, written like the statement of work an engineering agency signs with a client, with **four** machine-read manifests: `deliverables:` (the exhaustive schedule of work — every item the client receives, each with its own `accept:` check; not listed = not promised, listed = ships or the promise settles broken, acceptance indivisible; `assumes:` lists client-side dependencies, green at the making), `proof:` (the acceptance test — derived, not authored: the `&&`-join of every `accept:`; it becomes the todo's `outcome:`, the TEST assertion, the PROVE oracle, and the on-chain settlement condition; the schedule ⇄ proof law is gated by `.claude/scripts/do-promise-lint.sh`), `derives:` (which artifacts the promise spawns — `/do` reads it to know which doc stops to backfill), and `world:` (the runtime a kept promise puts into the substrate — lifecycle moves, workflow steps, agents + `subscribes:` tags, skills, task tags, tracking marks/warns, routing paths, views). Every `world:` entry is **presence-checked like an artifact**: missing agent → `template-agent.md` cycle + `subscriptions:register` · missing skill → `/skill-creator` · missing workflow/lifecycle stage → a todo cycle · missing view kind/route (`one.ie/web/src/lib/views/registry.ts` + the order-free traversal) → a todo cycle · present → skip. The covenant behind the mechanism: `text/promises.md`. Every doc reconciles upward to the promise — a doc claim that contradicts it is a bug in the doc. Full contract: `.claude/commands/do.md` § "PROMISE first".

Within a build cycle this still maps to three phases: **W2** declares which docs this cycle touches (the spec already exists; W2 lists the deltas), **W3** edits docs alongside code in the same wave, **W4** verifies consistency *and truth* against the shipped behaviour. The difference from before: the full doc set is not seeded-then-refined — it is written for real up front, and the cycle keeps it in sync and proves it true.

## Promises grow with delivery (always update the promise with what shipped)

**When you ship a feature that extends an already-kept promise — a new view, capability, or surface under the same banner — you MUST append it to that promise as a new `deliverable:` with its own `accept:` check, and extend the `proof:` `&&`-join to include that check.** This is not optional polish; it is what keeps the promise a record the system can depend on. A promise that silently omits shipped work is a promise that lies about the delivery, and the router that sells the next signal to the proven path is reading a stale contract.

The covenant's freeze (clause 4, `text/promises.md`) permits this because it is a **monotonic ratchet** — the same "can't regress" DNA `/do` runs on:

- **Allowed (do it every time):** append a deliverable whose `accept:` is **already green**, and add that exact `accept:` string to `proof:`. The join stays exit-0; the record only rises. No new `terms_hash` needed — nothing that was promised changed.
- **Forbidden (needs a *new* promise):** anything that would make the existing proof go **red** — weakening a check, removing a line, reversing a decision, or a broken `assumes:`. That's a regression, not growth.

Checklist when extending a kept promise `text/<slug>.md`:

1. Add the `- item:` + `accept:` row under `deliverables:` (group fulfilled follow-ons under a dated comment).
2. Append the identical `accept:` body to `proof:` (the schedule ⊆ proof law — `do-promise-lint.sh` enforces verbatim inclusion).
3. Add any new `world:` entries (a new view → `views:`, a new workflow step → `workflow:`).
4. Add the human-readable row to the deliverables table in the prose, and reconcile any now-stale status claim (e.g. an "X is still red / not shipped" line for the thing you just shipped).
5. Run `bash .claude/scripts/do-promise-lint.sh <slug>` — it must report `schedule ⊆ proof, contract well-formed` **and** every `assumes:` green. Fix any stale `assumes:` path while you're there (a moved file makes the whole contract un-signable).

The same discipline applies to the propagate matrix below: the promise is the first row every close reconciles, before its derived docs.

**Format:** any ASCII diagram written into a doc follows `text/CLAUDE.md § ASCII diagrams` — max ~60 chars wide, vertical flow over multi-column tables. A diagram that's fine in a wide terminal wraps into garbage in the narrow panels these docs actually get read in.

---

## The Three Phases

### **W2 — Planning Phase: Document the Plan**

Before any code is written, explicitly list which docs will change:

```markdown
### Documentation Updates (W2)

**New docs:**
- `text/feature.md` — {purpose}

**Docs modified:**
- `text/dictionary.md` — add term {name}
- `text/routing-plan.md` — update loop L{N}
- `text/rubrics.md` — add dimension {name}

**Schema changes:**
- New TypeDB entities, D1 migrations, TypeQL functions
```

**Why:** Naming decisions, API design, and lifecycle implications must be documented before code is written. The docs ARE the spec.

---

### **W3 — Edit Phase: Update Docs + Code in Parallel**

**Docs are a required W3 layer** — W2 declares which docs will change in `.w2-doc-plan.json`, and W3 applies those changes in the same W3a wave as code edits. Docs edits are spawned as parallel agents alongside code, not sequentially after.

**For every code file edited, edit the corresponding doc (always in W3a, never W3b):**

| Code File | Related Doc | What to add/update |
|-----------|-------------|---|
| `src/types/foo.ts` (new file) | `text/dictionary.md` | Add term: `Foo:` definition + field breakdown |
| `src/pages/api/foo.ts` (new route) | `text/lifecycle.md` | Add stage: when agent/operator uses this route, what they get |
| `src/components/foo/Foo.tsx` (new component) | Feature doc (`text/<feature>-plan.md`) | Add section: component purpose, props, slots, states |
| `migrations/0042_foo.sql` (schema change) | `text/one-ontology.md` | Add/update entity: new type or attribute; which actor reads it |
| `packages/sdk/src/index.ts` (new export) | `text/dictionary.md` | Ensure exported types are documented |
| Feature-wide changes | `text/<feature>-plan.md` | Update: add lifecycle section, API shapes, example usage, when/why to use |

**Pattern:** If you're adding a new field to a TypeScript interface, add it to the doc that defines that interface. If you're adding a new route, document when an operator/agent calls it and what they get back. If you're changing data structure, update the type definition in the dictionary.

**Critical rule:** Never commit code without corresponding doc edits in the same W3a wave. The W3a message spawns code-edit agents AND doc-edit agents together. A code change with no doc update is an incomplete feature and fails W4.

---

### **W4 — Verify Phase: Check Docs Match Code**

**Docs consistency checklist:**

1. **Terminology** — All renamed concepts updated everywhere
   ```bash
   grep -r "old-name" text/ -- ignore new-name where intentional (dead names)
   ```

2. **Examples** — Code examples in docs match actual implementation
   ```
   - TypeScript interfaces in examples match src/types.ts
   - TypeQL in examples match src/schema/*.tql
   - Function signatures match actual exports
   ```

3. **Cross-references** — Links don't 404
   ```
   - [dictionary.md](dictionary.md) exists and links back to source
   - Code file references match real paths (no moved files)
   ```

4. **Metaphor consistency** — 7-skin mappings still valid
   ```
   - Ant: pheromone/strength/resistance → brain: synapse/weight
   - Team: signal/mark → org: decision/approval
   - Check metaphors.md if touching path/signal semantics
   ```

5. **Rubric dimensions** — New quality scoring documented
   ```
   - If W4 adds a rubric dimension (e.g., "documentation"), it goes in rubrics.md
   - Scoring rules and edge cases documented
   ```

---

## Which Docs Are Always in Scope

These six docs are the **source of truth** and must stay in sync with code:

| Doc | Locks | Update when |
|-----|-------|-------------|
| **dictionary.md** | Canonical names, types, entities | Any naming change |
| **DSL.md** | Signal grammar, mark/warn/fade verbs | Signal behavior changes |
| **one-ontology.md** | 6 dimensions, actor/group/thing/path/signal/hypothesis | Type system changes |
| **routing.md** | L1-L7 loops, signal flow, priority formula | Loop/routing changes |
| **lifecycle.md** | Agent journey stages, revenue flow | Lifecycle/economic changes |
| **rubrics.md** | Code rubric (the design target — eight dims) + agent rubric (fit/form/truth/taste). Live weights are data at `.claude/scripts/rubric-weights.json`; the gap between the two is `text/rubric-migration-plan.md` | Rubric changes or new dimensions |

**Feature-specific docs** (rich-messages.md, webhooks.md, etc.) are updated per feature. Always link back to the six core docs.

---

## Rules for `/do` (The Command)

When running `/do {name}-todo.md`, the workflow enforces:

1. **W2 must explicitly call out doc changes** — no surprise doc edits in W3
2. **W3 spawns edit agents for both code AND docs** — parallel edits
3. **W4 includes doc consistency check** — not just code tests
4. **The code rubric applies to docs too**, reading each axis for prose — simplicity means fewer words; stability means no broken links and accurate references; security means no sensitive data exposed; integration means every doc is linked from its family and lies about nothing shipped; speed means lean docs = fewer tokens to read. (Axis names and weights: `.claude/scripts/rubric-weights.json`. Note the doc reading of *stability* — links and references — is not the code reading — error handling and closed loops; same name, two criteria, which is exactly why the eight-dim migration splits it.)

---

*Documentation is not a post-mortem. It's the blueprint. Build it first. Verify it matches.*

---

## Loop Close — propagate matrix (inlined, no separate file)

`/close` runs this matrix automatically after rubric + feedback signal. Each row is a bash + Edit-tool dispatch, zero agent spawns.

| Trigger (detected from W3 diff) | Target doc | Edit |
|---|---|---|
| feature extends an already-kept promise | that `text/<slug>.md` promise | **first row, always** — append the fulfilled deliverable + its green `accept:`, extend `proof:`, add `world:` entries, then `do-promise-lint.sh <slug>` must pass (see § Promises grow with delivery) |
| slug has `text/<slug>-agents.md` (a verification walk exists) | `.claude/scripts/do-walk.sh <slug> --agents` | run it — must exit 0; a promise extension that added a deliverable but no matching walk stop is an incomplete close, append the stop to both `-humans.md` and `-agents.md` before the cycle closes |
| any change | source-of-truth doc(s) from plan frontmatter | always — even if only touch-verified |
| 6-dim, L1-L8, or locked-rule change | root `CLAUDE.md` | edit the relevant section |
| directory contract change (new component family, new pattern) | nearest `CLAUDE.md` (e.g., `one.ie/web/src/components/CLAUDE.md`) | append / edit section |
| public surface change (new CLI verb, API route family, SDK export, MCP tool) | root `README.md` + feature doc | append row(s) |
| feature doc named in plan | feature doc | sync verb/component/endpoint counts |
| rename across W3 | every `**/*.md` containing old name | inline replace (auto-grep) |

Anchor mismatch → log to `text/improvements.md` for manual W2 next cycle (no halt — the cycle still closes; the propagate task surfaces next iteration).

**Learnings entry** (append to `text/learnings.md` on each close):

```
- YYYY-MM-DD · cycle N · wave N|gate · {one sentence} · rubric=0.NN [sec.NN simp.NN struct.NN speed.NN integ.NN reuse.NN test.NN ux.NN] · source=w1|w2|w3|w4|cycle

The `[...]` eight-field vector is self-labeling and appended, never replacing the
composite — see `text/rubrics.md` § Code Rubric for the eight dimensions and the
per-field scoring rules. A close with no per-dimension breakdown to hand may omit
the vector (old form still parses; counts toward the composite trend only).
```

W4 code rubric applies to docs too: security (no sensitive data), stability (no broken links, accurate references), simplicity (fewer words, no bloat), speed (lean = fewer tokens to read).

### W4 doc-sync hard gate (zero LLM)

W4 must pass four bash checks before the rubric runs. Detail in `.claude/commands/do.md` W4 section. Summary:

1. **stale-name check** — every old identifier in W3's rename list has 0 hits in `**/*.md`
2. **broken-link check** — `markdown-link-check` on every touched doc returns 0 broken. **It is not installed** (`command -v markdown-link-check` → nothing), so this check cannot pass today. Report it `n/a`, never `ok` — an absent tool is an unrun check, not a green one. Install it or replace it with a resolve-every-relative-link grep; do not let it silently vanish.
3. **contract-staleness check** — every dir whose code was touched has `CLAUDE.md` mtime ≥ newest code mtime
4. **shipped-status check** — the just-built slug's own `text/<slug>-plan.md` / `-docs.md` must not still claim the feature is unbuilt:
   ```bash
   grep -liE 'design doc \(not an armed|not yet built|^not shipped|is the A2A follow-on|durable.*follow-on, not' text/<slug>-plan.md text/<slug>-docs.md 2>/dev/null
   ```
   A hit on the plan that was *just built* is a doc that lies about what shipped → reconcile the phrase (or, if it genuinely refers to a separate future item, reword so it can't be confused with the shipped thing). This is the recurring drift (3/3 runs eve-C5 · remote-durable · remote-suspend): a feature-extension cycle ships the capability but leaves "X is the follow-on / not shipped" in its own plan/docs/code-headers. Catches the status-claim drift that #1 (names) and #2 (links) don't.

Any fail → cycle does NOT close. No rubric until docs match code.
