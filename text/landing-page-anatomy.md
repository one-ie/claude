# Anatomy of a high-converting SaaS landing page

A reference for anyone writing or reviewing copy in this folder. Universal anatomy first, ONE-specific addendum at the end. Pair this with [`.claude/product-marketing.md`](../.claude/product-marketing.md) (voice) and [`.claude/skills/writer/SKILL.md`](../.claude/skills/writer/SKILL.md) (craft).

> Median SaaS landing page converts at **3.8%**. Top quartile: **11.6%+**. Best-in-class: **18%**. — Unbounce Conversion Benchmark Report, 2024 (41,000 pages, 464M visitors).
>
> The gap is not magic. It's a stack of decisions — each measurable, each cheap to test, each documented below.

---

## 1. The 5-second test

A visitor lands. They scan. Five seconds later, they should be able to answer three questions out loud:

1. **What is this?** (category — "scheduling", "deploy platform", "CRM")
2. **Who is it for?** (audience — engineers, ops teams, founders)
3. **Why should I care?** (the one outcome they get)

If any answer is missing, the page fails before the scroll.

April Dunford and Wynter both run live 5-second tests on B2B pages. The ones that pass share four traits: a category-anchored headline, a specific subhead, a real product visual above the fold, and one CTA the eye lands on without searching.

---

## 2. The page as a funnel

A landing page is a sequence, not a layout. Every section closes one loop and opens the next.

```
Attention   → Hero                       (2s — am I in the right place?)
Trust       → Logo bar / counts          (5s — others like me use this)
Interest    → Problem · Solution · How   (30s — I see myself in this)
Desire      → Features · Demo · Cases    (2min — this would actually work)
Reassurance → Testimonials · FAQ         (3min — risks handled)
Action      → Pricing · CTA              (5min — what do I do next)
```

Every section has **one job**. Sections that try to do two jobs do neither.

---

## 3. Section-by-section anatomy

Each subsection follows the same template: **Job · Required elements · Variants · Copy patterns · Common mistakes · Data**.

### 3.1 Nav bar

**Job.** Confirm category and offer two paths: explore or convert.

**Required.** Wordmark, 3–5 nav links (Product / Pricing / Customers / Docs), one secondary CTA ("Sign in" or "Book demo"). Sticky on scroll.

**Variants.**
- **Full nav** — multiple product links, mega-menu. Use when product line is broad (Stripe, Notion).
- **Minimal nav** — wordmark + Pricing + Sign in. Use for single-product, conversion-focused (Linear, Cal.com).
- **No nav** — pure landing page for paid traffic. **91% of high-converting paid landers strip the nav** (Unbounce).

**Common mistakes.** Burying Pricing in a dropdown. Stuffing 8+ links. Two CTAs in the nav competing with the hero CTA.

---

### 3.2 Hero

**Job.** In one screen, tell the visitor what this is, who it's for, why it's better, and how to start. Eight seconds, max.

**Required elements.**
- **Eyebrow** (optional) — category tag or "New: …" announcement
- **Headline** — outcome-focused, specific, ≤12 words
- **Subhead** — clarifies, removes one objection, 15–30 words
- **Primary CTA** — action verb + what they get
- **Secondary CTA** (optional) — "See how it works" / "View pricing"
- **Visual** — real product screenshot, short demo loop, or hero video
- **Friction-reducer microcopy** — "No credit card · 2-min setup"

**Variants.**

| Variant | When to use | Examples |
|---|---|---|
| **Centered hero** | Single audience, single outcome, brand-led | Linear, Vercel |
| **Split hero** (copy left, visual right) | Product needs to be shown to be understood | Notion, Loom |
| **Code hero** (live snippet) | Developer audience, integration is the wow | Stripe, Resend, Supabase |
| **Video hero** | Product is itself a video tool, or demo is the product | Loom, Descript |
| **Interactive hero** | Confidence to show the product working in-page | Figma, Linear's command bar |

**Copy patterns** (templates that ship). Each is a real, named formula:

- **{Outcome} in {time}.** — "Accept crypto in 60 seconds."
- **The {category} for {audience}.** — "Scheduling infrastructure for everyone." (Cal.com)
- **{Hard thing} without {pain}.** — "Own your keys without managing them."
- **Unlike {alternative}, {product} {capability} so {value}.** — April Dunford positioning model.
- **{Number} {nouns}. {Result}.** — "Six dimensions. Seven loops. One brain."
- **{Plain truth}.** — "Payments infrastructure for the internet." (Stripe)

**CTA copy.** First-person beats second-person by **15–20%** (CXL): "Start my trial" > "Start your trial". Specific beats generic by **15–30%**: "Start my 14-day trial" > "Get started". One Philadelphia SaaS added "No credit card required" beneath the CTA and saw a **450% lift** in free-trial signups (2025).

**Common mistakes.**
- Clever headline that needs the subhead to decode it
- Stock illustration instead of the real product
- Two equally-weighted CTAs (the eye picks neither)
- Eight bullets in the subhead — kills scannability
- "Get started" / "Sign up" / "Learn more" — generic verbs that survey nothing

**Data.** Matching paid-ad headline to landing-page headline lifted form submissions **+115%** (California Closets). Personalised CTAs convert **+202%** vs. generic (HubSpot). Above-fold customer logos lift trust within the same 8-second window.

---

### 3.3 Logo / social-proof bar

**Job.** In one glance, prove "real companies use this." Borrowed authority before earned authority.

**Required.** 5–8 logos OR one stat line ("Trusted by 8,000+ teams"). Greyscale or single-tone — never coloured logos that compete with the hero.

**Variants.**
- **Logo grid** — strongest for B2B with recognisable customers (Linear, Vercel)
- **Stat line** — "Used by 30M+ people" (Loom) — works when individual logos aren't yet name-brand
- **Live ticker** — "Sarah from Acme just signed up" — **+98% lift** when used carefully (Sumo); destroys trust if faked

**Conversion ladder of social proof** (data from CXL, Wynter, Senja):

| Tier | Type | Lift |
|---|---|---|
| 1 | Logos only | +5–10% |
| 2 | Logos + count | +10–15% |
| 3 | Named text testimonial (name · role · company) | +15–25% |
| 4 | Case study with metric | +30–50% |
| 5 | Video testimonial | +60–80% |

**Common mistakes.** Logos that don't render at small sizes. Anonymous testimonials. "Industry leaders trust us" with no named industry leaders.

---

### 3.4 Problem / agitation

**Job.** Make the reader feel the pain they came with. Skip if the audience is already aware (devtools); essential if you're creating a new category.

**Required.** Named pain · concrete cost · brief amplification. Three sentences max.

**Pattern (PAS).**
> **Problem.** Your team spends 3 hours a week on manual data entry.
> **Agitate.** That's 156 hours a year your team isn't using on strategy.
> **Solve.** {Product} does it in 2 minutes.

**Common mistakes.** Five paragraphs of pain (the reader leaves before relief). Generic pain ("teams struggle with collaboration") — name the *specific* friction. Pain you can't actually solve.

---

### 3.5 Solution / how it works

**Job.** Show the mechanism in 3–4 steps. The reader should be able to retell it.

**Required.** 3 (max 4) labelled steps, each with a one-line explanation and a small visual.

**Variants.**
- **Numbered horizontal** — quick scan (Cal.com: Connect → Share → Get booked)
- **Vertical alternating** — when each step needs a fuller visual (Stripe Atlas)
- **Tabbed walkthrough** — when persona changes the flow

**Common mistakes.** Five steps (the reader gives up at four). Steps that describe *features* instead of the user's actions. Diagrams that need a key.

---

### 3.6 Features

**Job.** Translate capabilities into outcomes. Each feature answers "and so I can…?"

**Required.** 3, 6, or 9 feature blocks (3-grid is canonical). Each: short headline, 1–2 sentence body, supporting icon or thumbnail.

**Variants.**

| Variant | Best when | Example |
|---|---|---|
| **3-column grid** | Equal-weight features | Most SaaS sites |
| **Alternating left/right** | Each feature needs a real screenshot | Linear, Notion — *highest converting per Evil Martians' study of 100 devtool sites* |
| **Bento grid** | 5–7 features of unequal weight; visual brand statement | Apple, Vercel, Raycast — the 2024–25 trend |
| **Tabbed feature switcher** | Many features, one viewport | Figma |

**Copy pattern.** Headline = outcome. Body = mechanism. Never the reverse.
- ❌ "Real-time collaboration with WebSocket sync."
- ✅ "Edit together without refresh. WebSocket sync keeps everyone on the same line."

**Common mistakes.** Feature names without outcomes. Six features when three would have landed harder. Icon walls where the icons say nothing.

---

### 3.7 Product demo / screenshots / video

**Job.** Let them *see it work* before they sign up.

**Required.** Real product UI (not mockup), captioned, plays without sound by default, ≤90 seconds for video.

**Variants.**
- **Annotated screenshot** — fastest LCP, easiest to maintain
- **Looping micro-video** (5–10s, no audio) — high engagement, low file weight
- **Full demo video** (60–90s) — Loom, Descript, Cal.com use this well
- **Interactive demo** (Arcade, Storylane, Navattic) — highest engagement; reach for it when the product *is* the proof
- **Live in-page widget** — Figma's design pane, Linear's command bar

**Common mistakes.** Auto-play with sound. 4-minute "explainer" videos. Mockups that don't match the real UI (instant trust collapse). Videos that hide the actual product behind a face-cam.

---

### 3.8 Use cases / personas

**Job.** Let each visitor self-identify and see their workflow.

**Required.** 3–5 use cases, each with a named persona and one concrete outcome. Tabs or cards.

**Pattern.** "For {role}: {specific outcome}. {One-line proof}."

**Common mistakes.** Vague segments ("teams", "businesses"). Same copy under each tab with the role swapped. More than 5 tabs (decision paralysis).

---

### 3.9 Testimonials & case studies

**Job.** Convert "this looks good" into "people like me succeeded with this."

**Required for testimonials.** Real name · real photo · role · company · specific outcome in the quote. Three to five total — quality over volume.

**Required for case studies.** Customer logo + headline metric + 2-paragraph story + link to full case study (500–1500 words on a separate page).

**Pattern.** Lead each quote with a number.
- ❌ "Game-changer for our team."
- ✅ "Cut our billing time by 60% in the first month." — Sarah Chen, COO, TechCorp

**Common mistakes.** Testimonials that praise the company rather than the outcome. Stock photos. No company name (anonymous = false). "Mr. C., CEO" — full names or cut it.

**Data.** Video testimonials lift conversion **+60–80%** vs. text (Genesys 2025). Named case studies with hard metrics outperform unattributed quotes 2–3×.

---

### 3.10 Integrations

**Job.** Show this fits the stack the visitor already runs.

**Required.** 8–12 logos in a grid, link to a full `/integrations` directory. Group by category if many.

**Common mistakes.** Showing five logos when you have fifty. Showing fifty when you have five.

---

### 3.11 Comparison table

**Job.** End the "is this better than X?" tab in their browser.

**Required.** 4–8 rows, your product as the rightmost column, competitors named honestly. Use ✅ / ➖ / ❌, not vague phrases.

**Common mistakes.** Cherry-picking categories where competitors look bad on irrelevant features. Lying — one wrong row destroys the whole table. Hiding pricing.

**Honesty bonus.** Including a row where a competitor wins makes the rest of the table believable. Cal.com does this with Calendly.

---

### 3.12 Pricing

**Job.** Make the choice obvious. The wrong tier picked is better than no tier picked.

**Required.**
- 3 tiers (4 only if the fourth is enterprise anchor) — **3-tier is the default in 48% of successful SaaS sites; >4 hurts conversion**
- Annual/monthly toggle, **annual pre-selected** (lifts annual adoption +15–30%)
- "Most popular" badge on the middle tier — drives selection +14–23% via decoy effect
- Per-tier feature list, no asterisks
- **Visible price** — never gate the price behind "Contact sales" unless you are pure enterprise

**Variants.**
- **3-tier classic** — Free / Pro / Team
- **3-tier + Enterprise** — Free / Pro / Team / Contact (anchor)
- **Usage-based slider** — Vercel, Render, Cloudflare style; show calculator
- **Per-seat with team multiplier** — Linear, Notion

**Common mistakes.** "Contact sales" as the only option. 12 features per tier (eye gives up). Asterisks and footnotes (trust killer). No annual toggle or annual hidden in a sub-menu.

**Data.** Anchor pricing — listing a higher tier first or showing an enterprise tier — makes the middle tier feel +43% more selectable (Glen Coyne SaaS pricing study).

---

### 3.13 FAQ

**Job.** Capture the last objection before the CTA.

**Required.** 6–12 Q&As covering price, switching cost, security/trust, time-to-value, cancellation, scaling. Accordion or expanded list.

**The seven questions every SaaS FAQ must answer:**
1. How much does it actually cost? (link to pricing)
2. Is there a free trial / how does it end?
3. Can I cancel anytime?
4. How long does setup take?
5. Is my data secure? (SOC2, GDPR, where it's stored)
6. What if I outgrow my plan?
7. Who already uses this? (link to customers)

**Common mistakes.** Soft questions you wish people asked instead of the ones they actually have ("What inspires your team culture?"). 30+ Q&As — that's documentation, not a landing page.

---

### 3.14 Secondary CTA

**Job.** Give the now-warm reader the same on-ramp the hero offered.

**Required.** Same primary CTA copy as the hero. Optional re-stated value prop in one sentence. Optional contact-sales fallback.

**Common mistakes.** Different CTA from the hero (which is correct?). A wall of links. Asking for newsletter signup *here* instead of conversion.

---

### 3.15 Footer

**Job.** Reassure on legal · enable navigation · house secondary links.

**Required.** Wordmark, product/company/legal columns, social, copyright, status page link. 200–300px tall. Status page link signals operational maturity.

**Common mistakes.** 60-link sitemap dump. No legal links (compliance + trust signal missing). Newsletter form bigger than the legal links.

---

## 4. Copy frameworks (the canon)

Ten patterns. Pick one per page; don't mix.

| # | Framework | Template | When |
|---|---|---|---|
| 1 | **JTBD** | "{Product} helps {audience} {job} without {friction}" | Mature category, narrow buyer |
| 2 | **PAS** (Problem · Agitate · Solve) | Name pain → amplify cost → relief | Pain is felt but unsolved |
| 3 | **BAB** (Before · After · Bridge) | Show old world → new world → mechanism | Category shift, transformation story |
| 4 | **Outcome + timeframe** | "{Outcome} in {time}" | You can prove the speed |
| 5 | **Hard thing without pain** | "{Outcome} without {usual cost}" | Differentiation = removal of friction |
| 6 | **Plain truth** | One declarative sentence, no decoration | When the truth is good enough |
| 7 | **Numbered nouns** | "{N} {things}. {result}." | Architecture / system products |
| 8 | **Category for audience** | "The {category} for {audience}" | Carving a sub-category |
| 9 | **April Dunford positioning** | "Unlike {alternative}, {capability} so {value}" | Competitive market |
| 10 | **Real attributed quote** | A customer or thinker said it best | When the quote is *that* good |

**Specificity rule (Harry Dry).** If a competitor could put their logo on your headline and have it still be true, rewrite. "Worn by supermodels in London and dads in Ohio" only works for New Balance.

**Sensory rule.** Concrete nouns are recalled **+200%** vs. abstract concepts. "Touch ID signs every transaction" beats "industry-leading security model."

---

## 5. Psychology — the biases doing the work

| Bias | Mechanism | Tactic |
|---|---|---|
| **Anchoring** | First number colours the rest | Highest tier first; "was $99, now $49" |
| **Loss aversion** | Losses sting 2–3× more than gains feel good | "Don't let your free trial expire" beats "extend your trial" |
| **Social proof** | We do what others do | Logos, counts, named testimonials, live ticker |
| **Authority** | We trust experts | Cite Forrester, Gartner, NN/g; quote named industry voices |
| **Reciprocity** | Free thing → felt obligation | Free tool, calculator, guide (HubSpot Grader: 2M analyses, 3 years) |
| **Scarcity** | Limited = valuable | "Early-bird pricing ends Friday" — only if real |
| **Decoy effect** | A worse option makes another look better | Middle tier feels right next to a worse-value Basic |

**Loss-framed messaging lifts conversion +21%** vs. gain-framed (McKinsey). Use sparingly — it ages worse than gain framing.

---

## 6. Conversion data & benchmarks

Source-cited numbers. Update as new reports drop.

| Metric | Number | Source |
|---|---|---|
| SaaS landing-page median CR | **3.8%** | Unbounce 2024 (41,000 pages) |
| Top-quartile threshold | **11.6%** | Unbounce 2024 |
| Best-in-class SaaS | **18%** | Unbounce 2024 |
| Copy at 5–7th grade reading level | **12.9% CR** vs. 2.1% for "professional" | Unbounce |
| Form 11 → 4 fields | **+120%** | HubSpot |
| Multi-step form vs. single-page | **+300%** | Various, CXL |
| First-person CTA ("Start *my* trial") | **+15–20%** | CXL |
| "No credit card required" | **+25–450%** trial signups | Chargebee, Philadelphia SaaS case |
| Personalised CTA | **+202%** vs. generic | HubSpot |
| Matching paid-ad headline to LP headline | **+115%** | California Closets case |
| Each 100ms LCP increase | **−1 to −3%** conversion | Google Web Vitals |
| Akamai latency study | **100ms = −7% conversions** | Akamai 2017 |
| Google mobile load study | **53% leave** sites slower than 3s | Google 2017 |
| Deloitte "Milliseconds Make Millions" | **100ms = +1.11% session CR** | Deloitte 2020 |
| Cloudflare 1s vs. 10s mobile | **5× better conversion** | Cloudflare 2024 |
| Baymard cart abandonment | **70.19%** average e-commerce | Baymard 2024 |
| Forrester UX ROI | **$1 in UX = $100 return** | Forrester |
| Stripe "10-min API call" rule | Devs who hit a working call in <10min are **4× more likely to integrate** | Stripe 2023 |

**Headline takeaways.**
- The single biggest unforced error is reading level — write at 7th grade and you've already 6×'d the median page.
- The second biggest is form length — every additional field costs −5–10% (CXL).
- The third is page weight — every 100ms beyond 2.5s LCP bleeds 1–3% of conversion.

---

## 7. Performance is a conversion lever

Web Vitals targets — hit these or accept the conversion tax.

| Metric | Good | Needs work | Poor |
|---|---|---|---|
| **LCP** (Largest Contentful Paint) | <2.5s | 2.5–4s | >4s |
| **CLS** (Cumulative Layout Shift) | <0.1 | 0.1–0.25 | >0.25 |
| **INP** (Interaction to Next Paint) | <200ms | 200–500ms | >500ms |

**Receipts.** Economic Times improved LCP 80% (to 2.5s) → bounce −43%. Agrofy cut load abandonment 76% (3.8% → 0.9%) by improving LCP 70%. Red Bus mobile conversion lifted **80–100%** when CLS hit 0.

**Mobile mandate.** Mobile is **79% of SaaS traffic**. Buttons ≥44px, single-column forms, primary CTA above the fold without scroll. Avoid carousel CTAs (swipe converts worse than vertical scroll).

---

## 8. Teardowns — what the best are doing

**Stripe — `stripe.com`.** Hero is a 4-line code snippet on a mesh-gradient background. Headline: "Payments infrastructure for the internet." Two CTAs: "Start now" (self-serve) + "Contact sales" (enterprise). Every word in the hero removes anxiety — pricing is transparent (rare in fintech), the code shows simplicity, the gradient says modern. *Lesson: show the simplest path; let the visual do the trust work.*

**Linear — `linear.app`.** Centered hero: "Linear is a purpose-built tool for planning and building products." Logos of Vercel, Loom, Raycast immediately below. One CTA: "Start building." Almost no top-nav menu. Single screen of perfectly typeset, dark-themed UI. *Lesson: extreme focus and visual restraint outperform feature parades.*

**Vercel — `vercel.com`.** "The AI Cloud for building the best web experiences." Performance is the product *and* the demo — preview deployments are themselves the trust signal. CTA verb is action-specific: "Deploy to Vercel." Bento grid of features. *Lesson: when speed is the product, prove it on the page itself.*

**Cal.com — `cal.com`.** "Scheduling infrastructure for everyone." Two CTAs side-by-side: "Get started free" + "Self-host" — capturing both the lazy buyer and the privacy-conscious buyer with the same hero. Open-source visible above the fold. *Lesson: dual motion can work in the hero if the two paths target different objections.*

**Loom — `loom.com`.** Hero is a Loom video — the product is itself the proof. "Used by 30M+ people" + logos. CTA: "Get Loom for free." The page is the demo. *Lesson: when your product is media, lead with media.*

**Resend — `resend.com`.** Code-first hero. "Email API for developers." Live snippet. Pricing on the homepage. Status page in the footer. *Lesson: developer landing pages reward bluntness — show the call, show the price.*

---

## 9. The 20-point pre-publish checklist

Tick all twenty before shipping.

**Above the fold**
- [ ] Headline passes the 5-second test (what · who · why)
- [ ] Subhead removes one objection
- [ ] One primary CTA, action verb, what they get
- [ ] Real product visual (not stock, not mockup)
- [ ] Friction-reducer microcopy under CTA
- [ ] Logo bar or stat line within the first scroll

**Body**
- [ ] One copy framework, used consistently
- [ ] Every feature headline names an outcome, not a capability
- [ ] At least one named testimonial with a number in the quote
- [ ] Demo or screenshot loop, captioned, no auto-play sound
- [ ] FAQ answers price, cancellation, security, time-to-value
- [ ] Comparison table (if competitors named) is honest

**Pricing**
- [ ] 3 tiers (or 3+1 enterprise anchor)
- [ ] Visible price — no "Contact sales" gate unless pure enterprise
- [ ] Annual toggle pre-selected
- [ ] "Most popular" badge on the intended tier

**Performance & trust**
- [ ] LCP <2.5s, CLS <0.1, INP <200ms — measured, not assumed
- [ ] Mobile primary CTA above the fold without scroll
- [ ] No banned vocabulary anywhere on the page (see voice doc)
- [ ] Every conversion claim has a number and a source

---

## 10. ONE addendum — applying the anatomy

This anatomy is universal. ONE has additional constraints that override defaults.

### Voice — non-negotiable

The full voice contract is in [`.claude/product-marketing.md`](../.claude/product-marketing.md). Summary:

- **Anthony's voice.** First-person where it lands. Plain English. Short sentences. Numbers over adjectives.
- **Three claims, one thesis.** Whoever is fastest wins → the way to be fastest is to remove friction → the way to remove friction is power through simplicity.
- **Banned vocabulary** (full list in voice doc): seamless, robust, cutting-edge, leverage, synergy, holistic, end-to-end, streamline, optimise, empower, transform, delve, "in the realm of." Strip on sight.
- **No exclamation points. Ever.**

If a copy choice clashes with the voice contract, the voice contract wins.

### Speed claims must cite numbers we measure

The voice doc names the targets we measure. Use those, with the date:

| Surface | Target | Use in copy |
|---|---|---|
| Wallet provision | **5s p50** | Hero candidate for `/u`, `/wallet` |
| Crypto checkout | **60s** | Hero for `pay.one.ie` |
| Streaming first token | **<300ms** | `/chat` hero subhead |
| Time to first API call | **1 minute** | `api.one.ie`, SDK landers |
| Time to first agent doing work | **3 minutes** | `github.com/one-ie/one`, agent landers |
| `/chat` page load | **100% Lighthouse** | Live receipt for the speed thesis |

**Every speed claim has a number and a date.** "Fast" without a number is banned.

### Verb-surface parity (ONE-specific)

Every platform verb (CLI · API · MCP · SDK) must be reachable from every surface (web page · chat). Prominence varies by audience; availability is universal. A landing page that hides the SDK from CEOs or the dashboard from engineers fails this rule.

In the **anatomy** terms: the §3.6 features section, the §3.8 use cases section, and the §3.13 FAQ should each include both a CEO-readable framing and an engineer-readable receipt. Stripe is the model — the CEO sees "Payments infrastructure," the engineer sees four lines of code, both on the same screen.

### Anti-patterns banned by the voice contract

The §3.7 demo, §3.6 features, and §3.9 testimonials are the highest-risk sections for voice violations. Specifically:

- ❌ Stock-illustrated abstract shapes for features → ✅ real product UI fragments
- ❌ "Industry-leading" / "best-in-class" badges → ✅ a measured number
- ❌ Anonymous "CEO, Fortune 500" testimonials → ✅ named or cut
- ❌ Hero auto-play with sound → ✅ silent loop, captioned
- ❌ "Schedule a demo" as the only CTA → ✅ self-serve first, demo as fallback
- ❌ Long generic FAQ filler → ✅ the seven questions in §3.13, no padding

### ONE-specific section additions

For ONE pages, slot two sections most universal SaaS pages skip:

- **The substrate receipts.** "~670 lines of runtime. 6 dimensions. 7 loops. 5 wallet states. 1 substrate." — Dunford-style positioning by counting the real things.
- **You own your keys.** A standalone trust block, not buried in features. Secure Enclave + Touch ID, named by name. This is ONE's primary differentiator and gets its own real estate.

### Where to put what on ONE surfaces

| Surface | Hero pattern | Key sections | Voice angle |
|---|---|---|---|
| `one.ie` (homepage) | Plain truth + numbered nouns | Hero · Trust · How · Features · Substrate receipts · Pricing · CTA | Fast → Easy → Simple, all three |
| `pay.one.ie` | Outcome + timeframe ("Accept crypto in 60 seconds") | Hero · Logo bar · How (3 steps) · Code hero · Pricing · CTA | Speed-first; receipts heavy |
| `/chat` | Plain truth | Hero · Live demo (the page itself) · Use cases · CTA | Ease-first; the page is the proof |
| `api.one.ie` | Code hero | Hero · Quickstart · Reference · Pricing | Engineer-trust; show the call |
| `github.com/one-ie/one` README | Numbered nouns | Hero · `npx oneie` · Examples · Architecture | Simplicity-first; the receipts are the README |

### Verification — before merging any copy in `text/`

1. **Voice check.** Read aloud. Sounds like Anthony at the pub on a Friday? No banned vocabulary? Pass.
2. **Data rule.** Every claim cited (third-party study, ONE measurement with date, or named example). No bare adjectives.
3. **Anatomy check.** Each section has one job — does it? Hero passes the 5-second test?
4. **Speed audit.** Page hits LCP <2.5s, CLS <0.1, INP <200ms on mobile.
5. **Verb-surface parity.** Both CEO and engineer leave with what they came for?
6. **5,000-word ceiling.** This file. If it's growing, cut.

---

## Sources

Structural and data citations throughout this doc draw from:

- Unbounce — Conversion Benchmark Report 2024 · State of SaaS Landing Pages
- CXL (ConversionXL) — form length, CTA colour, button copy A/B archive
- Nielsen Norman Group — F-pattern, deceptive patterns
- Baymard Institute — checkout friction, cart abandonment 2024
- HubSpot — form-field benchmarks, personalised CTA study
- Akamai 2017 · Google 2017 · Deloitte 2020 · Cloudflare 2024 — latency vs. conversion
- April Dunford — *Obviously Awesome* positioning model
- Marketing Examples (Harry Dry) — specificity, sensory writing
- CopyHackers (Joanna Wiebe) — headline frameworks, CTA testing
- Evil Martians — analysis of 100 devtool landing pages (alternating-feature finding)
- Live page analysis: Stripe, Linear, Vercel, Cal.com, Loom, Notion, Attio, Resend, Supabase

Companion docs in this repo:

- [`.claude/product-marketing.md`](../.claude/product-marketing.md) — voice & thesis (load-bearing)
- [`.claude/skills/writer/SKILL.md`](../.claude/skills/writer/SKILL.md) — craft layer
- [`text/CLAUDE.md`](CLAUDE.md) — folder contract
