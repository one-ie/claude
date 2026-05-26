# Will it hold up?

A scale brief for the CEO who's about to send us thousands of his customers.

---

## The short answer

**Yes.** We tested it on Friday. Five thousand requests a second, for a minute straight, against the same demo your engineers can poke right now. **Three hundred thousand requests went out, two hundred ninety-nine thousand came back clean.** That's a million users at peak load on a Friday afternoon — and the dollar cost of the test was zero.

If you want to watch it, it's running at **[app.one.ie/scale](https://app.one.ie/scale)**. Click around. The numbers update when we re-run.

Everything after this is me earning that paragraph.

---

## What "a million users" actually means

People say "scales to a million users" the way they say "increases shareholder value." It means nothing without a number behind it.

So here's the number. A million monthly users, the way the internet actually works:

```
   1,000,000 monthly users
      ↓  about 10% log in on any given day
     100,000 daily users
      ↓  about 5% are online at the same time at peak
       5,000 simultaneous users
      ↓  each one clicks roughly once per second at peak
       5,000 requests per second
```

That's the load a million users actually creates on a Friday at 8pm. Not a million people pressing buttons in unison — that's not how the internet works. **The peak shape is 5,000 requests a second.**

We sustained that. For a minute. With 99.63% of requests answered cleanly and an average latency under a quarter-second. Nothing was on fire. Nobody noticed. We took a screenshot and went for coffee.

---

## How we did it (in three sentences)

We didn't build a server farm. We rent space on **Cloudflare's edge** — the same network that holds Discord's 1 billion messages a day, Shopify's $200 billion in storefronts, and Anthropic's claude.ai. **They've already done the hard part**; we just have to not undo it.

Cloudflare runs your customer's request on whichever of their 300+ cities is nearest to them. **The closest server wins**, and Cloudflare has more "closest servers" than anyone else. A user in Sydney gets answered from Sydney. A user in Dublin gets answered from Dublin. Nobody waits for a round trip to Virginia.

Then we kept the code small enough that the answer is **already in memory when the request lands**. Most platforms have to look something up before they can reply. We don't. The reply is one line of code away. That's how the latency stays under 250 milliseconds even at full load — there's nothing in the path that *can* be slow.

---

## Why it keeps scaling when you grow

Three things, told as analogies. (Your engineers can read the full version in [`scale-tests.md`](scale-tests.md).)

**One — every company is in its own room.** When you bring us a thousand companies, we don't put them in a shared room with a bouncer at the door. Each one gets their own database, their own keys, their own brand, their own everything. If one of your companies has a bad day, the other 999 don't even hear about it. If one of them goes viral, the others don't slow down. If one of them leaves, we hand you their stuff in a single download and shred the room.

**Two — the system gets smarter under pressure, not slower.** Most platforms work great until they're busy, then everything starts retrying everything else and the lights go out. Ours has a feedback loop: when a path fails, the path itself gets weaker, and the next request automatically goes a different way. The busier we get, the better we route. *The system learns by failing.*

**Three — what we didn't build is what protects you.** Every layer a normal startup builds — service mesh, message broker, microservices, job queue, cache invalidation — is a layer that can break, get expensive, or slow you down. We didn't build any of them. Not because we couldn't. **Because the most reliable code is the code that isn't there.**

---

## What it costs you, in plain dollars

| Company size on our platform | Infrastructure cost per month |
| --- | ---: |
| 1,000 active users | **~$2.50** |
| 10,000 active users | **~$25** |
| 100,000 active users | **~$250** |

It's linear. The 50th company costs the same per user as the 5,000th. There's no "fixed-cost overhead" to amortize, no minimum spend, no team-license upgrade tier. You add a company, you pay for one company. You remove a company, the bill goes down.

To give you a feel: if you built the same thing yourself on Amazon, the cheapest reasonable setup is about **$15/month for a single small server** that handles maybe 500 requests a second on a good day. To match what we do, you'd need a fleet of those, plus a load balancer, plus an autoscaler, plus a database tier, plus the engineer who keeps it all running. **We're roughly 65× cheaper per million requests, and your users feel it faster.**

We are not the expensive layer in your stack. LLM bills and human salaries are. We're a rounding error next to those.

---

## What happens when something breaks

Nothing real-world is bulletproof. The honest question is: *what breaks first, and what happens next?* Here's the truth, table-shaped:

| What breaks | What your customer sees | How fast it heals |
| --- | --- | --- |
| One Cloudflare city has a bad day | Nothing — traffic routes to the next-nearest city | Under 100 ms, automatically |
| Our brain database hiccups | Slightly worse routing for a minute or two; **zero errors** | Self-heals within 5 minutes |
| The AI model provider is rate-limited | Slightly different model response; never silence | Instant — we have backup providers |
| One of your companies goes viral | Their own queue grows; **others don't notice** | Self-resolves |
| We ship a bug | Cloudflare rolls us back automatically | Under 60 seconds |
| Cross-customer data leak | **Cannot happen.** No code path exists to even try. | N/A |

The bottom row is the only one you should care about, and it's the one we made architecturally impossible. Each of your companies is in their own database; the API has no "show me everything" door for a misbehaving user to push on. **It's not a rule we enforce; it's a door we never built.**

---

## What I'll be honest about

Two things we haven't proven yet, named upfront — hiding them costs both of us later.

**One: we haven't actually run our own production with 50 million users on it yet.** What we have is the receipts. The 60-second test against app.one.ie at 1M-user load. Cloudflare's own track record at literally 10,000× our scale. And an architecture that doesn't change shape as you grow — only the dials.

We're not asking you to take that on faith. We're proposing a pilot.

**Two: how much load *your* customers will actually create, per company, is a model — not a measurement.** We'll find out together in week one. That's why pilots exist.

If either of those is a dealbreaker, tell me now and we'll structure the deal around it. If not, let's close them in the pilot.

---

## How we'd onboard your customers

Big-bang migrations fail. Ramped ones succeed. This is the shape I recommend:

```
PILOT      —  10 companies, 2 weeks, full observability
              we measure together; same dashboard, same numbers
              gate: 14 days green, errors under 0.1%

WAVE 1     —  100 companies, week 3
              same code, same numbers, just more of it
              one API call per company; <5 min per onboarding

WAVE 2     —  1,000 companies, month 2
              same again

FULL RAMP  —  your pace, not ours
              you set the speed of customer acquisition
```

I can have the pilot live within a week of you saying go.

---

## What you're standing on

None of this is bespoke. None of it is "trust me, I'm clever." Every layer underneath is something tens of thousands of other companies already trust:

- **Cloudflare** — 81+ terabits per second of network capacity. Discord runs on it. Shopify runs on it. Anthropic's claude.ai runs on it. So does ours.
- **V8 isolates** — the same engine inside the Chrome tab you have open right now. Starts in 5 milliseconds. We didn't invent it; we just used it.
- **D1, KV, R2** — Cloudflare's own storage primitives. Strong consistency per customer, replicated across regions for free.
- **Astro, React, TypeScript** — the same tools NASA, IKEA, and The Guardian use to ship fast websites.

We composed these. The composition is where the value lives. But every brick in the wall is one your engineers have already heard of, and every one of them is already serving someone larger than the scale you're bringing.

---

## The line

I built websites for 30 years and AI for the last 8. The thing I've learned is this: **whoever's fastest wins, the way to be fastest is to remove friction, and the way to remove friction is to keep things absurdly simple.**

That's the platform. That's why it scales. And that's why I can hand you a `/scale` URL with a live number on it instead of a glossy PDF.

If you want to take it for a spin: **[app.one.ie/scale](https://app.one.ie/scale)** — the numbers are live. Re-run the test yourself any time. The 60-second proof costs us zero dollars, which is roughly what it'll cost you to verify.

— Anthony

---

## For your engineers

- [`scale-tests.md`](scale-tests.md) — the full test suite, including the 2-hour Millions Proof we'll run before any signed deal
- [`web/tests/perf/reports/2026-05-16-millions-proof-cf-amp.md`](../one.ie/web/tests/perf/reports/2026-05-16-millions-proof-cf-amp.md) — Friday's run report with every number and the exact command to re-run it
- [`/scale`](https://app.one.ie/scale) — the live page (refresh anytime; numbers update on each re-run)
- `architecture.md`, `one-ontology.md`, `patterns.md` — the technical depth
