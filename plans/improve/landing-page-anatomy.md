# landing-page-anatomy — gap analysis

Source spec: `text/landing-page-anatomy.md` (§3.1–3.15 · 15 sections · 20-point pre-publish checklist · ONE addendum §10).
Voice contract: `.claude/product-marketing.md`.

---

## Promise (prescribed anatomy)

A converting SaaS landing page is a sequence of 15 sections, each closing one loop and opening the next. The funnel order is fixed:

```
Nav → Hero → Logos → Problem → How → Features → Demo → Use cases
   → Testimonials → Integrations → Compare → Pricing → FAQ → Secondary CTA → Footer
```

Above-the-fold elements (the 5-second test) are non-negotiable:

- **Eyebrow / headline / subhead** — answers "what · who · why" in 5 seconds.
- **One primary CTA** — action verb + outcome, first-person preferred.
- **Friction-reducer microcopy** — "No credit card · 2-min setup."
- **Real product visual** — screenshot, loop, or in-page widget.
- **Logo bar or stat line** inside the first scroll.

ONE addendum (§10) adds three load-bearing constraints:

1. **Speed claims cite a measured number with a date.** Banned: "fast", "lightning-fast".
2. **Verb-surface parity.** Every page serves CEO + engineer on the same screen — Stripe model.
3. **Two ONE-specific blocks:** *Substrate receipts* (Dunford-style numbered nouns — "670 lines. 6 dimensions. 7 loops.") and *You own your keys* (Secure Enclave + Touch ID, named).

Plus the 7-question FAQ floor: price · trial · cancel · setup time · security · scaling · who uses this.

---

## Code reality (page-by-page audit)

### `/` (`web/src/pages/index.astro`)

Renders four React islands inside `<Layout>`:

```
PersonalizedHero (Hero.tsx)
  → Buyers (logo bar — 4 icon labels: Agencies / Organizations / Governments / AI Agents)
  → Strategy (3 pillars: Speed / Reach / Ownership)
  → Personas (4-tile audience selector — seeds chat)
```

That's it. No problem section, no demo/screenshot, no testimonials, no integrations, no comparison, no pricing on the home, no FAQ, no secondary CTA, no footer-of-substance.

Hero copy (`personalize-map.ts` default):
- Eyebrow: "White-label · Web + Mobile"
- Headline: "The fastest **AI brand** you can sell."
- Sub: "One platform. Any vertical. Set your price, keep the margin. Sell on web and mobile in minutes."
- Primary CTA: "Get yours" → `/get-yours` (which 301s to `/create`).
- Secondary CTA: "Learn more" → `#strategy` anchor.

Issues against §3.2:
- "Learn more" is the exact generic verb banned by the voice contract and §3.2 ("survey nothing").
- No friction-reducer microcopy under the CTA. `/create` page has "Free forever · No credit card" but the home hero doesn't surface it.
- No real product visual above the fold. `Hero.tsx` is text-only with `<br>` and a colored span — no screenshot, no loop, no live widget.
- "In minutes" is the only speed claim, with no number and no date. Violates §10 voice contract ("Every speed claim has a number").
- `Buyers.tsx` is a stat-less logo-substitute — generic noun labels with Lucide icons, not real customer logos. Tier 1 of the §3.3 social-proof ladder at best, and arguably below (no count, no real names).

### `/chat` (`web/src/pages/chat.astro`)

20 lines. Renders only `<Chat client:idle fullPage>` inside a full-viewport div. This is intentional — the page *is* the product proof (§3.7 "Live in-page widget"). It scores 100% Lighthouse, which is the receipt the voice doc wants. But as a landing page for paid traffic, it has no nav-stripped marketing surface above the chat — no headline, no CTA, no speed claim, no FAQ. It assumes the visitor already wants to chat.

### `/dashboard` (`web/src/pages/dashboard.astro`)

58 lines. Authenticated surface, not a landing page. Not in scope.

### `/get-yours` (`web/src/pages/get-yours.astro`)

5 lines. 301 redirect to `/create`. No anatomy.

### `/create` (`web/src/pages/create.astro`)

232 lines. Split-hero conversion page — best-shaped landing page in the repo.

- **Left panel:** brand color block. Eyebrow-less headline "Your workspace, your keys." Subhead names Touch ID. 4 bulleted feature rows (own keys / no password / works on devices / portable).
- **Right panel:** `PasskeyCreate` form card with "Free forever · No credit card" microcopy under the header.
- **Invite mode** swaps the bullets and headline to "You've been invited" — different audience, same shape.

Issues against §3.2 / §10:
- Hero passes the 5-second test (what · who · why are answerable from the headline + sub).
- Friction reducer present ("Free forever · No credit card") — good.
- No speed claim with number. "Create a workspace in seconds" — no measured number, no date. Should cite the **5s p50 wallet provision** from the product-marketing.md surface table.
- No social proof / logos / stat line.
- No demo visual — the form *is* the demo, defensible.
- No pricing visible. (Could be intentional for a free-tier conversion page.)
- No FAQ — at least the 4-bullet feature list answers "is my data secure" implicitly. But cancel / pricing / who uses it are not addressed anywhere on the page.

### `/agents` (`web/src/pages/agents.astro`)

184 lines. Marketplace browser, not a landing page in the §3.2 sense. Header is `<h1>Agents</h1>` + 1-line sub + filter chips + cards. No hero, no speed claim, no CTA strategy. Treats visitors as already-converted.

### `/marketplace` (`web/src/pages/marketplace.astro`)

86 lines. Same shape as `/agents`. Header + filter info card + grid. No hero, no demo, no testimonials, no pricing, no FAQ. The "info card" telling partners to add `marketplace: true` to frontmatter is the only call-to-action — engineer-only, no CEO surface.

### `/partners` (`web/src/pages/partners.astro`)

143 lines. Directory list with empty-state placeholder. "Independent publishers building AI agents on ONE. Revenue goes directly to authors." That's the entire pitch. No hero numbers (e.g. "Authors earn 70%" is shown on each card badge but never headlined), no demo of the earnings flow, no comparison vs. alternatives, no pricing/revenue split table, no FAQ.

### `/payments` (`web/src/pages/payments.astro`)

9 lines. Empty page or redirect. **Critical gap** — the voice doc explicitly cites `pay.one.ie` with hero pattern "Accept crypto in 60 seconds" and notes payments as a primary surface in the speed-receipts table. The on-`one.ie` `/payments` route is essentially missing.

### `/scale` (`web/src/pages/scale.astro`)

330 lines. **The strongest page in the repo by §10 standards.**

- Hero: dated speed claim ("5,000 requests/second · 60 seconds · one million users · 2026-05-16").
- Live attributed quote (Klaus Schwab — fast fish eats slow fish).
- 4-up headline numbers (requests sent · success rate · sustained RPS · p95 latency).
- Per-second RPS chart drawn from real log timeline.
- Stack comparison table (Express vs Lambda vs ONE — §3.11 done well).
- Engineering journey (4 fixes from broken to proven — close to §3.4 problem/agitation/solve).
- Missing: pricing, FAQ, secondary CTA, testimonials.

This is the only page that fully honors "every speed claim has a number with a date" — and it does so 4 separate times.

### `/studio/[agent]` (`web/src/pages/studio/[agent].astro`)

360 lines. Markdown-driven. Reads `journey:` / `sections:` / `theme:` / `ui:` from `web/agents/<name>.md` and renders a hero image (auto-fetched from loremflickr), funnel stages, quick-prompt pills, then `SectionRenderer` for each declared section (10 kinds: stat · card · grid · list · compare · cta · embed · code · timeline · hotel). Chat is always present on the right.

Anatomy-wise:
- Hero is image + title + description over a black-gradient overlay. No eyebrow, no friction-reducer microcopy, no primary CTA distinct from "Start this step". The CTA is the journey funnel itself.
- The journey funnel is essentially a §3.5 "how it works" — 4–6 numbered stages with bullets, owned by markdown frontmatter. Strong shape.
- `sections:` covers §3.6 features (`stat`, `grid`, `card`), §3.7 demo (`embed`, `code`), §3.11 compare (`compare`), §3.8 use cases (`grid` with personas), §3.14 secondary CTA (`cta`), and a kind for `hotel`/property listings. No primitives for **logo bar**, **testimonials**, **pricing**, or **FAQ**.
- A `timeline` kind exists, but not a `pricing` or `faq` kind. Authors who follow the §3.13 7-question FAQ floor have to bend `compare` or write raw HTML in a `card` — neither is good.

### `/showcase`, `/skills`, `/tools`, `/vietnam` (9 lines each)

Stub or redirect. No anatomy.

### `/design` (1105 lines), `/motion` (691 lines)

Internal design-system surfaces. Not landing pages.

---

## Gaps (missing sections, wrong order, missing CTAs)

| Gap | Severity | Where |
|---|---|---|
| Generic CTA verb "Learn more" on home secondary | high | `Hero.tsx:39` |
| No friction-reducer microcopy under home primary CTA | high | `Hero.tsx:32–34` |
| No real product visual above the fold on home | high | `Hero.tsx` whole component |
| Speed claim "in minutes" with no number, no date | high | `Hero.tsx:25` |
| Logo bar is generic icon labels, not real customer logos or a `Trusted by N+ teams` stat line | high | `Buyers.tsx` |
| No problem/agitation section anywhere on home | medium | missing |
| No how-it-works / mechanism on home (Strategy is positioning, not steps) | medium | missing |
| No testimonials with named quotes + numbers (§3.9 floor) anywhere site-wide except `/scale` chart | high | missing on `/`, `/create`, `/agents`, `/marketplace`, `/partners`, `/studio/*` |
| No pricing visible on home — `Pricing.tsx` component exists but is unused on `index.astro` | high | `Pricing.tsx` orphaned |
| No FAQ block on home, `/create`, `/agents`, `/marketplace`, `/partners`, `/studio/*` — the 7-question floor is unmet everywhere except… nowhere | high | site-wide |
| No comparison table on home; only `/scale` has one | medium | site-wide |
| No integrations / chains-supported grid on home | medium | site-wide |
| No secondary CTA at the bottom of any page (the hero CTA does not repeat after long scroll) | medium | `/`, `/create`, `/scale` |
| No footer-of-substance — no legal columns, no status page link, no nav columns visible from page reads | high | `Layout.astro` (assumed; not opened) |
| `/payments` is a 9-line stub but voice doc cites it as a primary surface with "Accept crypto in 60 seconds" hero | critical | `payments.astro:1–9` |
| `/marketplace` and `/agents` treat visitors as already-converted — no hero, no CTA strategy, no proof | high | both pages |
| `/partners` revenue pitch ("70% to authors") is buried on cards, not in a hero number | high | `partners.astro` |
| `/studio/[agent]` markdown has no `faq`, `pricing`, `testimonial`, `logos` section kinds — authors cannot honor the 7-question FAQ floor without raw HTML | high | `SectionRenderer.astro`, `agent-authoring.md` ten-primitives table |
| Substrate receipts block ("670 lines. 6 dimensions. 7 loops.") from §10 ONE addendum appears nowhere | medium | site-wide |
| "You own your keys" trust block from §10 ONE addendum appears on `/create` left panel, nowhere else | medium | site-wide |
| `/chat` is the live-product-as-proof per §10, but has no CEO-readable hero for paid traffic | medium | `chat.astro` |
| Verb-surface parity violated on `/marketplace` — only engineer copy (`oneie agent fork <id>`); no CEO framing | medium | `marketplace.astro:32–37` |

Order issues: where landing-page sections exist, order is mostly correct (hero → trust → strategy → personas on `/`). The problem is missing sections, not misordered ones.

---

## Recommended improvements

Three waves, ordered by lift × cost.

### Wave 1 — fix the home hero and add the missing primitives (highest lift)

1. **Rewrite the home hero CTA pair.** Primary stays "Get yours" but with friction-reducer microcopy underneath ("Free · 5-second wallet · No credit card"). Secondary CTA: rename "Learn more" → "See it work" or "Watch the 60-second demo" — verb + outcome.
2. **Add a real product visual above the fold.** Either (a) embed the `/chat` widget itself as the hero visual (the page becomes its own demo, §3.7 "Live in-page widget"), or (b) drop in a captioned loop of the 5-second wallet provision flow.
3. **Cite measured speed numbers in the hero subhead.** Replace "in minutes" with one of: "5-second wallet · 60-second checkout · 100% Lighthouse on /chat." Numbers come from `.claude/product-marketing.md` §1 surface table. Add date in a tooltip or as the eyebrow.
4. **Replace `Buyers.tsx` icon-labels with either real logos or a single stat line.** Stat-line option: "Used by 8,000+ workspaces · April 2026." Cite a measured number, not a placeholder.
5. **Compose `Pricing` into `index.astro`.** The component already exists, unused. Drop it in between `Strategy` and `Personas`. Set annual pre-selected and add "Most popular" badge on the Pro tier (already wired in the component data).

### Wave 2 — site-wide floors

6. **Add an FAQ component and slot it on `/`, `/create`, `/partners`, `/scale`.** Use the §3.13 7-question floor: price · trial · cancel · setup time · security · scaling · who uses this. Per-page answers vary but the questions are fixed.
7. **Add `kind: faq`, `kind: pricing`, `kind: testimonial`, `kind: logos` to `SectionRenderer.astro`** and document in `web/agent-authoring.md` §"The ten section primitives" (which becomes "fourteen"). Authors can then honor the FAQ floor without raw HTML.
8. **Build out `/payments` to the voice-doc spec.** Hero: "Accept crypto in 60 seconds." How (3 steps). Code hero (the receive-side `@oneie/sdk` call). Pricing. Logos of supported chains (§3.10 integrations). This is the single biggest missing page.
9. **Add a "substrate receipts" component** and slot it on `/`, `/scale`, README. Dunford numbered-nouns: "~670 lines of runtime. 6 dimensions. 7 loops. 5 wallet states. 1 substrate."
10. **Add a "you own your keys" trust block** as a standalone shadcn-card and slot it on `/`, `/payments`. Same shape as the `/create` left panel.

### Wave 3 — polish

11. **Reframe `/marketplace` and `/agents` with a CEO-readable hero** above the existing grids. Headline + one-line value prop + primary CTA (`Browse the marketplace`) + secondary (engineer code snippet for `oneie agent fork`). Verb-surface parity (§10) satisfied in one screen.
12. **Reframe `/partners` with a headline number in the hero** — "Keep 70% of every sale." Stack the testimonials/case-study block under it.
13. **Repeat the hero primary CTA at the bottom of every long page** (`/`, `/create`, `/scale`). §3.14 secondary-CTA contract: same copy, restated value prop, no newsletter form.
14. **Audit `Layout.astro` footer** — confirm legal columns, status-page link, social. Cut newsletter form if oversized vs. legal links.

---

## Files to touch

| Path | Change |
|---|---|
| `web/src/pages/index.astro` | Add `Pricing`, new `Faq`, new `SubstrateReceipts`, new `OwnYourKeys`, new `SecondaryCta` islands; add a real hero visual block before `<PersonalizedHero>` or wrap one within it |
| `web/src/components/Hero.tsx` | Rename secondary CTA; add friction-reducer microcopy; add a visual slot (image / loop / `<iframe src="/chat?embed=widget">`) |
| `web/src/lib/personalize-map.ts` | Replace "in minutes" with a measured number for `default`, `founder`, `agency`, and any other variant |
| `web/src/components/Buyers.tsx` | Replace icon-labels with real customer logos OR a single dated stat line |
| `web/src/components/Pricing.tsx` | Compose into `index.astro`; verify annual toggle pre-selected and "Most popular" badge present (data exists, render layer may not) |
| `web/src/components/Faq.tsx` | **New.** 7-question accordion. Accept `items` prop so per-page answers vary |
| `web/src/components/SubstrateReceipts.tsx` | **New.** Numbered nouns block (Dunford pattern). Reusable on `/`, `/scale`, `/payments` |
| `web/src/components/OwnYourKeys.tsx` | **New.** Trust block — Secure Enclave + Touch ID. Reusable on `/`, `/payments` |
| `web/src/components/SecondaryCta.tsx` | **New.** Restated primary CTA + 1-line value prop. Reusable on every long page |
| `web/src/pages/payments.astro` | **Rewrite.** Full landing page to voice-doc spec — hero · how · code hero · pricing · chain logos · CTA |
| `web/src/pages/marketplace.astro` | Add CEO-readable hero before the grid; keep the engineer code snippet as secondary |
| `web/src/pages/agents.astro` | Add CEO-readable hero before the grid |
| `web/src/pages/partners.astro` | Add hero with "Keep 70%" headline number; testimonials slot |
| `web/src/pages/scale.astro` | Add `Pricing`, `Faq`, `SecondaryCta` blocks |
| `web/src/pages/create.astro` | Add Faq below the form on mobile; add a small "Used by 8,000+ workspaces" stat under the bullets |
| `web/src/components/journey/SectionRenderer.astro` | Add `kind: faq`, `kind: pricing`, `kind: testimonial`, `kind: logos` |
| `web/agent-authoring.md` | Document the new section kinds in the ten-primitives table |
| `web/src/layouts/Layout.astro` | Audit footer; ensure legal columns, status link, no oversized newsletter form |

Lighthouse rule: every new component on `/`, `/chat`, `/create` must be lazy-loaded if heavy (§`astro.md` performance rule). `Faq`, `SubstrateReceipts`, `OwnYourKeys`, `SecondaryCta` are all below-fold and should ship with `client:visible` or static (no hydration).
