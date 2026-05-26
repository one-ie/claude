# 08-memory — gap analysis

## Promise

`text/08-memory.md` is the chapter "Memory: Every Conversation Makes the Next One Better." It claims:

- **Five memory types, one substrate.** Episodic (`signal`), Semantic (`hypothesis`), Procedural (`skill`+`.on()`), Social (`membership`/`capability`), Associative (`path`). All queryable without embeddings or a parallel memory service.
- **Two scopes.** Per-actor memory (portable across channels via cryptographic identity) + per-world memory (the workspace corpus). 50 clients = 50 isolated TypeDB tenants.
- **Four-stage hardening.** Signal (ms) → Trail (sec-hr) → Highway (hr-day) → Hypothesis (~hourly L6 `know()`). Promised drop from ~1500ms to <10ms on proven routes — "200x cost reduction" after fifty interactions.
- **Crawl ingest path.** `unit('crawl:client-site').on('document')` → LLM extracts typed primitives into TypeDB + raw text + embedding fallback into KV. Crawler hardens semantic memory.
- **L6 `know()` promotion.** Hourly tick surveys highways that survived multiple fade cycles, writes `{subject, predicate, object, confidence, source}` hypotheses. Contradiction detection via `warn()` on the producing path.
- **Asymmetric fade.** Strength × (1−0.05)^t, resistance × (1−0.10)^t. Resistance decays 2x faster, every 5 minutes. Forgives faster than it praises.
- **Source-typed confidence.** `observed` ≤ 0.95, `asserted` ≤ 0.30, `verified` ≤ 0.99. `select()` ignores asserted-only paths.
- **Twelve verbs total surface.** `signal · mark · warn · fade · know · recall · open · highways · reveal · forget · frontier · sense`.
- **GDPR built in.** `persist.reveal(uid)` returns a `MemoryCard` (hypotheses + highways + last 200 signals + memberships + capabilities + frontier tags) for Article 20; `persist.forget(uid)` cascades through schema for Article 17.
- **Scope attribute on every signal.** `private` (sender+receiver), `group` (workspace), `public` (cross-workspace if federated). Private signals never promote to hypotheses.
- **Cross-channel identity.** Same actor on SMS/web/email — memory follows the keypair, not the session.
- **Numbers asserted:** 200x cost drop · 5min fade cadence · 1hr L6 lag · 1 command to erase · 12 verb surface · 670-line runtime · 0.30 asserted cap · 0.95 observed cap.

## Code reality

- **Substrate primitives present.** `/Users/toc/Server/one-ie/one/claw/src/substrate.ts` and `/Users/toc/Server/one-ie/one/web/src/lib/substrate.ts` both implement `mark()` / `warn()` / `fade()` / `follow()` / `select()` against TypeDB through `api.one.ie/typedb/query`. D1 mirror (`claw_paths`) backs fast reads. Asymmetric fade is real (`factor * 0.5` on resistance — `web/src/lib/substrate.ts:291`, mirrored at `:301`).
- **Hypothesis read path works.** `recallHypotheses()` (`claw/src/substrate.ts:230`), `/api/learning` and `/api/learning/discovered` (`web/src/pages/api/learning/{index,discovered}.ts`) read `isa hypothesis` rows and convert p-value → confidence. `/api/frontiers` reads the same dimension.
- **Slash commands wired.** `/memory`, `/forget`, `/explore` exist in `claw/src/memory.ts` and produce real output from substrate state.
- **Forget cascade is real.** `/api/forget/:id` (`web/src/pages/api/forget/[id].ts`) + `lib/pii/forget.ts` orchestrate a 6-tier cascade (vault/KV/D1/TypeDB/R2/ads) with poll-able receipts. `claw/src/memory.ts:75-97` deletes paths + hypotheses + messages for a given uid in TypeDB.
- **Fade endpoint exists.** `/api/fade` (`web/src/pages/api/fade.ts`) is protected by `SERVER_SECRET`. Calls `fade(env, rate)` against TypeDB and D1.
- **Hypothesis schema declared.** `one/marketing-schema.tql:356,598` define `hypothesis` with `hypothesis-statement`, `p-value`, `observations-count`, `hypothesis-status`, `source`.
- **Crawl exists, but only in showcase.** `web/src/pages/api/showcase-chat.ts:32-47` is the only consumer of CF browser-rendering. The spec at `one/crawl.md` was written for `web/src/pages/api/chat.ts` — never landed there. Production `chat.ts` has no `crawl` tool.
- **Browse, not crawl.** `claw/src/aitools.ts:161` exposes a `browse({ url })` tool that uses `claw/src/browser.ts` — a regex-stripped single-fetch with 5s timeout. No depth, no LLM extraction into TypeDB, no embedding fallback. KV is the only store.
- **`remember()` writes hypotheses with source=`asserted` and p-value=0.05 fixed.** `claw/src/substrate.ts:207-228` (`rememberHypothesis`) hardcodes `source "asserted"` and `p-value 0.05`. Per spec, asserted should cap confidence at 0.30 — `recallHypotheses` returns `1 - 0.05 = 0.95` for every asserted memory. The cap is documented in copy but not enforced anywhere.

## Gaps

1. **No `know()` / L6 promotion loop.** The promise: highways that survive multiple fade cycles get promoted hourly to typed hypotheses. The reality: `claw/src/cron.ts:16-20` registers only `journey-tick`, `identity-tick`, `export-tick`. There is no L6 handler, no scheduled `know()`, no promotion job anywhere in `claw/src/` or `web/src/pages/api/`. Hypotheses exist only when explicitly written by the `remember` tool. The "Day 43: L6 runs, writes `delivery-delay → weekend-order` at 0.87" example is unreachable today.
2. **No `fade()` schedule.** Asymmetric decay code is correct, but `fade` is exposed only as a manual privileged `POST /api/fade`. No cron entry, no L3 5-minute tick. Paths grow monotonically until someone pokes the endpoint. The "forgets twice as fast as it praises" claim has no scheduler behind it.
3. **`source` confidence caps not enforced.** Marketing claims `asserted ≤ 0.30`, `observed ≤ 0.95`. `rememberHypothesis` writes asserted hypotheses at p=0.05 → confidence 0.95. Neither `select()` nor `recallHypotheses` filters or caps by source. A customer who lies *can* in fact route on the lie. (`claw/src/substrate.ts:207-228`, `web/src/pages/api/learning/index.ts:36-46`.)
4. **No crawl ingest path in production.** The chapter's "Crawling the Web" section describes `unit('crawl:client-site').on('document', ...)` extracting typed primitives. The actual `crawl.md` plan was never implemented in `chat.ts`. The only crawl code is `showcase-chat.ts` (one-shot Q&A, no TypeDB write, no embedding) and `browser.ts` (regex strip, KV cache only). No LLM extraction-into-schema, no recurring crawl unit, no embedding fallback.
5. **No `reveal(uid)` endpoint.** The promised `MemoryCard` aggregate (hypotheses + highways + signals + groups + capabilities + frontier) — the GDPR Article 20 surface — does not exist. `/api/learning`, `/api/frontiers`, `/api/export/actors`, `/api/forget/:id` each return slices. No single endpoint composes them into the documented shape, and `persist.reveal` is referenced nowhere in code.
6. **No `scope` attribute on signals.** Marketing claims every signal carries `private` / `group` / `public`. `claw/src/substrate.ts` inserts paths and hypotheses with strength/resistance/traversals only — no `scope`, no `sensitivity`. The L6 exclusion of private signals from hypothesis promotion has nothing to filter against. (`agent-md.ts` has `sensitivity` on the agent level only.)
7. **No tenant isolation in the substrate calls.** The claim is "each client workspace is a separate TypeDB tenant; queries cannot cross tenant boundaries." All gateway calls go to one `api.one.ie/typedb/query`. `recallHypotheses` searches `has statement $s; $s contains "${term}"` globally — there is no `group` / workspace predicate in the TQL. Group-scoped queries are absent at the substrate layer (workspace gating is enforced one layer up via `scopeToGroup`, but the TQL itself reaches everything).
8. **No contradiction detection.** "L6 detects contradicting hypotheses … `warn()`s the path that produced the old belief." There is no L6 loop and no contradiction comparator anywhere.
9. **No `MemoryCard` type, no `frontier()` per actor.** `/explore` (`claw/src/memory.ts:118`) is the closest — it returns ad-hoc skill tags the actor hasn't touched. No typed `frontier(uid)` API; no shape that matches the marketing example.
10. **Cross-channel identity is partial.** Actor uid stable through `claw:${groupId}`. There is no signed cross-channel merge path described in `one/memory.md:62-79`; identity unification across SMS/web/email is by handle convention, not signed claim.
11. **Verb surface mismatch.** Promised 12 verbs. Actual public callable surface in `web/src/lib/substrate.ts`: `mark, warn, fade, follow, select, isToxic, writeSignal, writeOutcome, pollOutcome` (9) — missing `know`, `recall`, `open`, `highways`, `reveal`, `forget`, `frontier`, `sense`. `claw/src/substrate.ts` adds `highways`, `actorHighways`, `recallHypotheses`, `rememberHypothesis` (4 more, partial coverage). No `sense`, no `open`, no `reveal`.
12. **Highway → hypothesis promotion threshold is never read.** `highways()` filters `$s >= 10.0` (`claw/src/substrate.ts:174`). No code consults this to write a hypothesis. The threshold lives only as a number in code, never as a policy.
13. **"200x cheaper after 50 interactions" is unverified.** No benchmark, no telemetry. `claw/src/middleware.ts` records cache-read ratio into `mark()` strength, but no cost-per-decision counter accumulates or surfaces anywhere.

## Recommended improvements

1. **Land L6 `know()` as a cron handler.** Add `{ cron: '0 * * * *', handler: 'know-tick' }` to `claw/src/cron.ts:16`. Implement `claw/src/agents/know-promoter.ts`: SELECT highways with `strength >= 10 AND traversals >= 5 AND age_ms >= 2 fade cycles`, write `hypothesis` with `source = "observed"`, `p-value = 1 - min(0.95, strength/maxStrength)`, `subject/object` from path endpoints. Emits the audit signal the marketing claims is automatic.
2. **Land L3 fade as a cron.** Add `{ cron: '*/5 * * * *', handler: 'fade-tick' }`. Call `fade(env, 0.05)`. Removes the need for the privileged `/api/fade` endpoint to be poked manually; fixes the monotonic-strength bug.
3. **Enforce source caps at read time.** In `recallHypotheses` and `/api/learning`, clamp confidence by source: `observed → min(0.95)`, `asserted → min(0.30)`, `verified → min(0.99)`. In `select()`, filter out hypotheses whose only support is asserted (no observed sibling on the same edge).
4. **Add scope to substrate writes.** Schema: `attribute scope, value string;` on `signal` and `hypothesis`. Default `group`. `mark` / `warn` / `rememberHypothesis` take a `scope?: 'private'|'group'|'public'` param. `know-promoter` skips `scope = "private"`.
5. **Add workspace predicate to substrate queries.** Pass `groupId` into every TQL and add `$actor has group "${esc(groupId)}";` (or join through `membership`). Promote `scopeToGroup` from the API layer down into substrate, so a leaked endpoint cannot read another tenant by skipping the gate.
6. **Build `/api/reveal/:uid`.** One endpoint that composes the documented `MemoryCard`: hypotheses (with source + confidence) + top highways + last 200 signals + memberships + capabilities + frontier tags. Reuses existing readers in `learning`, `frontiers`, `export/actors`. Type the response in `web/src/lib/substrate.ts` as `MemoryCard` so SDK + UI share the shape.
7. **Implement the crawl unit, not just a tool.** Per `one/crawl.md`, add `crawl` tool to production `web/src/pages/api/chat.ts` using CF browser-rendering. Then add an `agents/crawler.md` that runs on a cron, hits configured URLs, extracts typed primitives via LLM into TypeDB (`product`, `pricing`, `faq` entities — `marketing-schema.tql` already has the slots), keeps raw text + embedding in R2/KV as the documented fallback.
8. **Contradiction detector in L6.** When promoting, query `match $h2 isa hypothesis, has subject $s, has predicate $p, has object $o2; $o2 != $newObject; select $h2`. Found rows → `warn()` the path that produced `$h2`; mark `$h2 hypothesis-status "rejected"` after N ticks below threshold.
9. **Wire cost-per-decision telemetry.** `substrateMiddleware` already sees usage. Add `cost-per-mark` counter in D1 (`claw_paths.cost_acc`). `/api/learning` returns `cost_at_decision_n / cost_at_decision_1` so the marketing's "200x" becomes a real chart.
10. **Add the missing verbs as thin exports.** `open(n)`, `sense(edge)`, `frontier(uid)`, `recall(match)`, `reveal(uid)`, `know()`, `forget(uid)` all become exports of `web/src/lib/substrate.ts`. Brings the actual surface up to the documented 12 — even if each is a thin wrapper at first, the *name* is the contract.
11. **Implement signed cross-channel merge.** `lib/identity` already has Sui keypair derivation. Add `/api/identity/merge` that takes `{primary_uid, secondary_uid, signature}`, verifies, rewrites `aid` references in TypeDB. Documents `one/memory.md:62-79` becomes truth instead of aspiration.
12. **Strip dead claims from the chapter.** If we don't ship (3) / (5) / (6) / (7) / (8) in the same cycle, delete the corresponding paragraphs from `text/08-memory.md` rather than leave them as marketing-promise debt. Specifically: the Day-43 worked example (lines 96-118), the `reveal(uid)` MemoryCard block (lines 270-282), the "asserted hypotheses are capped at 0.30" objection answer (lines 244-253), and the crawl `unit('crawl:client-site')` example (lines 126-144). Replace each with a roadmap row.
13. **Document the actual surface.** `agents/README.md:191` already flags `memory` as "(roadmap)" — promote to a doc page at `web/src/pages/memory.astro` that mirrors the actual code: what's live (fade, mark/warn, forget cascade, learning read API, browse, /memory slash) vs what's roadmap (L6 know-tick, scope attribute, reveal endpoint, crawl unit, contradiction detection). The 16-chapter TOC promises this page exists — currently it does not.

## Files to touch

- `/Users/toc/Server/one-ie/one/claw/src/cron.ts` — add `know-tick` (hourly) + `fade-tick` (5min) entries.
- `/Users/toc/Server/one-ie/one/claw/src/agents/know-promoter.ts` (new) — L6 highway → hypothesis promotion.
- `/Users/toc/Server/one-ie/one/claw/src/agents/fade-ticker.ts` (new) — L3 5-minute fade.
- `/Users/toc/Server/one-ie/one/claw/src/agents/crawler.ts` (new) — recurring crawl unit per `one/crawl.md`.
- `/Users/toc/Server/one-ie/one/claw/src/substrate.ts` — add `scope` param to `rememberHypothesis`; cap p-value by source; add workspace predicate to `recallHypotheses` / `highways` / `actorHighways`.
- `/Users/toc/Server/one-ie/one/web/src/lib/substrate.ts` — add `know`, `recall`, `reveal`, `frontier`, `open`, `sense`, `forget` exports; type `MemoryCard`.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/reveal/[uid].ts` (new) — composed `MemoryCard` endpoint (Article 20).
- `/Users/toc/Server/one-ie/one/web/src/pages/api/learning/index.ts` — clamp confidence by `source` at read time.
- `/Users/toc/Server/one-ie/one/web/src/pages/api/chat.ts` — land the `crawl` tool from `one/crawl.md`.
- `/Users/toc/Server/one-ie/one/one/marketing-schema.tql` — add `scope` attribute on `signal` and `hypothesis`; add `predicate` + `object` attributes on `hypothesis` so contradiction detection is queryable.
- `/Users/toc/Server/one-ie/one/web/src/pages/memory.astro` (new) — chapter 8 surface page; reflects shipped vs roadmap honestly.
- `/Users/toc/Server/one-ie/one/text/08-memory.md` — strip or roadmap-tag the claims that depend on (1)/(3)/(4)/(5)/(6)/(8) until those land.
- `/Users/toc/Server/one-ie/one/agents/crawler.md` (new) — markdown spec for the crawl unit.
- `/Users/toc/Server/one-ie/one/claw/migrations/0004_scope_and_cost.sql` (new) — `claw_paths.cost_acc` column for the "200x" telemetry; `signal.scope` if claw mirrors signals to D1.
