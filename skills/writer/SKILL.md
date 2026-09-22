---
name: writer
description: Write, edit, and improve any prose — blog posts, essays, articles, landing page copy, founder updates, LinkedIn posts, technical explanations, marketing emails, documentation, or any other written deliverable. Use this skill whenever the user asks to "write", "draft", "rewrite", "edit", "polish", "tighten", "make this clearer", "improve this copy", "fix my writing", or asks for help with anything that ends up as words on a page. Use it for short pieces (a single tweet, a paragraph) and long ones (a 2,000-word essay) alike. Use it even when the user has already drafted something and just wants feedback — the skill covers editing as much as it covers drafting.
---

# Writer

A skill for producing prose that lands. The goal is writing that is clear, alive, and structurally sound — not "correct" in the schoolteacher sense, not bloated with adjectives, not LinkedIn-ese.

This skill exists because most writing fails for the same handful of reasons: the writer didn't know who they were writing for, didn't lead with the strongest point, told instead of showed, padded with adjectives instead of facts, ignored how readers actually process sentences, and stopped at the first draft. Fix those six things and the prose becomes good. Fix them consistently and the prose becomes great.

---

## The core loop

Every piece of writing — long or short — goes through this loop:

1. **Understand the audience, medium, and goal** before writing a word.
2. **Draft fast, without judgement.** Get the ideas down. Don't edit while drafting.
3. **Cut.** Aim to halve the word count. Then halve again where possible.
4. **Restructure.** Move the strongest point to the top. Reorder for flow.
5. **Polish at the sentence level.** Apply the five questions (below).
6. **Read it aloud.** A good sentence sounds good. If it stumbles, rewrite it.
7. **Stop when it's done.** Don't pad.

If time is short, skip steps 5 and 6 and ship. Steps 1–4 are non-negotiable.

**Writing under Anthony's or ONE's name?** Invoke the `voice` skill. It picks
between his two registers — the book register
([`text/voice-and-tone.md`](../../../text/voice-and-tone.md), his own writing
specification) and the commercial register
([`text/writing-style-guide.md`](../../../text/writing-style-guide.md)).

**Order depends on the register.** For commercial work, run this loop first, then
`voice`. For **book** work, invoke `voice` first and use this skill only for
sentence-level polish — step 3 above ("aim to halve the word count") and step 4
("move the strongest point to the top") are wrong for that register, which is
paced to walk at the reader's pace and never leads with its thesis. Applying
them to a chapter turns it into a landing page.

This skill decides whether the sentence works; `voice` decides whether it's *his*.
When they disagree, `voice` wins.

---

## Step 0: Audience, medium, goal

Before writing anything, answer four questions. If the user hasn't given you enough to answer them, ask. Don't guess.

- **Audience.** Who is reading this? What do they already know? What do they care about? What language do they actually use? (A landing page for a Thai parent, a Slack message to a CTO, and a thread on Hacker News all need different sentences.)
- **Medium.** Email, blog post, tweet, white paper, landing page, founder update, push notification? The medium dictates length, tone, and which rules are worth breaking.
- **Mode.** Persuasive, explanatory, narrative, reference? A "how-to" reads differently from a "here's what I think."
- **Goal.** What do you want the reader to do, feel, or believe after reading? If you can't state this in one sentence, you aren't ready to write.

If the user's request is ambiguous (e.g. "write me something about X"), pick the most likely answers, state them inline as assumptions, and proceed. Don't stall on questions when good defaults exist.

---

## Step 1: Drafting

When drafting, **do not edit**. Editing while drafting kills momentum and produces neither a good draft nor a good edit.

- Start with the point you most want to make. Not the setup, not the throat-clearing, not "In today's fast-paced world…" — the point.
- Write in your natural voice. If you're drafting for someone else, write in theirs. Read three things they've written first, then echo their rhythm.
- Use placeholders for facts you'll need to check: `[stat: Q3 churn rate]`. Don't break flow to look things up.
- It's fine for the first draft to be twice as long as the final. Cutting is easier than expanding.

---

## Step 2: Cutting (the highest-leverage step)

Most writing is 30–70% too long. Cut anything that doesn't earn its place.

**Cut these on sight:**

- Adverbs that boost weak verbs ("walked quickly" → "hurried"; "very large" → "huge" or just a number).
- Adjective stacks ("blazingly fast and incredibly efficient" → pick one, or replace with a fact).
- Hedges that protect the writer rather than serve the reader ("I think maybe it could possibly be the case that…" → state the thing).
- "In order to" → "to". "At this point in time" → "now". "Due to the fact that" → "because".
- Throat-clearing openers: "I just wanted to say…", "It's worth noting that…", "In today's world…".
- Empty intensifiers: "really", "very", "literally", "actually", "basically", "simply", "essentially".
- Restating the question back at the reader ("That's a great question. The answer to whether X is Y is…").
- Closing throat-clearing: "I hope this helps!", "At the end of the day…", "Hopefully that gives you a sense of…".

**Cut whole sentences if:**

- They restate something already said.
- They explain a metaphor you just used (trust the reader).
- They could be deleted without anyone noticing.

**Diagnostic.** Read each paragraph and ask: if I deleted this paragraph, would the piece be worse? If no, delete it.

---

## Step 3: Show, don't tell

This is the single biggest weakness in most writing — including most professional writing.

**Telling** asserts. **Showing** demonstrates with specifics the reader can feel.

**Bad (telling):**
> Our app is blazingly fast and incredibly powerful.

**Good (showing):**
> The app cold-starts in 200ms. The competitor takes 4 seconds.

**Bad (telling):**
> She was nervous about the meeting.

**Good (showing):**
> She read the agenda four times on the elevator up.

When you find an adjective doing heavy lifting ("amazing", "powerful", "innovative", "seamless", "robust"), replace it with the fact, number, or scene that earned the adjective. If you can't find that fact, the claim isn't real and shouldn't be in the piece.

A drill that works: write the whole piece without adjectives. If it's still interesting, the content is good and you can add adjectives sparingly. If it's boring without them, the problem is the content, not the prose.

---

## Step 4: Structure (the part most advice skips)

Structure is where good writing becomes great. Two frames cover most cases.

### Frame 1: Reader expectations (Gopen & Swan)

Readers have unconscious expectations about *where* information appears in a sentence. Match those expectations and prose becomes effortless to read without being dumbed down. Violate them and the reader works harder, gets less, and blames themselves.

The rules:

1. **Subject + verb close together.** Don't separate them with long parenthetical clauses. The reader holds their breath until the verb arrives.
2. **Old information at the start of a sentence (topic position).** New information at the end (stress position). This is how you build flow: each sentence picks up where the last one left off, then introduces something new, which the next sentence picks up.
3. **Whose story is this?** Put that person/thing in the topic position. If the sentence is about the customer, start with the customer. If it's about the product, start with the product.
4. **Action lives in the verb.** "We made a decision to invest" → "We decided to invest." Nominalised verbs ("made a decision", "performed an analysis", "had a discussion") drain energy.
5. **Context before novelty.** Tell the reader what frame to read the next thing in, then deliver the next thing.
6. **Structural emphasis must match substantive emphasis.** If the most important point is at the end of the sentence in the stress position, good. If it's buried in a subordinate clause, fix it.

### Frame 2: Lead with the strongest point

Newer writers usually reach their strongest point around paragraph three. Emotional writers reach it at the end. Find yours and move it to the top.

A practical edit: after drafting, scan for the sentence that made you most want to keep writing. That sentence is probably your real lede. Move it up. Delete everything before it that doesn't earn its place.

For business writing, this often means the Pyramid Principle (Barbara Minto): state the conclusion first, then the supporting reasons, then the evidence. Readers can stop reading at any point and still take away the main thing.

---

## Step 5: The five sentence questions

Once the structure is right, polish each sentence by asking, in order:

1. **Does it say what I mean?** (Meaning is non-negotiable. Get this first.)
2. **Can it be clearer?** (Includes brevity. Shorter is usually clearer.)
3. **Does it match the tone of the piece?** (A formal sentence in a casual piece breaks the spell.)
4. **Can it be more novel?** (Replace clichés. "At the end of the day", "move the needle", "low-hanging fruit", "game-changer" — all dead.)
5. **Can it be more beautiful?** (Rhythm, sound, the play of the tongue. Read it aloud.)

Start at the top. The moment an answer suggests a change, make it and start over from question 1. Under deadline you get to question 1 or 2. With time, you get to 5.

---

## Step 6: Read it aloud

Move your lips. A sentence that stumbles when spoken stumbles when read silently — the reader just doesn't know why it feels off. Common problems this catches:

- Sentences that are too long (you run out of breath).
- Repeated word sounds at sentence boundaries ("…the system. The system…").
- Awkward consonant clusters.
- Rhythms that fight the meaning (a punchy idea in a meandering sentence).

---

## Tone defaults

Unless the user specifies otherwise, default to:

- **Short sentences.** Mix in longer ones for rhythm, but lean short.
- **Concrete over abstract.** "Three customers cancelled this week" beats "we're seeing some churn signals."
- **Active voice by default.** Passive is fine when the actor is unknown or genuinely irrelevant ("The server was rebooted overnight").
- **Conversational over formal.** "Don't" not "do not", unless the piece is genuinely formal.
- **Plain words over fancy ones.** "Use" not "utilise". "Help" not "facilitate". "About" not "regarding".
- **Specific over general.** Names, numbers, places, dates.

Avoid by default:

- LinkedIn-ese. "I'm thrilled to announce", "humbled and honoured", "circle back", "synergies", "leverage" (as a verb), "thought leader", "ecosystem" used loosely.
- Hype adjectives without facts: "incredible", "amazing", "revolutionary", "game-changing", "world-class", "best-in-class", "next-generation".
- Em-dash overuse as a substitute for clear sentence structure. (One em-dash per paragraph max, usually fewer.)
- Bullet points where prose would be clearer. Bullets are for genuinely list-shaped content (steps, options, criteria). Don't bullet ideas that connect to each other — write the connection.
- Headers in short pieces. A 400-word post does not need three H2s.
- Emoji unless the user uses them or the medium expects them.

---

## Common formats

When the user asks for a specific format, these are the defaults. Adjust based on Step 0 (audience, medium, goal).

### Blog post / essay

- Open with the strongest point or a concrete scene. Not a definition. Not "In this post, I'll…".
- One idea per paragraph.
- Section headers only if the piece is long enough that a reader might want to skim or return to a section.
- Close on a thought worth carrying away. Not "in conclusion". Not a summary of what you just said.

### Landing page / marketing copy

- Headline names the audience's problem or desired outcome in their words.
- Subhead delivers the proof or specificity ("how").
- Body shows, doesn't tell — facts, numbers, screenshots, named customers.
- One clear call to action.
- Cut every word that doesn't sell.

**Pick one headline framework per page; don't mix.** The canon — ten templates,
when each one fits, plus the specificity rule, the sensory rule, and the seven
biases (anchoring, loss aversion, social proof, authority, reciprocity,
scarcity, decoy) doing the persuasive work underneath — is in
`references/copy-frameworks.md`. Read it before writing or rewriting any
landing-page hero, pricing page, or feature section.

Quick map of the ten:

| # | Framework | When |
|---|---|---|
| 1 | JTBD — "{Product} helps {audience} {job} without {friction}" | Mature category, narrow buyer |
| 2 | PAS — Problem · Agitate · Solve | Pain is felt but unsolved |
| 3 | BAB — Before · After · Bridge | Category shift, transformation story |
| 4 | Outcome + timeframe — "{Outcome} in {time}" | You can prove the speed |
| 5 | Hard thing without pain — "{Outcome} without {usual cost}" | Differentiation = removal |
| 6 | Plain truth — one declarative sentence | When the truth is good enough |
| 7 | Numbered nouns — "{N} {things}. {result}." | Architecture / system products |
| 8 | Category for audience — "The {category} for {audience}" | Carving a sub-category |
| 9 | Dunford — "Unlike {alt}, {capability} so {value}" | Competitive market |
| 10 | Real attributed quote | When the quote is *that* good |

Two non-negotiable rules every headline passes:

- **Specificity (Harry Dry):** if a competitor could put their logo on your
  headline and have it still be true, rewrite. "Worn by supermodels in London
  and dads in Ohio" only works for New Balance.
- **Sensory:** concrete nouns are recalled +200% vs. abstract concepts. "Touch
  ID signs every transaction" beats "industry-leading security model."

### Founder update / investor email

- Lead with the headline (what changed, what's working, what's broken).
- Numbers up top. Story underneath.
- Honest about problems. Investors trust founders who name the hard things.
- End with specific asks if you have any.

### LinkedIn / social post

- First line earns the click to "see more". Make it a hook, not a setup.
- Short paragraphs, often one sentence each (the format demands it).
- One idea per post. Don't try to say three things.
- No hashtag spam.

### Email

- Subject line: specific, not clever. ("Friday review — 3 decisions needed" beats "Quick check-in".)
- First sentence states the purpose.
- Asks are explicit and easy to act on.
- Short. Almost always shorter than your first instinct.

### Technical explanation / documentation

- Lead with what the thing is and what it's for. Not the history.
- Concrete examples before abstractions.
- Code blocks and diagrams where they're clearer than prose.
- Define jargon the first time it appears, or link to a definition.

---

## Editing someone else's draft

When the user gives you a draft to improve:

1. **Read it through once before changing anything.** Understand what they're trying to do.
2. **Preserve their voice.** If they write punchy, stay punchy. If they write warm, stay warm. Your job is to make their writing better, not to make it sound like yours.
3. **Identify the strongest sentence in the draft.** If it isn't near the top, that's usually the first fix.
4. **Cut before you add.** Most drafts get better by 30% just from cutting.
5. **Show the change, not just the result.** If the user pasted a paragraph, return the rewritten paragraph and a one-line note on what changed and why. They learn faster, and they can push back on changes they disagree with.
6. **Don't over-correct.** If a sentence is fine, leave it. Constant tinkering loses the writer's trust.

When the user asks for "feedback" rather than a rewrite, give feedback. Don't rewrite the whole thing unless they asked. Diagnose: what's working, what isn't, what one change would have the biggest effect.

---

## What to avoid

- **Never use em dashes habitually.** They're a tic that signals AI-written prose. Use commas, full stops, or parentheses instead. One em-dash in a piece is fine; six is a tell.
- **Never use "delve", "navigate" (as a metaphor), "tapestry", "landscape" (as a metaphor), "in the realm of", "it's important to note", "in conclusion", "in summary".** These are AI-prose tells. They're also just bad writing.
- **Never write "As an AI…" or refer to the writing process from inside the piece** unless explicitly asked to.
- **Never pad to hit a word count.** If the piece is done at 300 words and the user asked for 500, return 300 and say so. Padding is worse than under-delivering.
- **Never use "elevate", "unlock", "empower", "transform", "supercharge", "revolutionise"** in marketing copy unless quoting someone.
- **Never start a piece with a dictionary definition.** It's the laziest opening in writing.

---

## When to ask vs when to proceed

**Proceed without asking when:**

- The user pasted a draft and asked you to "improve" or "tighten" it. Just do it.
- The user asked for a specific deliverable in a specific format ("write a 200-word LinkedIn post about X"). Ship the post.
- The audience and goal are obvious from context.

**Ask first when:**

- The user said "write me something about X" with no medium or audience specified, and the choice meaningfully changes the output.
- You'd need to invent significant facts to write the piece (numbers, names, customer quotes).
- The user's voice matters and you have no examples of it.

When in doubt, write the piece with stated assumptions ("Assuming this is for a developer audience and goes on your blog…") rather than stalling on questions.

---

## A note on length

Match length to the job. A great tweet is 30 words. A great founder update is 400. A great essay might be 3,000. None of these are inherently better than the others.

But: when in doubt, shorter. Almost no one ever wishes a piece of writing were longer.

---

## Project-specific voice

Voice documents layer on top of this skill. **Which ones you read is the `voice`
skill's decision, not this one's** — it picks the register first, and the book
register reads `text/voice-and-tone.md` and stops there. Don't preload all of
them.

**Commercial register — blog posts, landing pages, client email, social, docs prose:**
[`text/writing-style-guide.md`](../../../text/writing-style-guide.md) — the
derived guide. The sensibility (does this tool serve the work, or has it started
serving itself?), the typography fingerprint (trailing ` …`, the em-dash ration,
scare-quotes, capitalized Concepts), the sentence rhythm (punch / carrier /
escalating list), and the recurring beats (received-wisdom turn, forensic
descent, two-camps dismissal).

**Marketing, product, and landing-page copy:**
[`/.claude/product-marketing.md`](../../product-marketing.md) — ONE's brand voice.
Audience (CEOs + engineers), the speed/ease/simplicity thesis, banned vocabulary,
headline patterns, and the data rule. Layers on top of the style guide for
anything that ships as ONE copy.

---

## Reference files

- `text/writing-style-guide.md` — the commercial register: sensibility, typography fingerprint, sentence rhythm, recurring beats, vocabulary bank, anti-patterns, worked examples. Read it when `voice` picks commercial; for the book register `voice` sends you to `text/voice-and-tone.md` instead.
- `references/anti-patterns.md` — A longer catalogue of clichés, AI-prose tells, and corporate jargon to avoid, with replacements. Read this when editing marketing or corporate copy where the user wants to sound less like a press release.
- `references/structures.md` — Concrete templates for common pieces (essay openings, founder updates, landing page sections, cold emails). Read this when the user asks for a format you want to handle well.
- `references/copy-frameworks.md` — The canon: ten headline frameworks (JTBD, PAS, BAB, outcome+timeframe, hard-thing-without-pain, plain truth, numbered nouns, category-for-audience, Dunford positioning, attributed quote) with when-to-use, examples, traps; the specificity and sensory rules; the seven biases (anchoring, loss aversion, social proof, authority, reciprocity, scarcity, decoy) and which frameworks recruit which. Read this when writing or rewriting landing pages, pricing pages, hero sections, or any headline that has to convert.

These are loaded only when relevant. Don't read them for every task.

---

## The thing nobody can teach

Live a life worth writing about. Voice comes from somewhere. The best writing in the world is animated by the writer's actual thinking, actual taste, actual stake in the subject. This skill can sharpen prose. It can't manufacture conviction. When the user has something real to say, get out of their way and help them say it cleanly.
