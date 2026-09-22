---
name: promise-make
description: State terms + exactly one checkable proof — make a promise as a signal any actor can send. Use whenever an operator or agent commits to an outcome that should be held, watched, and settled — "promise that X", "commit to Y", "make a promise", "I'll deliver Z by the time the proof passes". Refuses a promise with no observable. Emits signal("promise:make", { slug, terms, proof }) and closes the loop with a receipt.
---

# promise-make — state terms + exactly one checkable proof

**Purpose:** Turn a commitment into a promise Thing the world holds: frozen terms + ONE proof observable. One signal in, one `promised` state out, announced to everyone staked on the `promise` tag. The run-time face of what `/do`'s PROMISE stage does at build time.

Source of truth: `one.ie/web/src/lib/resolvers/promises.ts` (receiver `promise:make`) · briefing: `text/promise-signals-agents-docs.md` · contract: `text/promise-signals.md`.

---

## HARD RULES

- **Refuse a promise with no observable.** Empty or vague `proof` → do NOT emit the signal. The resolver rejects it anyway (`{ok:false, error:'a promise needs one observable'}`), but the refusal happens here first: ask for the one checkable thing, or dissolve the request with a stated reason. Never a silent return.
- **Exactly ONE proof.** If the terms need two *independent* observables, that's two promises — split them into two slugs. But a **multi-part delivery is one promise with a schedule** (covenant clause 1, `text/promises.md`): enumerate the deliverables in `terms` like an agency SOW — every item the receiver gets, each with its own acceptance check in words — and make the ONE `proof` the observable that is true only when *every* line shipped (acceptance indivisible, no partial credit). Not enumerated = not promised. If no single observable can cover the whole schedule, the schedule is two promises.
- **Terms freeze at the making.** The resolver inserts with `ON CONFLICT(slug) DO NOTHING` — a re-make of an existing slug changes nothing. Never "update" a promise's terms; make a new slug.
- **Know which rail the proof settles on.** A shell-shaped proof (`test -f`, `grep`, `&&`, `;`, `$()`, backticks) is a BUILD-time observable — it settles at PROVE via `do-promise-settle.sh`, and `promise:settle` will refuse it. A runtime observable (a D1 row, a fetch, a signal receipt, a maker-attested verdict) settles via `promise:settle`. State which rail at make-time so the maker isn't surprised at settle-time.
- **Identity is the session, never the body.** `maker` becomes `ctx.ownerSlug` server-side. Never pass an `actorId` in the payload expecting it to matter — it doesn't, by design (IDOR-safe).
- **Closed loop.** Emit → read the response → `mark` mentally on `{ok:true}`, surface the error verbatim on `{ok:false}`. No silent returns.

## When to use

- An operator says "promise that…", "commit to…", "hold me to…"
- An agent takes on work whose completion should route future work (reputation via `promise:<slug>→proof`)
- A `/do` promise file's `world.skills` fan-out names a commitment that must exist as a run-time object
- A deal needs an unpriced spine before money attaches (a priced promise rides the deal rail on top of this)

**Not for:** settling (that's `promise-settle`), reading (`promise:get`, public, no skill needed), or build-time promise files in `text/` (that's the `docs` skill + `template-feature.md`).

## The signal (exact shape)

```ts
signal("promise:make", {
  slug:  "ship-weekly-digest",         // ^[a-zA-Z0-9_:/-]{1,128}$ — the promise's name, forever
  terms: "A digest email goes to every subscriber each week.",  // frozen prose, hashed sha256
  proof: "promise:get shows a broadcast_sends row for the current week"  // ONE observable
})
```

Response on success:

```json
{ "ok": true, "slug": "ship-weekly-digest", "state": "promised", "terms_hash": "<sha256 of terms>" }
```

What the resolver does (so you don't re-do it): inserts the D1 `promises` row (state `promised`, strength 0, resistance 0), fire-and-forgets a TypeDB `thing` with `thing-type "promise"`, and fire-and-forgets `world:announce` with tags `["promise", "made", slug]` — every subscriber staked on those tags gets it in their inbox Space.

## Process

1. **Extract the terms.** One sentence of what will be true. If the ask is fuzzy, tighten it with the maker before emitting — frozen fuzz is worse than no promise.
2. **Extract the ONE proof.** Ask: "what single check settles this?" If the answer is "well, A and B" → two promises. If the answer is "you'll know it when you see it" → refuse, with the reason stated. The check should be *false right now* (covenant clause 3, red before green) — a proof that already passes means the thing is already built, or the proof is too weak to gate anything. The resolver does not enforce this; you do.
3. **Classify the proof rail.** Shell-shaped → tell the maker it settles at PROVE via CLI, not via `promise:settle`. Runtime-checkable → `promise:settle` works.
4. **Pick the slug.** Kebab, stable, matches `^[a-zA-Z0-9_:/-]{1,128}$`. It becomes the path endpoint `promise:<slug>→proof` — choose like it's permanent, because it is.
5. **Emit** `signal("promise:make", { slug, terms, proof })` — authenticated (the session's `ctx.ownerSlug` becomes the maker who alone may settle).
6. **Close the loop.** `{ok:true, state:"promised"}` → report slug + terms_hash back to the maker. `{ok:false}` → surface the error verbatim (`slug + terms required` · `invalid slug` · `a promise needs one observable` · `forbidden: authentication required`) and fix the input. If the slug already existed, `promise:get` it and tell the maker the prior terms stand — nothing was overwritten.

## Worked example

Operator: *"Promise the client their movers landing page will be live."*

1. Terms: "The elitemoversca landing page is live at its production URL."
2. Proof (one, runtime-checkable): "GET https://elitemoversca.com returns 200 with the hero headline present."
3. Rail: runtime observable → settles via `promise:settle`. Good.
4. Slug: `elitemoversca-landing-live`.
5. Emit:
   ```ts
   signal("promise:make", {
     slug:  "elitemoversca-landing-live",
     terms: "The elitemoversca landing page is live at its production URL.",
     proof: "GET https://elitemoversca.com returns 200 with the hero headline present"
   })
   ```
6. Response `{ ok: true, slug: "elitemoversca-landing-live", state: "promised", terms_hash: "9f2c…" }` → report: "Promised. Terms frozen (hash 9f2c…). Settles kept when the page answers 200 — run `promise-settle` when it's live. Everyone staked on the `promise` tag was announced."

Counter-example (must refuse): *"Promise we'll make the client happy."* → No observable. Reply: "A promise needs one checkable proof — what single thing, when true, means this is kept? (e.g. a signed renewal, a ≥ 4-star review row)." Do not emit.

## Quality checks

- [ ] Exactly one proof observable, stated in the payload
- [ ] Proof rail classified (shell → PROVE/CLI · runtime → `promise:settle`) and told to the maker
- [ ] Slug matches the regex and won't need renaming
- [ ] Response read and reported — `ok:true` receipt or verbatim error, never silence
- [ ] No body-field identity games — session auth only

## Cross-references

- Settle side: `.claude/skills/promise-settle/SKILL.md`
- Receiver source: `one.ie/web/src/lib/resolvers/promises.ts` (`make`, lines 36–67)
- Agent briefing (payloads, errors, recovery): `text/promise-signals-agents-docs.md`
- The contract this skill serves: `text/promise-signals.md` (`world.skills` names this skill)
- Build-time twin: `/do` PROMISE stage + `text/template-feature.md` (contract: block). "Never update the terms" is this rail's rule — a D1 row inert after `ON CONFLICT DO NOTHING`. The build-time rail differs: a *kept* `text/<slug>.md` promise grows, appending a follow-on deliverable whose `accept:` is already green and extending the `proof:` join (`.claude/rules/documentation.md` § "Promises grow with delivery"). Green-only and additive there; frozen here.
