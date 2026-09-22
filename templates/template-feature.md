<!--
TEMPLATE — THE ROOT DOCUMENT: a story, and the contract it commits to.
Copy to text/<slug>.md, fill, delete this comment.
Owner: writer skill. THE STORY IS THE TOP-LEVEL DOCUMENT. This is the FIRST
file; everything else (-plan, -todo, -docs, tests, code) is derived from it and
must reconcile UPWARD to it.

Fill `story:` FIRST — it is mandatory and it comes before the schedule, because
the schedule exists to answer it. `want` names what is wanted, `way` names the
mechanisms the deliverables compose, `turn` seeds the lifecycle. THE TWO-WAY
CHECK: a `deliverables:` line answering no beat is scope nobody asked for; a
beat with no deliverable is a story the contract does not keep (put it under
"Out of scope" in writing, or deliver it).

  text/<slug>.md          ← THE PROMISE (this file) — root canon + oracle
    ├─ text/<slug>-plan.md    (HOW / DESIGN)
    ├─ text/<slug>-todo.md    (cycles / PLAN — its `outcome:` = this file's `proof:`)
    ├─ text/<slug>-docs.md    (the full spec — elaborates this promise; the acceptance oracle)
    └─ tests/<slug>.test.ts   (one assertion per documented observable)

The prose is the marketing copy. The frontmatter is the contract — read it the
way an engineering agency reads the statement of work it signs with a client:
`deliverables:` is the exhaustive schedule of what will be delivered, each line
with its own acceptance check; `proof:` is the acceptance test — the && -join
of every acceptance check, one command that settles the whole contract;
`derives:` is the manifest of artifacts this promise spawns (each true key →
its template, filled at its /do stop by a parallel agent); and `world:` is the
manifest of runtime the kept promise puts into the substrate — lifecycle,
workflow, agents, skills, tasks, tracking, routing, views. NO GAPS BY LAW:
not on the schedule = not promised (write it in "Out of scope") · on the
schedule = ships or the promise settles broken · acceptance is indivisible
(all lines together, no partial credit). do-promise-lint.sh enforces the
schedule ⇄ proof law with zero LLM calls. /do presence-checks world: entries like artifacts: missing
agent → template-agent.md cycle, missing skill → /skill-creator, missing
workflow/lifecycle stage → a cycle in the todo, missing view/route → a cycle
in the todo. "The first file creates the rest" is these blocks, made
mechanical. The covenant every maker signs into: text/promises.md.

A promise that also settles ON-CHAIN (generated Move contract + terms_hash
ratchet) uses the SAME template: uncomment the contract: block below and
follow its comment. Worked example: text/playbook.md.
-->
---
title: {Human-readable title}
slug: {kebab-slug}
type: feature              # this file IS the promise — the genesis contract for the slug

# ─── THE CONTRACT (machine-read by /do) ──────────────────────────────
# A promise is a contract of what will be made — the statement of work
# an engineering agency signs with a client. The schedule of
# deliverables is EXHAUSTIVE, every line carries its own acceptance
# check, and the one proof is all of them joined. PROMISE writes the
# terms first; every downstream stop reconciles to them; PROVE settles
# the contract by re-running `proof`. No gaps: not listed = not
# promised · listed = ships or the promise settles broken.

deliverables:              # THE SCHEDULE — what will be delivered, enumerated like an
                           # agency SOW. Exhaustive by law: an item not on this list is
                           # NOT promised (name it under "Out of scope" in the body); an
                           # item on this list ships or the WHOLE promise settles broken.
                           # Acceptance is indivisible — every line together, no partial
                           # credit, nothing between the lines. 3–9 items is typical;
                           # if you can't enumerate the delivery, you're not ready to
                           # promise. Linted: do-promise-lint.sh <slug>.
                           # PAGE-PROOF LAW: any user-visible item needs a route/component
                           # row whose accept: loads the page — e.g.
                           # `bash .claude/scripts/do-prove.sh --route /x` — enforced by
                           # do-promise-lint.sh (grep/tsc alone can pass while the page 500s).
  - item: "{one concrete thing the client receives — a route, a component, a doc, a wire}"
    accept: "{bash — exits 0 ONLY when this item is delivered AND wired, not merely present}"
  # - item: "{next deliverable}"
  #   accept: "{its own check}"

assumes: []                # CLIENT-SIDE DEPENDENCIES — what must already be true for the
                           # schedule to be deliverable, one bash check per line. GREEN AT
                           # PROMISE (the inverse of proof): a failing assumption means the
                           # contract can't be signed yet; one that goes false mid-build
                           # forces a renegotiation (a NEW promise), never a silent gap.

proof: ""                  # THE ACCEPTANCE TEST — derived, not authored: the && -join of
                           # every deliverable's accept:, verbatim, in schedule order:
                           #   proof = accept₁ && accept₂ && … && acceptₙ
                           # ONE command settles the contract (do-promise-settle.sh runs
                           # exactly this); the schedule above makes it exhaustive BY
                           # CONSTRUCTION — an accept: missing from the proof, or an item
                           # with no accept:, fails do-promise-lint.sh. It still BECOMES
                           # the todo's `outcome:`, the TEST assertion, and the PROVE
                           # oracle — named once, here, never restated loosely.
                           # RED BEFORE GREEN: at PROMISE this must EXIT NON-ZERO (the thing isn't
                           # built yet). It goes green only at PROVE. Green at PROMISE = already
                           # shipped (skip) or too weak to gate (rewrite it).
                           #
                           # THREE EXIT CODES, NOT TWO. A check that can only say ok/failed will
                           # report an outage as a broken promise:
                           #   0  ok         — the thing is built and behaves
                           #   1  RED        — the thing is genuinely missing or wrong
                           #   3  CANNOT RUN — the check could not reach its evidence (cluster
                           #                   down, no creds, network gone). NOT a red.
                           # Exit 3 must be distinguishable, because red and cannot-run send a
                           # human to opposite places: red means fix the build, cannot run means
                           # fix the environment. A board that paints cannot-run as failure will
                           # send someone to re-scope a correct migration. Make each accept:
                           # exit 3 when its evidence is unreachable, and say WHY in one line.
                           # And when the armed check goes red, confirm it is red for the RIGHT
                           # reason — a proof that false-fails on a dialect artifact or a missing
                           # binary gates nothing (recorded: a bare `node --check` that could
                           # never pass, so the kill-switch was decorative).

derives:                   # the artifacts this promise spawns. /do backfills each down the spine
                           # instead of re-deciding at DESIGN. true = spawn · false = skip.
  plan:      true          # text/<slug>-plan.md      — HOW (DESIGN)   — spine, always
  todo:      true          # text/<slug>-todo.md      — cycles (PLAN)  — spine, always
  docs:      true          # text/<slug>-docs.md      — spec + oracle (DOCS) — spine, always
  tests:     true          # tests/<slug>.test.ts     — one assert / observable (TEST) — spine, always
  features:  false         # text/<slug>-features.md  — WHAT — set true if scope spans ≥3 capabilities
  ui:        false         # text/<slug>-ui.md        — screens/states — DEFAULT true whenever world: names views,
                           # lifecycle stages, inbox spaces, or any route; false only with a stated reason
                           # (mirror the engine's {"surface":"none","reason":…} escape). When true, this
                           # promise's proof: MUST invoke `bash .claude/scripts/do-ui-gate.sh <slug>` —
                           # do-promise-lint.sh's ui-coupling check enforces it, so a UI-bearing promise
                           # can't settle without its ```ui fence rows (text/template-ui.md) actually
                           # being gate-checked.
  tutorial:  false         # text/<slug>-tutorial.md  — set true if there's a first-success worth its own page
  how-to:    false         # text/<slug>-how-to.md    — set true if ≥2 recurring tasks users repeat
  reference: false         # text/<slug>-reference.md — set true if the spec is too detailed for -docs.md
  agents:    false         # text/<slug>-agents-docs.md — set true if agents call this feature's receivers
  walk:      false         # text/<slug>-humans.md + text/<slug>-agents.md — the deterministic verification
                           # walk (do-walk.sh); DEFAULT true whenever ui: is true or any route ships —
                           # one stop per deliverables: row, agents-mode asserts reuse the accept: checks
  lifecycle: false         # text/<slug>-lifecycle.md — the end-to-end journey for both audiences;
                           # set true when world: names lifecycle stages, workflow steps, or ≥2 surfaces

rubric:                    # THE QUALITY CONTRACT — W4 scores every cycle against these
                           # floors; the composite gates the cycle (≥ 0.65 AND goal-fit
                           # ≥ 0.50) and becomes the mark() amount on this promise's path —
                           # quality compounds, not completion.
  security:    0.65        # secrets never land, authority walk intact, IDOR-guarded
  stability:   0.65        # ratchet held — tsc delta ≤ 0, tests green, must_not_break preserved
  simplicity:  0.65        # net-new primitives ≤ 0 — compose 3 existing before adding 1
  speed:       0.65        # cheapest tool that decides; token ceiling respected; lean diff
  integration: 0.65        # wired, never orphaned — nav/SDK/MCP/CLI/docs synced; scored
                           # deterministically from .w2-surface-checklist.json + do-reconcile.sh

# ── ON-CHAIN (optional) — uncomment to mint + settle this promise on Sui:
# fill the block, run `bun pay/tools/promise-chain.ts mint <slug>` at PROMISE;
# /close's do-promise-settle.sh then drives both settles.
# Deep-dive: text/do-promise.md. ──
# contract:
#   object:      Promise     # generated: schema/sui.tql `promise` → substrate.move — never hand-written
#   disposition: shared      # @sui:shared — maker + world both settle (owned = solo fast path · frozen = immutable once kept)
#   terms_hash:  "sha256(text/<slug>.md @ PROMISE)"  # the prose frozen at genesis — PROVE checks against THIS hash
#   settle:      proof       # PROVE runs `proof`: exit 0 → settle_promise(kept=true, k), strength += k (mark);
#                            # non-zero → kept=false, resistance += k (warn). assert!(state < 3) = the on-chain ratchet.
#                            # The off-chain `proof:` above IS the settlement condition — one source.
#   object_id:   ""          # on-chain handle — written back by the mint
#   maker:       ""          # Sui address that promised — filled at mint
#   oracle:      ""          # Sui address that attests — distinct from maker; set PROMISE_ORACLE=0x… before
#                            # minting or the tool refuses (exit 5); --self-oracle for fixtures/local only

world:                     # the runtime the kept promise puts into the world —
                           # /do presence-checks each entry and backfills the gaps
  lifecycle: []            # "{stage} → {stage}: the move + the signal that records it"
  workflow:  []            # "{kind}: …" — kinds (LOCKED): trigger·tool·skill·agent·condition·human·delay·sell
  agents:    []            # { name, subscribes: [tags] } — the tags are the stake (routing + inbox Space)
  skills:    []            # "{skill}: what it lets an agent do"
  code:                    # the CODE the tag's family owns — every value a path relative to
                           # the repo root, presence-checked EXACTLY like agents: a declared
                           # path that does not exist → a cycle in the todo; present → skip.
                           # Gate: `bash .claude/scripts/do-world-check.sh <slug>`.
    ts:      []            # ["one.ie/web/src/lib/{slug}/tasks.ts"] — libs, resolvers, receivers
    astro:   []            # ["one.ie/web/src/pages/{slug}.astro"]  — pages the tag ships
    tql:     []            # ["schema/{slug}.tql"]                  — the tag asked as a query
    panel:   []            # ["one.ie/web/src/components/{Slug}Panel.tsx"] — what a view mounts
    command: []            # [".claude/commands/{slug}.md"]         — the operator's door
  tasks:
    tags: ["slug:{slug}"]  # the todo enters the world as a tagged weighted signal
  tracking:
    marks: []              # signals that prove it works — strengthen the path
    warns: []              # signals that prove it doesn't — add resistance
  routing:   []            # "{from}→{to}: what a high strength here routes next"
  views:     []            # "{view-kind}: what this promise shows there" — where the
                           # kept promise becomes VISIBLE. Kinds from the view registry
                           # (one.ie/web/src/lib/views/registry.ts), reached by the
                           # order-free traversal (lib/navigation.ts resolvePath — any
                           # {dept, view} permutation lands on the same cell). Presence-
                           # checked like every entry above: view kind or route missing
                           # → a cycle in the todo; present → skip. Worked example:
                           # text/view-coverage.md.

goal:                      # THE STANDING OBJECTIVE THIS PROMISE SERVES — one line, and
                           # NOT a restatement of story.want. `want` is what THIS story's
                           # actor wants, once; `goal:` is the objective that outlives this
                           # promise and that several stories serve. It is machine-read:
                           # `objective` is a live factory rung (RUNGS in
                           # one.ie/web/src/lib/resolvers/factory.ts:36 — objective ->
                           # deliverable -> task, keyed `oid` in resolvers/fn.ts:51), and
                           # `thing-type='plan'` already owns a `goal` attribute
                           # (schema/one.tql:142,384), so -plan.md inherits this line rather
                           # than inventing its own. If the goal and the want are the same
                           # sentence, the goal is missing — write the one that survives
                           # this promise being kept.
                           # Lint: absent -> WARN, present-but-empty -> FAIL.
  objective: ""            # the standing objective, one sentence

loop:                      # WHAT RE-RUNS WHILE THE GOAL IS UNMET, and what stops it.
                           # (An earlier revision of this template ruled `loop:` out as
                           # prose, on the grounds that nothing resolves a loop by name.
                           # That was the wrong place to look: the referents are on the PLAN,
                           # not in a registry — `escape-condition` and `escape-action` are
                           # declared attributes at schema/one.tql:386-387 and generated into
                           # the SDK zod schemas, and `cycles-planned` at :385. The loop is
                           # machine-read after all.)
                           #
                           # THE STAGES ARE THE SPINE, and they are the same six every time:
                           #   goal → story → plan → tasks → promise → results → (repeat)
                           # A turn that skips one is not a faster loop, it is a loop with a
                           # missing rung: no story means nobody wanted it, no tasks means
                           # nothing was filed, no results means nothing closed.
                           #
                           # `until:` IS MANDATORY AND IS THE WHOLE POINT. A loop with no
                           # escape is not a loop, it is a bill. Three terminators, and the
                           # second and third are ONE shipped mechanism: `funding-of`
                           # (schema/roles.tql:134) walks up the group tree and returns the
                           # first ancestor with `credit > 0.0`. When it returns EMPTY there
                           # is no money and no credit anywhere above this group, and the
                           # loop must stop — that is not a policy, it is a query.
                           # Lint: absent → WARN · present with no `until:` → FAIL.
  stages: [goal, story, plan, tasks, promise, results]
  until:
    - "complete: this promise's own proof: exits 0"
    - "out of credit: funding-of(group) returns empty — no ancestor holds credit > 0"
    - "exhausted: cycles-planned is spent; escape-action decides what happens next"


story:                     # MANDATORY, AND WRITTEN FIRST — this is the root document, and
                           # the story is what it is. Condensed, commercial-register beats.
                           # The schedule above answers these beats; see the two-way check
                           # in this file's header comment.
                           # NOT the same thing as text/template-story.md, which is a SEPARATE,
                           # standalone, book-register file (no selling, no "I", no code) — that
                           # template's own doctrine is explicit: a story that needs to be SOLD
                           # gets BOTH files, kept apart, never merged. This block is the other
                           # half of that split: the promise's own condensed telling, in the
                           # promise's own commercial register, using the SAME seven beats and
                           # the SAME locked dimension mapping template-story.md defines —
                           # so the two forms are never in tension about what a beat means.
  seven_beats:
    world:  "{where it happens, before this promise — Groups}"
    cast:   "{who acts in it, and who leaves the marks — Actors. Name every audience
             this promise's -lifecycle.md will later give its own stage table to;
             cast here is that table's row list, one sentence early}"
    knock:  "{the signal that starts it — the trigger, dimension 5. What arrives
             and makes this promise necessary}"
    want:   "{what is wanted — Things. A promise with no want is a spec, not a story}"
    way:    "{how it goes — Paths. The receivers/mechanisms this promise composes,
             named as the READER would name them, not as the code does}"
    turn:   "{the moment the meaning changes — Events. This is the seed of every
             stage-transition row -lifecycle.md will elaborate: write it so a
             lifecycle table could be built from this one sentence and nothing else}"
    lesson: "{what the substrate now knows that it didn't — Learning. What gets
             carried forward to the next actor who arrives at the same knock}"
# ─────────────────────────────────────────────────────────────────────
---

# {Title}

## The goal, and the loop that pursues it
{Two short paragraphs. First: the standing objective — the thing that is still
true after this promise is kept, and that other promises also serve. Second: the
loop — what re-runs while the goal is unmet, what each turn closes with, and what
stops it. A goal with no loop is a wish; a loop with no goal is a treadmill.}

## The story
{The seven beats in prose, three or four sentences. The same beats as the `story:`
frontmatter, told rather than listed. This is the top of the document because it is
what the document is; everything below is what keeping it costs.}

## Who this is for
{One sentence — the persona. "A {role} who {context}."}

## What they get
{One sentence — the outcome. "They can now {do X} without {pain Y}."}

## Why it matters
{One sentence — the delta. "Before: {friction}. After: {flow}."}

## The promise (PROVE checks this)
{One paragraph — concrete enough to prove. What the user sees, clicks, or gets back. Specific nouns. No hedging. The schedule below is the whole delivery; the exclusions after it are the whole "no".}

## The deliverables (the schedule of work)

{Read this like the statement of work an agency signs. One row per `deliverables:` line — the same items, in the client's words. Anything not in this table is not promised.}

| # | Deliverable | Answers the beat | Accepted when |
|---|---|---|---|
| 1 | {the thing delivered} | {want · way · turn — which beat this keeps} | {its `accept:` check, in words} |

**Completeness clause:** this schedule is exhaustive and acceptance is indivisible — every line delivered and green together, or the promise settles broken. No partial credit, no "mostly done", nothing between the lines.

## Out of scope (excluded, in writing)

{Enumerate the adjacent things this promise deliberately does NOT deliver — every line a client might otherwise assume in. One line each: "Not this: {thing} — {where it lives instead, if anywhere}." An ambiguity that isn't on the schedule and isn't listed here is a drafting bug in the promise.}

## The proof (the acceptance test the whole spine points at)
{The `proof:` command in words — the && -join of every deliverable's acceptance check. True only if every line of the schedule shipped. DESIGN's pre-mortem tests, the todo's `outcome:` command, the TEST assertion, and TEACH's "verify it's working" all reference THIS — never a loose restatement.}

## Tone
{Voice contract keywords for this surface — 3-5 words that capture the feel. These come from .claude/product-marketing.md.}
