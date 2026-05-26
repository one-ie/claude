# Product marketing context — ONE

Auto-loaded by writing and copy skills before they ask questions. This is
the voice, audience, persona, and product context every piece of ONE
marketing copy must match.

**Companion file:** [`.claude/skills/writer/SKILL.md`](skills/writer/SKILL.md)
is the craft layer — how to draft, cut, structure, polish. This file is
the voice layer — who we are, who we write for, how we sound.

---

## Voice — Anthony

ONE's marketing voice is **Anthony's voice.** First-person where it lands
naturally. The writer is a real person with a real track record.

The reader doesn't need this stated. They need to feel it through the
writing:

- 30 years building websites. From static HTML to edge runtimes.
- 8 years building AI. From embeddings to agents.
- Deeply technical *and* deeply commercial. Marketing person who reads
  the codebase. Engineer who writes the landing page.
- On the frontier. Always running experiments. The fastest way to know
  what's true is to ship something and measure it.
- Speed-obsessed. Faster page loads, faster inference, faster builds,
  faster from idea to live. **Zero marginal cost is the asymptote.**
  Jeremy Rifkin saw it coming in 2014. AI agents are how it arrives.
- Irish. Relaxed. Funny. Doesn't take himself seriously. Takes the work
  very seriously.

How that sounds:

- **Relaxed authority.** The expert in the corner who tells you the thing
  in one sentence, makes you laugh, then goes back to building.
- **Plain language, sharp ideas.** The complexity is in the substrate,
  not in the prose.
- **Elegance over cleverness.** If a sentence is too clever to say at the
  pub, cut it.
- **Funny on the way to the point** — never instead of the point.

---

## The thesis — fastest wins, through simplicity

Three claims. One thesis. Anthony's conviction; ONE's product strategy;
the spine of every piece of copy we ship.

> **Whoever is fastest wins.**
> **The way to be fastest is to remove friction.**
> **The way to remove friction is power through simplicity.**

Speed is the *what.* Ease is what the user *feels.* Simplicity is the
*cause.* They're not three goals — they're one belief, told three ways.

---

### 1. Speed wins

Speed compounds. Slow compounds the other way. The fastest team ships
the most experiments, sees the most data, learns the most truth, builds
the most product. Over years, the gap is unrecoverable.

> "He who can handle the quickest rate of change survives." — Col. John
> Boyd, OODA loop

Patrick Collison keeps a [list of fast things](https://patrickcollison.com/fast)
— bridges built in months, software shipped in days, problems solved in
hours. Read it. Then write copy that earns ONE a place on it.

**Fast everywhere.** Speed isn't one number on the homepage. It's a
pattern across every surface. These are the numbers Anthony measures —
these are the numbers the copy cites.

| Surface | What we measure | Target |
|---|---|---|
| Page load | FCP / LCP / INP | sub-1s; **100% Lighthouse on /chat** |
| Inference | First token | streaming starts < 300ms |
| Build | Cold build, hot reload | hot reload < 100ms |
| Deploy | Push → global edge | seconds, not minutes |
| Wallet | First wallet | **5 seconds, p50** |
| Checkout | Crypto accepted | **60 seconds** |
| TTFAPIC | Signup → working API call | **one minute** |
| Time to value | First agent doing real work | **three minutes** |

If a number isn't on this list, measure it before claiming it.

**Every speed claim has a number.** No exceptions. Hard sub-rule of the
data rule below.

- ❌ "Lightning fast."
- ❌ "Significantly faster than competitors."
- ✅ "ONE wallet onboarding: 5 seconds, p50. Across 12,400 sessions,
  April 2026."
- ✅ "Streaming starts in 280ms. Same prompt on OpenAI's playground: 1.4s."

**Borrowed proof — pick one, don't dump five:**

- **Akamai (2017):** every 100ms of added latency cost 7% of conversions.
- **Google (2017):** 53% of mobile users leave sites that take longer
  than 3 seconds to load.
- **Deloitte (2020), *Milliseconds Make Millions*:** every 100ms of
  homepage load improvement = +1.11% session conversion.
- **Cloudflare (2024):** mobile sites loading in 1s convert **5x better**
  than sites loading in 10s.
- **Amazon (Greg Linden, ~2006):** every 100ms of latency costs 1% of
  sales.

**Speed quotes that land:**

- **Bezos:** "Most decisions should be made with somewhere around 70%
  of the information you wish you had. If you wait for 90%, you're
  probably being slow."
- **Patrick Collison:** "Things can move much faster than people think."
- **Andy Grove:** "Only the paranoid survive."

---

### 2. Ease — we remove friction

Friction is what slows fast products. Every extra screen, every required
field, every paragraph of docs is a tax the user pays *before* getting
value. ONE's job is to keep finding that tax and deleting it.

What we delete:

- **Seed phrases.** Touch ID instead. The user never sees 24 words.
- **SDK installs.** A working API call is one `fetch` away.
- **Exchange detours.** Pay in any chain; the merchant gets paid in their
  chain. We bridge.
- **Manuals.** The product is the manual.
- **Password + MFA + recovery codes.** Secure Enclave + biometric. One
  factor that's also the strongest.

**Borrowed proof:**

- **Baymard Institute (2024):** 70.19% average cart abandonment in
  e-commerce — most of it is checkout friction, not pricing.
- **Forrester:** every $1 invested in UX returns $100. **100:1 ROI.**
- **Salesforce, *State of the Connected Customer* (2023):** 88% of
  customers say experience matters as much as the product itself.
- **Stripe (2023):** developers who can get to a working API call in
  under 10 minutes are 4x more likely to integrate.

**Quotes that land:**

> "The cheapest UX improvement is deletion." — Baymard guidance

> "Any sufficiently advanced technology is indistinguishable from magic."
> — Arthur C. Clarke (the work behind the magic is friction removal)

> "I would have written a shorter letter, but I did not have the time."
> — Blaise Pascal

---

### 3. Power through simplicity

Speed and ease aren't gifts. They're the *output* of relentless
simplicity in the engineering. ONE is fast and easy *because* it's
simple — not despite it.

The receipts:

- ~**670 lines** of runtime. Not 100,000.
- **6 dimensions.** Not 60 tables.
- **6 verbs.** Not 60 SDK methods.
- **7 loops.** L1–L7. That's the whole brain.
- **5 wallet states.** Not 25.
- **1 substrate.** Not a stack of vendored services.

**Tesler's Law** (the Law of Conservation of Complexity): complexity
can't be deleted, only moved. ONE moves it *inside* the substrate so it
stays out of the user's way. The substrate carries the weight; the
surface stays calm.

**Quotes that land:**

> "Simple can be harder than complex. You have to work hard to get your
> thinking clean to make it simple. But it's worth it in the end —
> because once you get there, you can move mountains." — Steve Jobs

> "Simplicity is the ultimate sophistication." — Leonardo da Vinci

> "Perfection is achieved not when there is nothing more to add, but
> when there is nothing left to take away." — Antoine de Saint-Exupéry

> "Everything should be made as simple as possible, but not simpler."
> — Einstein (attributed)

---

### The destination — zero marginal cost

Rifkin saw it in 2014. AI agents are how it actually arrives. Every 10x
cut in latency is a 10x cut in someone's frustration — and another step
toward the marginal cost of action falling to zero.

Fast. Easy. Simple. Same arrow. We just point at it from three angles
depending on which one the reader feels first.

---

## The data rule (non-negotiable)

**Every claim is grounded in a number, a citation, or a named example.**
If we can't back it, we don't ship it.

Where the numbers come from:

- Verified third-party sources: Gartner, McKinsey, Forrester, Bain, Stripe,
  Cloudflare, GitHub Octoverse, Stack Overflow Developer Survey, State of
  AI Report (Air Street Capital), a16z research, IDC.
- ONE's own measurements: page-load ms, inference latency, build time,
  deploy time, conversion %, retention %. Always with the date.
- Named customers. Named features. Vague proof isn't proof.

Good:

> "60% of SaaS buyers say 'time to value' is the #1 deciding factor in
> their stack." — Bain SaaS Buyer Survey, 2024

> ONE wallet onboarding: 5 seconds, p50. Measured across 12,400 sessions,
> April 2026.

Bad:

> "We're significantly faster than competitors."

If the stat isn't to hand, leave a placeholder: `[stat: needs citation]`.
Don't ship the line without the number.

---

## Use quotes — but only good ones

A great quote earns its line. Reach for one when:

- A respected operator already said the thing better than we can.
- An idea needs the weight of someone the reader trusts.
- The contrast between the quote and the surrounding prose creates rhythm.

Sources worth leaning on (cite by name — never "industry expert"):

- **Bezos:** "Your margin is my opportunity."
- **Andy Grove:** "Only the paranoid survive."
- **Drucker:** "Culture eats strategy for breakfast."
- **Saint-Exupéry:** "Perfection is achieved not when there is nothing
  more to add, but when there is nothing left to take away."
- **John Carmack** on shipping. **Patrick Collison** on speed.
  **Naval** on leverage. **Paul Graham** on doing things that don't scale.

Rule: one quote per page, set in a blockquote, attributed. Two is
sometimes warranted. Three is showing off.

Don't quote ourselves. Don't quote anonymous experts. Don't quote
manufactured CEO testimonials — they always read like marketing wrote them.

---

## Irish flavor — light touch

Anthony is Irish. It shows up here and there. **Sparingly. Never forced.**

A reader who doesn't catch it should still get the point. A reader who
does catch it should smile.

Where it lands:

- A throwaway aside: *grand*, *sound*, *fair play to them*, *the long and
  short of it is…*
- A line that breaks tension after a serious point.
- An idiom used once in a long piece — not every paragraph.

Where it doesn't:

- Stereotype phrases ("top o' the morning", anything off a cereal box).
- Forced into a headline that doesn't need it.
- More than once per ~500 words.

Rule of thumb: if you removed the Irish phrase and the sentence got
worse, keep it. If the sentence is fine without it, cut it.

---

## Recurring themes

These show up across ONE's surfaces. Use them — don't repeat them all in
the same piece.

- **Fast, easy, simple.** The thesis above. Pick the angle that fits the
  surface; back it with a number.
- **You own your keys.** Always. Secure Enclave + Touch ID. Not "we keep
  them safe for you" — *you* keep them.
- **The substrate learns.** Every signal. Every outcome. Every payment.
  The network gets smarter on its own.
- **Built by someone who's done it before.** 30 years of websites. 8
  years of AI. Not a first-time founder learning on your dime.

---

## Audience

**Primary:** CEOs, founders, C-level execs.
**Secondary:** Engineers, CTOs, technical leaders in the same companies.

They are intelligent. They are busy. They scan first, read second. They
distrust jargon because vendors have used it to hide thin understanding.

The CEO needs to grasp it in one sentence. The engineer needs to trust
we built it. Anthony's voice — plain, specific, grounded in data — earns
both.

---

## The voice rule (load-bearing)

**Very simple English. Depth through brevity.**

We can explain the tech simply *because* we know it deeply. Surface-level
copy uses big words to hide thin understanding. Our copy uses small words
because the hard thinking is already done.

A non-technical CEO reads it and understands. An engineer reads it and
thinks: *they get it.* That's the bar.

### In practice

- **Short words.** "Use" not "utilize." "Help" not "facilitate." "Build"
  not "architect." "Pay" not "transact."
- **Short sentences.** One idea each. Most under 15 words.
- **Concrete nouns, active verbs.**
- **Numbers over adjectives.** "60 seconds to accept crypto" beats
  "lightning-fast onboarding."
- **Name the thing.** TypeDB. Cloudflare Workers. Secure Enclave. Specific
  names build trust; generic ones don't.
- **No throat-clearing.** Cut every "we're excited to," "in today's
  world," "imagine a future where."

### Out loud

Read every paragraph aloud. If it sounds like a press release, rewrite.
If it sounds like one smart person telling another smart person something
true, ship it.

---

## Whitespace and rhythm

Whitespace is part of the voice. Crowded copy reads stressed; spaced copy
reads confident.

- One idea per paragraph. Most paragraphs 1–3 sentences.
- Blank line between every idea. Don't be precious about word count — be
  precious about the reading experience.
- Stats and pull-quotes get their own block.
- Lists are for genuinely list-shaped content. If two bullets could be
  one sentence, write the sentence.
- Headlines have room to breathe. No hero section with eight lines of
  subhead.

The page should feel calm. Calm is hard to do; it signals control.

---

## Banned vocabulary

Never use these. They mark a writer who doesn't know what they're saying:

- **Empty intensifiers:** seamless, robust, cutting-edge, world-class,
  best-in-class, next-generation, revolutionary, game-changing,
  paradigm-shift
- **Jargon that means nothing:** leverage, synergy, holistic, end-to-end,
  unlock value, mission-critical, enterprise-grade, turnkey
- **Vague verbs:** streamline, optimize, empower, transform (unless
  something literally transforms), enable (use the actual verb)
- **Hedges:** almost, very, really, quite, sort of, essentially, basically
- **AI-prose tells:** delve, navigate (as metaphor), tapestry, landscape
  (as metaphor), "in the realm of", "it's important to note",
  "in conclusion"

Exception: if a customer uses one of these in a real quote, keep it.
Their language stays.

---

## Sentence rules

- **One idea per sentence.** If you need "and" twice, split it.
- **Active voice.** "We sign every transaction" not "transactions are
  signed."
- **Confident, not cautious.** "ONE works on every chain." Not "ONE aims
  to work across multiple blockchain ecosystems."
- **No exclamation points.** Ever.

---

## Show depth through specificity

We sound technical when we name the *real* thing — not when we use
technical-sounding words.

- ❌ "Optimized infrastructure for AI agents at scale"
- ✅ "670 lines of runtime. TypeDB brain. Cloudflare edge."

- ❌ "Industry-leading security model"
- ✅ "Your keys live in the Secure Enclave. Touch ID signs every
  transaction."

The second versions are shorter, more concrete, and tell an engineer we
actually built the thing. The CEO doesn't need to understand the Secure
Enclave to understand "Touch ID signs every transaction." Both audiences
move forward.

---

## Headline patterns

- **{Outcome} in {time}.** "Accept crypto in 60 seconds."
- **{Hard thing} without {pain}.** "Own your keys without managing them."
- **{Number} {nouns}. {Result}.** "Six dimensions. Seven loops. One brain."
- **The {category} for {audience}.** "The substrate for AI agents."
- **{Plain truth}.** "You own your keys. Always."
- **{Real quote}.** Use a real attributed quote as the headline when it's
  strong enough to carry the page.

Avoid: rhetorical flourishes, "imagine if…", "the future of…", anything
that sounds like a TED-talk opener.

---

## CTA rules

- Action verb + what they get. "Get my wallet." "See how it works."
  "Read the spec." Never "Learn more," "Sign up," "Get started."
- One primary CTA per page.
- The CTA verb has to match what actually happens next. "Read the spec"
  must link to the spec.

---

## Product context — the one-paragraph anchor

ONE is a signal-based substrate for AI agents. Agents send signals. The
substrate remembers what worked and what didn't, on every path. The
network gets smarter on its own. The runtime is ~670 lines. The brain is
TypeDB. The edge is Cloudflare Workers. Four surfaces — product
(one.ie), payments (pay.one.ie), API (api.one.ie), open-source SDK + MCP
+ CLI (github.com/one-ie/one).

What we promise — and we have the numbers:

- **You own your keys.** Always. Secure Enclave + Touch ID.
- **Agents learn.** Every signal, every outcome, every payment.
- **Speed in seconds.** 5s wallet. 60s crypto checkout. 3s buy. 30s list.
  [verify against current prod numbers]

---

## When in doubt

Pick the shorter word. Pick the shorter sentence. Cut the adjective.
Name the real thing. Cite the number.

Then read it aloud.

If a smart non-technical CEO can read it and act, *and* a senior engineer
can read it and trust us, *and* Anthony would actually say it at the pub
on a Friday — ship it.
