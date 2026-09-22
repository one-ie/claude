---
name: promise-settle
description: Run the proof, move the path, announce the verdict — settle a promise and never return silently. Use whenever a promise's proof can now be checked — "settle the promise", "did we keep it", "the work is done, close the promise", or when a watched promise's observable flips. Emits signal("promise:settle", { slug, kept?, composite? }); kept → mark, broken → warn, no observable → dissolve. Refuses shell-shaped proofs (those settle at PROVE via do-promise-settle.sh).
---

# promise-settle — run the proof, move the path, announce the verdict

**Purpose:** Close a promise's loop. Check the one observable the promise froze at make-time, then emit the verdict: kept → `mark` on `promise:<slug>→proof` (strength climbs, routing follows), broken → `warn` (resistance climbs, the path decays honestly), no observable → dissolve with a receipt. There is no third outcome and no silent one.

Source of truth: `one.ie/web/src/lib/resolvers/promises.ts` (receiver `promise:settle`) · briefing: `text/promise-signals-agents-docs.md` · contract: `text/promise-signals.md`.

---

## HARD RULES

- **Never return silently.** Every settle attempt ends in exactly one of: `settled-kept` (mark) · `settled-broken` (warn) · `dissolved` (no observable) · a surfaced refusal (`forbidden` / `already settled` / `shell proof settles at PROVE via CLI` / `not_found`). Report which one, verbatim.
- **Run the proof BEFORE emitting.** The resolver does not execute proofs — the verdict is the maker's authorized assertion (`kept: true|false`). So this skill IS the proof-runner: actually check the observable (fetch the URL, read the row, `promise:get` the dependent state) and set `kept` from the real result. Emitting `kept:true` without checking is declaring green — green is earned, never declared.
- **`kept` defaults to true server-side** (`data.kept !== false`). Therefore: to settle broken you MUST pass `kept: false` explicitly. Omitting it after a failed check would lie. Pass the boolean explicitly both ways.
- **Shell-shaped proofs never settle here.** `test -f` / `grep` / `&&` / `;` / `$()` / backticks in the proof → the resolver refuses (`shell proof settles at PROVE via CLI`). Route those to `.claude/scripts/do-promise-settle.sh <slug>` at PROVE instead — same verdict table, CLI rail.
- **Only the maker settles.** The resolver compares the persisted `maker` to `ctx.ownerSlug` — session identity only, a body `actorId` is never checked. If you are not the maker, do not attempt; `promise:get` to learn who is.
- **The ratchet is final.** A terminal promise (`settled-kept` / `settled-broken` / `dissolved`) never re-settles — the resolver returns `already settled`. Do not retry a terminal verdict; report the existing state via `promise:get`.
- **Disputed → human, not warn.** If the verdict is contested, `human:ask` the oracle before a `warn` lands on someone's path (the standing workflow's rule — `text/promise-signals.md` world.workflow).

## When to use

- The work behind a promise is done and its observable can be checked now
- A watched promise's `world:do-event` traffic says the proof is worth re-running
- An operator asks "did we keep the promise?" / "close out the promise"
- A promise turns out to have no real observable → settle it *dissolved*, with the receipt stated

**Not for:** making promises (`promise-make`), reading state (`promise:get` — public, no skill needed), or build-cycle promises with shell proofs (those are `do-promise-settle.sh`'s at `/close`).

## The signal (exact shape)

```ts
// 1. Read the promise first — terms, proof, current state
signal("promise:get", { slug: "elitemoversca-landing-live" })
// → { ok: true, slug, terms, state: "promised", strength: 0, resistance: 0 }

// 2. RUN the proof yourself (fetch / D1 read / dependent promise:get) → verdict

// 3. Emit the verdict — maker only, kept explicit, composite optional
signal("promise:settle", {
  slug: "elitemoversca-landing-live",
  kept: true,          // EXPLICIT — from the check you just ran; false to settle broken
  composite: 0.78      // optional rubric score; kept strength += composite×5 (else +1)
})
```

Responses (one of, always):

```json
{ "ok": true,  "slug": "…", "state": "settled-kept",   "strength": 3.9 }
{ "ok": true,  "slug": "…", "state": "settled-broken", "resistance": 1 }
{ "ok": true,  "slug": "…", "state": "dissolved" }
{ "ok": false, "error": "forbidden: only the maker may settle" }
{ "ok": false, "error": "already settled" }
{ "ok": false, "error": "shell proof settles at PROVE via CLI" }
{ "ok": false, "error": "not_found" }
```

What the resolver does on each verdict: kept → `mark(env, "promise:<slug>", "proof", composite×5 or 1)` + state `settled-kept` + `world:announce` tags `["promise","settlement",slug]` · broken → `warn(…, 1)` + state `settled-broken` + same announce · empty proof → state `dissolved` (belt-and-braces — `promise:make` refuses empty proofs, but the closed-loop leg exists so no path is silent).

## Process

1. **`promise:get` the slug.** Confirm state is `promised` (terminal → report final state, stop) and read the frozen `proof` text.
2. **Classify the proof.** Shell-shaped → hand off: `bash .claude/scripts/do-promise-settle.sh <slug>` (or tell the operator that's the rail) and stop. Runtime observable → continue.
3. **Run the observable for real.** Fetch the URL, query the row, check the signal receipt — whatever the proof names. Record the evidence (status code, row id, output line).
4. **Confirm you are the maker.** Your session slug must equal the persisted `maker`. Not you → report who may settle; do not spoof.
5. **Emit** `signal("promise:settle", { slug, kept: <checked verdict>, composite? })` — `composite` only if you hold a real rubric score.
6. **Announce + close the loop.** The resolver already fans `world:announce` to everyone staked on `[promise, settlement, <slug>]` — your job is the human-readable verdict: state (`settled-kept` / `settled-broken` / `dissolved`), the path moved (`promise:<slug>→proof` strength/resistance delta), and the evidence from step 3. On `{ok:false}` report the error verbatim and the recovery (see table in `text/promise-signals-agents-docs.md § Errors → recovery`).

## Worked example

Promise `elitemoversca-landing-live` — proof: "GET https://elitemoversca.com returns 200 with the hero headline present."

1. `signal("promise:get", { slug: "elitemoversca-landing-live" })` → `state: "promised"`. Proceed.
2. Proof is a runtime fetch — no shell shapes. This rail.
3. Run it: `curl -s -o /dev/null -w '%{http_code}' https://elitemoversca.com` → `200`; page text contains the hero headline. Evidence: HTTP 200 + headline match. Verdict: kept.
4. Session slug = persisted maker. Authorized.
5. `signal("promise:settle", { slug: "elitemoversca-landing-live", kept: true })`
6. Response `{ ok: true, state: "settled-kept", strength: 1 }` → report: "Settled **kept**. Proof: 200 + hero headline live. Path `promise:elitemoversca-landing-live→proof` strength 0 → 1; verdict announced to everyone staked on [promise, settlement]. The ranker now favors this maker for the next matching work."

Broken variant: the curl returns `522`. Then step 5 is `{ slug, kept: false }` → `{ ok: true, state: "settled-broken", resistance: 1 }` → report the warn and the evidence (522), not a euphemism. The path decays honestly — that is the feature.

## Quality checks

- [ ] Proof actually run, evidence recorded — verdict never asserted unchecked
- [ ] `kept` passed explicitly (true AND false) — never rely on the server default
- [ ] Shell-shaped proof routed to `do-promise-settle.sh`, not forced through the signal
- [ ] Exactly one closing outcome reported, verbatim — kept/broken/dissolved/refusal
- [ ] Terminal promise not retried — ratchet respected
- [ ] Disputed verdicts pause for `human:ask` before a warn lands

## Cross-references

- Make side: `.claude/skills/promise-make/SKILL.md`
- Receiver source: `one.ie/web/src/lib/resolvers/promises.ts` (`settle`, lines 82–137 — IDOR guard, ratchet, shell-proof refusal, verdict table)
- Agent briefing (payloads, errors, recovery): `text/promise-signals-agents-docs.md`
- The contract this skill serves: `text/promise-signals.md` (`world.skills` names this skill; `world.tracking` names the mark/warn wires)
- Build-time twin: `.claude/scripts/do-promise-settle.sh` at `/close` — same verdict table, CLI rail
