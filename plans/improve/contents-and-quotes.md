# contents-and-quotes — gap analysis

## Promise (TOC structure + quote inventory)

**`text/contents.md`** is the working TOC for the brand book / PDF / site. It enumerates 16 top-level surfaces:

```
Build Your Brand · Build your Agency · Chatbots (Web / Messaging / Groups) ·
Models · Agents · Skills · Tools · Memory · Teams (Marketing / Sales / Service) ·
Tracking · Analytics · CRM · Learning · Development (CLI / API / SDK / MCP /
ADL / Ontology / DSL / Dictionary) · Security · Speed
```

These are mirrored 1:1 by the 17-page PDF in `/Users/toc/Server/one-ie/one/text/` (`00-cover.md` … `16-speed.md`), each ~5k words, passing the `text/verify.sh` gate at rubric ≥ 0.90 — see `text/text-plan.md` and `text/text-todo.md`.

**`text/quotes.md`** is a curated bank of ~150 attributed quotes across 8 parts:

- Part I  Speed (classic tech, Zuck/Jobs/Schwab/Hoffman)
- Part II Speed→conversion stats (Amazon Linden, Walmart, Akamai, Google, Bing, Shopzilla, Pfizer, BMW, Vodafone)
- Part III AI latency (TTFT, Alhena, Bessemer)
- Part IV AI agents (Gates, Altman, Huang, Karpathy, Pichai)
- Part V Distribution / brand (Naval, Neumeier, Ben Thompson, Collison, Bezos, McLuhan, Gibson)
- Part VI Simplicity (da Vinci, Saint-Exupéry, Dijkstra, Bell, Kernighan)
- Part VII Anthony O'Connell originals (~35 founder quotes on self-learning, AI, marketing, education, competence, engineering, strategy, emergence, AGI)
- Part VIII Emergence / swarm / AGI / superintelligence (Anderson, Minsky, Bonabeau/Dorigo, Grassé, Kauffman, Wolfram, Hassabis, Sutskever, I.J. Good)
- Plus an **operator-grade bank** (Klarna/Siemiatkowski, Siu, IDHL, Butler-Till, Vaynerchuk) + analyst bank (McKinsey, BCG, Bain, Gartner, Forrester, Salesforce) + pressure bank (WPP Read, CMO Barometer, ANA) + incumbent bank (Sadoun, Wren, Bolloré, Igarashi, Benioff, Huang, Nadella)
- Plus 4 pre-built **clusters** at the footer (Threat / FOMO / TAM / Incumbent-bet) — explicitly tagged "deck-ready"

The text-plan binds specific quote buckets to each PDF page via a `Page-to-bucket map` in `text/text-todo.md`. The integrity rule is binding: `quotes.md` is the **only** source — no paraphrase, no training-data quotes, ever.

## Code reality

### Site IA vs TOC

Live pages in `web/src/pages/`:

```
index · chat · agents · skills · tools · payments · settings · dashboard ·
marketplace · marketing-studio · partners · create · get-yours · scale ·
showcase · motion · design · vietnam · 404 · 500 · recovery-codes ·
in/[groupId] · u/[slug] · studio/[agent] · studio/discovery-dashboard ·
studio/field-service-dashboard · studio/ptcorp-dashboard · crm/* · settings/* ·
share/* · go/* · api/*
```

Comparison against `contents.md` 16 top-level surfaces:

| TOC surface         | Live page                          | Status |
|---------------------|------------------------------------|--------|
| Build Your Brand    | `/get-yours`, `/create`            | partial — no dedicated `/brand` |
| Build Your Agency   | `/partners` (publishers list only) | thin — no whitelabel / billing IA |
| Chatbots (Web)      | `/chat`, `/showcase`               | yes |
| Chatbots (Messaging)| —                                  | **missing** — no Telegram/iMessage page |
| Chatbots (Groups)   | `/in/[groupId]`                    | yes |
| Models              | —                                  | **missing** — no `/models` |
| Agents              | `/agents`, `/studio/[agent]`       | yes |
| Skills              | `/skills`                          | yes |
| Tools               | `/tools`                           | yes |
| Memory              | —                                  | **missing** |
| Teams (M/S/Service) | —                                  | **missing** — `/marketing-studio` only |
| Tracking            | —                                  | **missing** (despite load-bearing PDF page) |
| Analytics           | `/agents/[id]/analytics` (nested)  | partial — no top-level `/analytics` |
| CRM                 | `/crm/*`                           | yes |
| Learning            | —                                  | **missing** (despite load-bearing PDF page) |
| Development         | —                                  | **missing** — no `/cli`, `/api`, `/sdk`, `/mcp`, `/adl`, `/ontology`, `/dsl`, `/dictionary` page |
| Security            | —                                  | **missing** |
| Speed               | `/scale`, `/motion`                | yes (rebadged) |

Coverage: ~7 of 18 TOC nodes have a real page. 11 are absent. The PDF has shipped at 90k words but the site IA hasn't caught up.

The root `README.md` headings (`See it work · Why ONE · Quick start · How it works · Example agents · The six verbs · Packages · What's in this repo · Documentation`) describe the SDK/CLI surface, not the agency-product TOC. README and contents.md are written for different audiences and they do not reconcile.

### Quote usage in product

`grep -rli` across `web/src/` for the most distinctive quote markers (Anthony O'Connell, Klarna, Sebastian Siemiatkowski, McKinsey, Naval, Bezos, Linden, BCG, Bain, Forrester, Hassabis, Sadoun, Benioff, Karpathy, Klaus Schwab):

- **Single quote in production:** `/Users/toc/Server/one-ie/one/web/src/pages/scale.astro` line 91-93 — Klaus Schwab "fast fish eats slow fish."
- **One unattributed pull-quote** in `/Users/toc/Server/one-ie/one/web/src/pages/scale.astro` line 286-288 (own benchmark sentence, not from quotes.md).
- **One `<blockquote>`** in `/Users/toc/Server/one-ie/one/web/src/pages/motion.astro` line 45-48 — design tension copy, not from quotes.md.
- **`QuoteCard` components** at `web/src/components/chat/cards/QuoteCard.tsx` and `BoqQuoteCard.tsx` — these are **pricing-quote** cards (field-service estimates), not pull-quotes / testimonials. Name collision only.
- **A `testimonial` section type is wired** in `web/src/components/journey/SectionRenderer.astro` line 486-505 (renders `quote` + `author` + `role` blockquotes). **Zero agent markdowns use it** — `grep -rln 'kind: testimonial' web/agents/ agents/` returns nothing.
- **Zero Anthony O'Connell founder quotes** appear anywhere in `web/src/`. 35 founder lines sit in `quotes.md` and the PDF; none are deployed as social proof, hero subhead, or section closer.
- **Zero operator-grade quotes** (Klarna 25%, Forrester 15% agency-role cut, WPP $300M, Publicis €300M, Benioff "digital labor", CMO Barometer 12%) appear on the public site, despite text-plan flagging them as conversion-critical for the agency-CEO PDF.
- **Zero pre-built clusters** (Threat / FOMO / TAM / Incumbent-bet) appear as deployed UI components.

## Gaps

1. **IA gap.** 11 of 18 contents.md TOC nodes have no dedicated route. The PDF is the spec; the site is two cycles behind. Most painful misses: Models, Memory, Teams (M/S/Service), Tracking, Learning, Development, Security — all of which have a finished PDF chapter at rubric ≥ 0.90 ready to lift.

2. **Quote-deployment gap.** ~150 curated quotes exist, including 35 owned founder quotes that *cannot* be copy-pasted by competitors. Public site uses exactly **1** of them (Schwab on `/scale`). The asymmetric advantage of Part VII (Anthony originals) is unrealised — no `<TestimonialBand>` on `/`, no founder pull-quote on `/agents` or `/scale`, no operator cluster on the homepage hero, no FOMO bar above the agency pricing.

3. **Component gap.** A `testimonial` section type exists in `SectionRenderer.astro` but no React `<PullQuote>`, `<TestimonialCard>`, `<QuoteCluster>`, or `<FoundersVoice>` component lives in `web/src/components/`. The renderer hook is there; the marketing surfaces never reach for it. No agent markdown uses `kind: testimonial` either, so the studio pages don't surface social proof.

4. **Single-source-of-truth gap.** `text/quotes.md` is binding for the PDF via `text/verify.sh` step 7 (quote-traceability grep). The web has no equivalent — quotes could drift or be invented in JSX with no enforcement.

5. **README↔contents.md drift.** README's top-line ("AI agents that learn. Build in markdown. Deploy everywhere.") matches the SDK pitch, not contents.md's agency-brand framing ("Build your AI Brand · Attract, convert and grow customers with AI"). Two valid stories told in two places, with no map between them.

## Recommended improvements

1. **Add five missing routes that already have a finished PDF chapter** — promote the rubric≥0.90 PDF text as the seed copy for each:
   - `/models` (from `text/04-models.md`)
   - `/memory` (from `text/08-memory.md`)
   - `/teams` with three children `/teams/marketing`, `/teams/sales`, `/teams/service` (from `text/09-teams.md` — load-bearing per text-todo)
   - `/tracking` (from `text/10-tracking.md` — load-bearing)
   - `/analytics` top-level (from `text/11-analytics.md` — load-bearing, renewal deliverable)
   - `/learning` (from `text/13-learning.md` — load-bearing)
   - `/development` with children for CLI/API/SDK/MCP/ADL/Ontology/DSL/Dictionary (from `text/14-development.md`)
   - `/security` (from `text/15-security.md`)
   - `/brand` and `/agency` as proper marketing pages (from `text/01-brand.md` and `text/02-agency.md`), distinct from `/get-yours` and `/partners`.

2. **Build three React components, deployed against `quotes.md`:**
   - `<PullQuote quote author year source />` — single quote, used inline on every marketing page.
   - `<QuoteCluster cluster="threat|fomo|tam|incumbent" />` — renders the four pre-built footer clusters from `quotes.md`. Use on `/`, `/agency`, `/teams`, `/analytics` per the same page-to-bucket map text-todo uses for the PDF.
   - `<FoundersVoice tag="self-learning|marketing|engineering|strategy|emergence" />` — picks one Anthony O'Connell quote from Part VII at random or by tag. This is the unique-to-ONE asset; deploy it as the hero subhead on `/`, between Hero and Strategy on `/index`, as the closer on `/agents`, `/scale`, `/skills`.

3. **Single-source the quotes** — components import from a generated `web/src/data/quotes.ts` built from `text/quotes.md` (script in `text/build/`). Add a `web/verify-quotes.sh` that mirrors `text/verify.sh` step 7: every blockquote in `web/src/**/*.{astro,tsx}` must be traceable to `quotes.md`. Run in CI.

4. **Wire the `testimonial` section type** in at least three agent markdowns (e.g. `web/agents/marketing-strategist.md`, `agents/cmo.md`, a new `agents/brad.md`) so `/studio/[agent]` pages show pull-quotes by default. This activates the dormant `SectionRenderer.astro` branch.

5. **Reconcile README + contents.md.** Either:
   - Lift the contents.md top-line ("Build your AI Brand · Attract, convert and grow customers with AI") into README as the second-line positioning, with the SDK pitch staying first; or
   - Move the SDK-flavoured README to `sdk/README.md` and write a new root README that mirrors contents.md (the agency-brand frame). Cross-link both ways.

6. **One pheromone hook on every deployed quote.** `emitClick('ui:quote:<id>')` on the quote container, so the substrate learns which quotes earn dwell / scroll-through / CTA-click. Quotes become A/B-testable assets, not decoration.

## Files to touch

- `/Users/toc/Server/one-ie/one/web/src/pages/brand.astro` (new — seed from `text/01-brand.md`)
- `/Users/toc/Server/one-ie/one/web/src/pages/agency.astro` (new — seed from `text/02-agency.md`)
- `/Users/toc/Server/one-ie/one/web/src/pages/models.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/memory.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/teams.astro` (+ `teams/marketing.astro`, `teams/sales.astro`, `teams/service.astro`)
- `/Users/toc/Server/one-ie/one/web/src/pages/tracking.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/analytics.astro` (new, top-level)
- `/Users/toc/Server/one-ie/one/web/src/pages/learning.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/development.astro` (+ children: `cli`, `api`, `sdk`, `mcp`, `adl`, `ontology`, `dsl`, `dictionary`)
- `/Users/toc/Server/one-ie/one/web/src/pages/security.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/components/PullQuote.tsx` (new)
- `/Users/toc/Server/one-ie/one/web/src/components/QuoteCluster.tsx` (new)
- `/Users/toc/Server/one-ie/one/web/src/components/FoundersVoice.tsx` (new)
- `/Users/toc/Server/one-ie/one/web/src/data/quotes.ts` (new — generated from `text/quotes.md`)
- `/Users/toc/Server/one-ie/one/text/build/quotes-to-ts.mjs` (new — generator)
- `/Users/toc/Server/one-ie/one/web/verify-quotes.sh` (new — mirror of `text/verify.sh` step 7)
- `/Users/toc/Server/one-ie/one/web/src/lib/menu.ts` (extend with new routes, role-gated where needed)
- `/Users/toc/Server/one-ie/one/web/src/pages/index.astro` (add `<FoundersVoice>` between `<Buyers>` and `<Strategy>`; add `<QuoteCluster cluster="fomo">` near pricing)
- `/Users/toc/Server/one-ie/one/web/agents/marketing-strategist.md` (add `sections: - kind: testimonial`)
- `/Users/toc/Server/one-ie/one/agents/cmo.md` (add testimonial section)
- `/Users/toc/Server/one-ie/one/README.md` (reconcile top-line with contents.md framing, or split SDK README)
- `/Users/toc/Server/one-ie/one/text/contents.md` (after site catches up, mark which TOC nodes have a live route)
