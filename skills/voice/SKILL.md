---
name: voice
description: "Write in Anthony O'Connell's voice. Use whenever prose will go out under Anthony's or ONE's name and must sound like him, not like a generic assistant — books, essays, whitepapers, manifestos, blog posts, landing-page and marketing copy, founder updates, social posts, newsletters, client emails, playbook chapters, README and doc prose, or any rewrite where the note is \"this doesn't sound like me\". Its first job is picking the register: book/essay (patient, observational, no visible author, never sells) or commercial (first person, receipts, product names, sells). Invoke AFTER `writer` (craft) and alongside `product-marketing.md` (product context). Triggers — \"write this in my voice\", \"in Anthony's voice/tone\", \"make it sound like me\", \"this reads like AI\", \"too corporate\", \"sounds generic\", \"write the book/chapter/essay/whitepaper\", \"write the blog post/landing page\", \"rewrite this properly\"."
---

# voice — Anthony O'Connell's register

He writes in two registers. **Picking the right one is this skill's main job**, and getting it wrong is the most expensive mistake available — the two contradict each other on narrator, on selling, and on whether jokes exist.

---

## Step 1 — pick the register

| Writing this | Register | Read |
|---|---|---|
| book · book chapter · essay · whitepaper · manifesto · long-form thought | **Book** | `text/voice-and-tone.md` — **complete, stop there** |
| landing page · blog post · promise (`text/<slug>.md`) · client email · social · newsletter · playbook chapter · doc prose | **Commercial** | `text/writing-style-guide.md` Parts 1, 3–8 + `.claude/product-marketing.md` |
| unsure | **Ask one question:** does it sell anything, and does it have a narrator? Both no → book. Either yes → commercial. |

The registers differ on five load-bearing points. Do not blend them:

| | Book | Commercial |
|---|---|---|
| "I" / "we" | **never** — no visible author | yes |
| Sells | **never** | yes, that's the job |
| Product / company names | **never** | yes |
| Code, file paths | **never** | yes, and always real |
| Headings inside a piece | **never** | yes |

Everything else — observe don't assert, specific numbers or none, short sentences, one-sentence paragraphs, never lecture, never apologise, never overreach, recognition not awe — holds in both. Those universals are Part 1 of the style guide.

---

## Step 2 — the sources, in order of authority

1. **`text/voice-and-tone.md`** — the specification. **Authored by Anthony.** Vendored from `apps/ants/docs/book/files/01-voice-and-tone.md`; edit the original, re-vendor here. Demonstrated across `apps/ants/docs/book/manuscript/` — 96,540 words of directory, 93,032 of them the 25 chapters the section below measures. **Senior to everything else. Where anything disagrees with it, it wins.**
2. **`text/writing-style-guide.md`** — derived. Splits universal from book-only, and documents the commercial register the spec doesn't cover.
3. **`.claude/product-marketing.md`** — product context: offer, audience, thesis, the measured-numbers table. Commercial only.

Read the whole of the relevant source when the piece is long-form, when it's the first piece in a new format, or when the user's note is about voice. For a short piece in a format you've already done this session, the checklists below are enough.

---

## The sentence test (both registers)

> *Would a careful, slightly amused, very patient person, who is in no hurry to convince anyone of anything but who has noticed something important, write this sentence?*

If it performs urgency, expertise, contrarianism, or aspiration — rewrite it.

**He does not joke.** *"It is amused, but never sarcastic … The voice does not joke."* There is dry pleasure at a pattern recurring where nobody expected it. There is no comedy, no snark, no bit. If a draft is being funny, it is not being him.

---

## What the corpus actually does — measured

`text/voice-and-tone.md` says what the voice must never do. The 25 chapters of
*100 Million Years Ahead* show what it does. Measured 2026-09-09 over
`apps/ants/docs/book/manuscript/*.md` — 93,032 words, 6,163 sentences, 1,441
paragraphs. Re-measure any time with `bash .claude/skills/voice/corpus-check.sh --corpus`.

| Signature | Measured | What it means for a draft |
|---|---|---|
| **"I"** | **0** in 93,032 words | Absolute, not a preference. One occurrence is a defect. |
| **Contractions** (`n't`) | **5** in the whole book | Effectively never. Write *does not*, *is not*, *will not*. The spec never states this; the corpus is unanimous. |
| **`###` headings inside a chapter** | **0**, across all 25 | Confirmed absolute. |
| **Horizontal rules** (`---`) | **median 5 per chapter**, up to 10 | The derived guide's "once or twice" is **wrong**. The scene break is a primary structural tool, not a rarity. |
| **One-sentence paragraphs** | **371 of 1,441 — 25.7%** | One paragraph in four is a single sentence. That is the rhythm, not an occasional flourish. |
| **Sentence length** | median **12** words · mean 15.1 · p10 **4** · p90 30 · max 82 | Wide range on purpose; 22.2% of sentences are 6 words or fewer. A draft of uniform 20-word sentences is not this voice. |
| **Final sentence of a chapter** | median **10** words; three chapters end in 3 | Land short. *"The soil will."* · *"In the substrate."* · *"The architecture, running."* |
| **"the reader"** vs **"you"** | 134 vs 113 — and **50 of the 113 sit in the epilogue alone** | The standing device is third-person *"the reader."* Direct *you* is held back and spent at the end, where the book turns to face the reader. |
| **Digits** | 5.8 per 10k words | Numbers are rare and therefore load-bearing. A number earns its place or is cut. |
| **Hedges** | *on the order of* ×12 · *roughly* ×23 · *approximately* ×3 | Precise when the evidence is sharp, *on the order of* when it is not. Never a fake decimal. |
| **Em dashes** | 89.6 per 10k | Book register uses them freely. The "3 or fewer" rule is **commercial only** — do not carry it across. |
| **Question marks** | 5.3 per 10k — 49 in the whole book | A rhetorical question is a rationed move. Two chapters end on one. |

---

## The three sentence shapes

These are the shapes the corpus reaches for. They are not decoration. They are how an
observation gets made without being asserted.

**1. The negative-definition fragment.** A statement, then a fragment that names the
obvious alternative and refuses it. The most characteristic sentence in the book.

> *"This is the thing to look at. Not the ant."*
> *"This is where the colony's memory lives. Not in any ant."*
> *"The colony regulates the queen. Not the other way around."*
> *"That eighth one ran in fifteen years what the desert ran in a hundred million. Not because it was better designed."*

The fragment is deliberate. It does the work an em dash and a subordinate clause would
do, and it lands harder because it stops.

**2. "It is not X. It is Y."** Two flat copulas. The first clears the ground, the second
puts the thing down. No connective, no *rather*, no *instead*.

> *"It is not chemistry. It is not soil."*
> *"It is not a stored recipe retrieved on cue. It is constructed for the case in front of it."*
> *"It was not built as a substrate for collective intelligence. It was built to record grain shipments and tax debts."*

**3. The copula-forward declarative.** *It is* appears 683 times — 73.5 per 10k. The
voice states what a thing is and then stops, rather than explaining that it is about to
state it. This is what "confidence without assertion" looks like structurally.

**And one shape to avoid:** the interpretive paragraph after a clear observation. The
corpus makes the observation and leaves a blank line. The reader is given room to feel
the implication before the next paragraph arrives.

---

## Openings and closings

**Every one of the 25 chapters opens on a concrete particular.** Never on an argument,
never on a thesis, never on a summary of what the chapter will do.

They open on: a temperature on dirt · a nine-month-old on a kitchen floor · dawn in the
Chihuahuan Desert · a corridor a centimetre wide · a freshly emerged ant · a stretch of
high desert near Rodeo · *"She is the largest animal in the nest, and she is doing the
least."* · a man opening a coffee shop · a person selling four hundred shares · Vienna,
1847 · a scrape on a knee · one and a half kilograms of tissue · the year 1300 · 2008 ·
*"The desert is still there."*

Three reliable opening moves: **a place and a temperature**; **a date, a person, an
action**; **a flat short sentence holding a contradiction** ("largest… doing the least").
Pick one and begin. Do not announce.

**The closings are short, and they return.** Median 10 words. The dominant move is a
recontextualised return to the chapter's own opening image — chapter 22 opens *"The
desert is still there"* and closes *"The architecture, running."* Two chapters close on a
question. Several close on a fragment that lands on one noun and nothing else.

Never close on a summary. Never close on an implication the reader can draw alone.

---
## Book-register checklist

- [ ] **Opens on a scene** — a place, a person, a moment, a number. Never on an argument.
- [ ] **No "I", no editorial "we", no visible author.** The camera is there; the camera is not the subject.
- [ ] **Observes; does not assert.** "The intelligence was not in any of the ants," not "intelligence is a property of substrates."
- [ ] **Sells nothing.** Names no company, product, or technology. Quotes no code.
- [ ] **No contractions.** *does not*, not *doesn't*. Five in 92,894 words of corpus.
- [ ] **No `###` subheadings** — zero across 25 chapters. But **use the horizontal rule**: median 5 scene breaks per chapter, up to 10.
- [ ] **"The reader", not "you"** — 134 to 116, and 50 of the *you*s are in the epilogue. Direct address is saved for the end.
- [ ] **One paragraph in four is a single sentence** (25.7% measured). Vary sentence length hard: median 12 words, but 22.2% are ≤6.
- [ ] **Specific numbers, or honest hedging** (*on the order of*, *roughly*). Never false specificity. Digits appear only 5.8 times per 10k words — each one is load-bearing.
- [ ] **Never defines a technical term** — makes its meaning land through use.
- [ ] **Opens on a concrete particular** — a place and a temperature, a date and a person and an action, or a short flat sentence holding a contradiction. Never on the thesis.
- [ ] **Closes short** — median 10 words — often a recontextualised return to the opening image. Never a summary.
- [ ] **Reaches for the three shapes** — the negative-definition fragment, "It is not X. It is Y.", the copula-forward declarative.
- [ ] **Leaves the observation alone.** No interpretive paragraph after a clear one.
- [ ] **Passes both the "your mum" and the "Demis Hassabis" test.**
- [ ] **The emotion is recognition, not awe.** No "this changes everything."
- [ ] **Run `bash .claude/skills/voice/corpus-check.sh <draft.md>`** — it counts the mechanical half against the corpus and cannot judge the rest.

## Commercial-register checklist

- [ ] **Em dashes: 3 or fewer.** Count them. (Book register is the opposite — 89.6 per 10k. Do not carry this rule across.)
- [ ] **Every quality adjective replaced by a number** — or the claim cut, or the gap stated.
- [ ] **No fabricated proof.** Every metric, quote, logo, benchmark, file path real or marked unproven.
- [ ] **Speed claims carry a measured number** from `product-marketing.md`'s table.
- [ ] **Opens with a scene or an orthodoxy, not the thesis.**
- [ ] **Closes on a verdict with its shadow** — name what's still broken. No "In conclusion."
- [ ] **No hedging, no throat-clearing.** (Honest uncertainty stated precisely is not hedging.)
- [ ] **Snark aimed at systems, never people.**
- [ ] **Substrate jargon stripped** from customer-facing copy — no `signal`, `mark`, `warn`, `path`, `substrate`. Customer's words instead.
- [ ] **Pub test** — read the cleverest sentence aloud. If you'd wince, cut it.
- [ ] **Status claims are true** — built means built, armed-red means armed-red.

---

## The five commercial moves

| Move | Example |
|---|---|
| **"X, not Y"** | "The threat model is a table, not a promise." |
| **The physics reframe** | "This is not a buyer problem. It is a physics problem." |
| **The uncomfortable truth** | "Here's the part nobody in marketing wants to say out loud …" |
| **Receipts, not adjectives** | "11 interactions, 55 to 65 seconds, plus DNS wait." |
| **The unpaid-debt close** | end on what's still broken, unresolved |

The uncomfortable-truth move is not contrarianism and not a hot take — the spec forbids performing either. It works because it is a conclusion reached reluctantly and reported flatly.

---

## The stack

```
1. writer                    craft    — draft, cut, structure, polish
2. voice  (this skill)       register — pick one, then apply it
3. product-marketing.md      context  — offer, audience, measured numbers (commercial only)
4. docs                      taxonomy — only for text/*.md doc types
```

`writer` decides whether the sentence works. `voice` decides whether it's his. When they disagree, `voice` wins.

---

## Don't

- **Don't blend the registers.** A book chapter that names a product, or a landing page with no narrator, is the failure this skill exists to prevent.
- **Don't make him funny.** His own spec rules it out. Warmth is not comedy.
- **Don't invoke this instead of `writer`** — invoke it after. Craft first, register second.
- **Don't apply it to internal specs, TypeQL, migrations, or commit messages.** Those have their own registers and this one makes them worse.
- **Don't edit `text/voice-and-tone.md`.** It's a vendored copy. Edit `apps/ants/docs/book/files/01-voice-and-tone.md` and re-vendor.
- **Don't invent biography.** If a beat wants lived experience that isn't on record, use a corpus example or mark it constructed.
