# persona-agency-owner — gap analysis

Anchor persona: Brad Poirier (PT Corp / BOQ) per `text/persona-agency-owner.md`. Mid-fifties, 30-person agency, 7 ICPs, 12k contacts, ~200 active clients, betting on a 5,400-client / $5.4M ARR forecast at 95% gross margin. Awareness level 4 (product-aware, not yet committed). Source: `text/persona-agency-owner.md` §1, `text/02-agency.md`, `web/roles.md`, `donal/tony-plan-summary-2026-05-15.md`, BOQ JV memory.

---

## Persona (jobs / fears / objections / triggers)

**Functional jobs** — replace headcount £ with software £; ship 50 clients in 6 weeks without 50 meetings; 90%+ gross margin retainer; identical 5-thing delivery (chat / edits / leads / reports / payment) per client; pluggable 6th/7th service later.

**Emotional jobs** — stop being the bottleneck; stop dreading the talent meeting; stop apologising for missed deliverables; stop being the guy who didn't see it coming.

**Social/identity jobs** — be the agency that "got AI right"; become a *platform founder* not an *agency owner*; build something sellable / inheritable.

**Top fears (3am list, §8)** — vendor pivots/raises/acquired; clients realise it's AI and demand discounts; AI screws up in front of marquee client; team feels replaced and quits; GDPR / state-AI regulation bites; budget spent, tech still isn't ready; competitor lifts ONE first.

**Top objections (§10)** — *what if you pivot?* · *clients will demand a discount* · *AI says something stupid* · *GDPR/compliance* · *why not build?* · *vs HubSpot/GHL/Vendasta?* · *can I leave with my data?* · *what if I overspend?* · *team replacement* · *worst case* · *why now?*

**Triggers** — board meeting in 8 weeks; senior strategist with another offer; client fired him for "trying ChatGPT instead"; flat January pipeline; talent budget at 65% of revenue; partner Donal pushing pace.

**Reading mode for the PDF/site** — level 4-to-5, expects proof not pitch. Banned words list (§13) is long: *AI-powered, cutting-edge, game-changer, future-proof, transform, empower, seamless, reach out*. He's past every one.

---

## Surfaces aimed at this persona

Mapped against the agency-tier story in `text/02-agency.md` and the 4-tier viewer in `web/roles.md`:

| Surface | File | What it does for Brad |
|---|---|---|
| Public home | `web/src/pages/index.astro` | Tagline ("fastest AI brand you can sell"); `<Buyers>` lists *Agencies* as first chip; `<Strategy>` 3 pillars (Speed / Reach / Ownership); `<Personas>` 8-tile picker. No agency-owner-specific tile. |
| Agency-tier deck | `text/02-agency.md` | The single page that lands the JTBD, the £/$ unit economics, the 5,400-client maths, the white-label cascade, all 6 objections, FAQ, glossary. **Strongest agency surface in the entire repo.** Lives in `text/`, not yet wired to a web route. |
| Workspace dashboard | `web/src/pages/u/[slug]/dashboard.astro` + `components/dashboard/*` | Hero number, persona tabs (CEO / Mktg / Sales / Service), hot accounts, funnel ribbon, `ClientsCard`. Agency-aware but built around *one workspace*, not *a portfolio of client workspaces*. |
| Workspace billing | `web/src/pages/u/[slug]/billing.astro` + `billing/{allocations,plans,platform,simulate}.astro` | Pool, ledger, top-up; `allocations.astro` is the per-client distribution view; `platform.astro` is owner-only agency breakdown. Wired to the cascade described in `02-agency.md`. |
| Provisioning API | `web/src/pages/api/provision/bulk.ts` + `lib/in/bulk-provision.ts` | Bulk-create client workspaces. API exists; UI surfacing is thin. |
| Settings | `web/src/pages/u/[slug]/settings.astro` + `web/src/pages/settings/*.astro` | Per-workspace brand / packs / integrations / templates / tags / privacy. No "manage clients" panel. |
| Partners page | `web/src/pages/partners.astro` | Aimed at independent agent publishers (referral split), not agency operators. |
| Scale page | `web/src/pages/scale.astro` | Capacity/perf story, not commercial. |
| Persona tile | `web/src/lib/personas.ts` | 8 personas: `executives, engineers, designers, marketers, sellers, creators, young, kids`. **No `agency` tile.** Chat seeds map to functional roles only. |
| BOQ-specific deliverables | external `boq-*.pages.dev` (per `reference_boq_links.md`) | Pitch, forecast, ICP explorer, workspace wireframe, competitive matrix. **Lives outside the product repo.** |
| BOQ doc inside repo | `web/boq.md` | Operator brief; not user-facing. |

---

## Copy aimed at this persona

| Asset | Reads to Brad as |
|---|---|
| `text/02-agency.md` | **On-target.** Hits push (margin / talent / churn), pull (corpus moat / 89% margin / £2M payroll shipped day one), defuses 6 of 12 objections, walks the unit economics, names the exit clean. Voice is right. Numbers are concrete. Glossary is there. This is the artefact that wins Brad. |
| `text/00-cover.md` | Cover page exists but not yet rendered as a web hero. |
| `text/{05-agents,08-memory,09-teams,11-analytics,13-learning,15-security,16-speed}.md` | All map onto Brad's `problems → ONE solutions` grid (`text/persona-agency-owner.md §9`). Quality high. |
| `index.astro` headline | "ONE — The fastest AI brand you can sell." Tagline lands the pull (speed + ownership), but pull-alone copy. Misses the push (your ceiling is payroll) and the proof stack (5s / 60s / 48h / 90s). |
| `Strategy.tsx` pillars | Speed / Reach / Ownership. "Ownership" pillar uses *"white-label end-to-end... we power the substrate; the relationship — and the revenue — stays yours."* — directionally right, but generic. No numbers, no payroll-replacement frame, no 4-tier cascade visible. |
| `Personas.tsx` tiles | No agency tile. Brad lands on a homepage that doesn't reflect him back. Closest tile is `sellers` ("Close the deal") — wrong audience. |
| `Buyers.tsx` trust strip | Lists "Agencies" first — good — but as a generic *audience* claim, not a *positioning* claim. No named partner; the doc explicitly authorises dropping Brad/BOQ as social proof (§4 Guide). |
| `partners.astro` | Confuses the agency motion with the publisher/referral motion. Brad is not a "publisher of agents." |

---

## Gaps (what they need that's missing or under-served)

1. **Brad cannot get to `02-agency.md` from the public site.** It is the single best agency-tier asset in the repo and it lives only as a markdown file. There is no `/agency`, `/agencies`, `/scale` (taken), or `/resell` route that surfaces this content. The homepage doesn't link to it. Brad reads the home, doesn't see himself, leaves.
2. **No agency persona on the public homepage.** `Personas.tsx` has 8 tiles (`executives → kids`); none of them represent the agency-owner buying motion. The chat seeds don't include an agency walkthrough.
3. **No agency-owner dashboard.** `web/src/pages/u/[slug]/dashboard.astro` is one-workspace-deep. The role doc (`web/roles.md §7`) and the JV brief (`donal/tony-plan-summary-2026-05-15.md`) both describe a portfolio view (per-client revenue, per-client burn, per-client status, churn risk, escalations). It is wireframed externally at `boq-diagrams.pages.dev/workspace-dashboard-wireframe` but not built in this repo.
4. **No client-management UI.** The provisioning API exists (`api/provision/bulk.ts`); no settings panel exposes "create client", "invite client", "set markup per client", "set cap per client", or "view client list with status". `roles.md §14 Step 6` flags this as not-yet-built.
5. **No agency-tier sign-up flow.** Pricing path in `02-agency.md §Pricing path` names `agency $500 / 5M credits / 20% markup baseline` but there is no buy/checkout route for the agency plan. `/buy` does not exist as a route. `payments.astro` exists; agency plan SKU not surfaced.
6. **The proof stack from the persona doc is not on the home page.** The four numbers Brad is told to see on cover (`5s wallet · 60s bot live · 48h fully tuned · 90s monthly report`) appear in `00-cover.md` and `02-agency.md`, not in `index.astro`. The home shows no receipts.
7. **Top fears are not addressed on any public-facing page.** Vendor pivot risk (open-source substrate + escrow), AI-says-wrong-thing risk (0.65 quality gate), client-discovers-AI risk, team-feels-replaced risk, GDPR risk — all covered in `02-agency.md` §Objections and `text/15-security.md`. None of it links from `index.astro`. Brad's 3am fears go un-defused on the surface he sees first.
8. **Brad's social/identity job is invisible.** "Become a platform founder, not an agency owner" is the most powerful lever in the persona doc (§2 Identity jobs, §4 Philosophical problem). The home, the pillars, and the chat seeds never name this transition.
9. **No social proof / named partner.** Persona doc §4 (Guide) explicitly authorises mentioning Brad/BOQ as a real partner. Nothing on the site does. `Buyers.tsx` lists generic audiences; no logos, no quotes, no case-study link, no "agencies already shipping" badge.
10. **No call to a binary, measurable agency action.** Persona §4 (Plan) requires *"Deploy a Marketing, Sales and Service team to one client this week."* Home CTA path goes to `/chat` with no agency-specific seed. Pilot 1 framing (50 clients / 6 weeks) is invisible to a self-serve visitor.
11. **The 4-tier cascade is described but not demoed.** A live preview ("see the OAuth screen with your name", "preview the client invite email", "switch viewer tier") would defuse white-label scepticism instantly. The viewer model is shipped (`roles.md §14 Step 1`); the demo isn't.
12. **Pricing is on the agency markdown, not on a pricing page.** `02-agency.md §Pricing path` table has 3 plans (`starter $5 / growth $50 / agency $500 / agency-plus $5k`). No public `/pricing` route surfaces them. Brad cannot quote his board.
13. **Two competing agency stories.** The OO/Donal Phase-1 model (`donal/tony-plan-summary-2026-05-15.md`) makes OO the Tier 2 operator and Brad the Tier 3 channel partner. `02-agency.md` writes to Brad-as-Tier-2 directly. The product narrative needs to pick one tier-story for the public site or both Brads will be confused — the channel-partner Brad needs a different page than the operator Brad.
14. **Donal (the technical partner) has nothing to read.** Persona §12 names §14 Development as Donal's page — exists as `text/14-development.md`, not on web. Anxiety #6 (*"What if I commit and the tech doesn't deliver?"*) is partly Donal's job to defuse for Brad; we don't help him.

---

## Recommended improvements

Speed-ordered. Each addresses one or more gap rows above.

| Cycle | Change | Files | Gaps closed |
|---|---|---|---|
| **W1** | Add `agency` persona tile to home + seed an agency-walkthrough chat prompt | `web/src/lib/personas.ts`, `web/src/components/Personas.tsx` | 2, 10 |
| **W1** | Render `text/02-agency.md` as `/agency` route (`web/src/pages/agency.astro`); link from home hero, from `Strategy.tsx` Ownership pillar, from `partners.astro` | `web/src/pages/agency.astro` (new), `index.astro`, `Strategy.tsx` | 1, 6, 7 |
| **W1** | Add proof-stack strip to homepage (`5s · 60s · 48h · 90s`) under the hero, with each number link-deep into the page that proves it (`/scale`, `/chat`, `/agency`, `/u/[slug]/analytics`) | `index.astro`, new `<ProofStack>` component | 6 |
| **W1** | Rewrite `Strategy.tsx` Ownership pillar copy to name the payroll-replacement frame, white-label cascade in one line, and quote the 89% gross-margin / 5,400-client number from `02-agency.md` | `web/src/components/Strategy.tsx` | 8, 11 |
| **W1** | Add a `/pricing` page that surfaces the four plans from `02-agency.md §Pricing path` with the agency plan featured and a checkout-stub CTA | `web/src/pages/pricing.astro` (new) | 5, 12 |
| **W2** | Build the agency-owner portfolio dashboard view — multi-workspace, per-client burn / status / escalation, markup column. Promote the existing `ClientsCard.tsx` into the primary card. Mirror `boq-diagrams.pages.dev/workspace-dashboard-wireframe` | `web/src/pages/u/[slug]/dashboard.astro`, `web/src/components/dashboard/ClientsCard.tsx` | 3 |
| **W2** | Build the "Clients" settings panel: create / invite / per-client plan / per-client markup / per-client cap / suspend / export. Wire to `api/provision/bulk.ts` and the `clients/{clientSlug}.md` R2 store described in `roles.md §11` | `web/src/pages/u/[slug]/clients.astro` (new), `web/src/pages/settings/clients.astro` (new), `web/src/components/settings/ClientsPanel.tsx` (new) | 4, 11 |
| **W2** | Add a live "white-label preview" widget on `/agency` — viewer-tier switcher (owner / agency / client / end_user), live OAuth-screen mockup, live invite-email mockup, brand-token applied in-place | `web/src/components/agency/WhiteLabelPreview.tsx` (new) | 11 |
| **W2** | Add objection-handling block to `/agency` that mirrors `02-agency.md §Objections answered` but as collapsible cards with the 0.65 quality-gate, the open-source-substrate link, the GDPR delete-in-one-command demo | `web/src/pages/agency.astro` | 7 |
| **W3** | Decide the public agency story: Brad-as-operator vs Brad-as-channel-partner. Reconcile `02-agency.md` with `donal/tony-plan-summary-2026-05-15.md`. If Phase-1 OO-as-operator is the public story, fork `02-agency.md` into `02-agency-operator.md` (for the OO/Donal/HK-JV audience) and `02-agency-channel.md` (for Brad's 12k list) | `text/02-agency.md`, `text/persona-agency-owner.md` | 13 |
| **W3** | Add named-partner social proof. With Brad's permission, list BOQ as the first agency case-study on `/agency` and `index.astro`. Quote, logo, headline number | `index.astro`, `agency.astro`, `Buyers.tsx` | 9 |
| **W3** | Add a `/developer` or `/build` route from `text/14-development.md` for Donal — substrate-extension story, the three-command deploy, the SDK reference. Link from `/agency` | `web/src/pages/build.astro` (new) | 14 |
| **W3** | Add agency-owner chat seeds: "Show me the unit economics for 50 clients", "Walk me through the cascade", "What happens if I leave?". Wire into `Personas.tsx` agency tile | `web/src/lib/personas.ts`, `claw/` agent | 2, 10 |

---

## Files to touch

**New routes**
- `web/src/pages/agency.astro` — render `text/02-agency.md`; add objection cards + white-label preview + pricing CTA
- `web/src/pages/pricing.astro` — surface the 4 plans
- `web/src/pages/build.astro` — Donal's page from `text/14-development.md`
- `web/src/pages/u/[slug]/clients.astro` — agency-owner client list
- `web/src/pages/settings/clients.astro` — create / invite / set markup / suspend

**Edits**
- `web/src/pages/index.astro` — add proof-stack strip; add agency-walkthrough CTA in hero
- `web/src/components/Strategy.tsx` — rewrite Ownership pillar with the £/$ numbers and the payroll-replacement frame
- `web/src/components/Personas.tsx` + `web/src/lib/personas.ts` — add agency tile + seeds
- `web/src/components/Buyers.tsx` — add named-partner row when Brad agrees
- `web/src/pages/u/[slug]/dashboard.astro` + `web/src/components/dashboard/ClientsCard.tsx` — portfolio view
- `web/src/components/dashboard/Dashboard.tsx` — add `agency` persona tab alongside CEO/Mktg/Sales/Service

**New components**
- `web/src/components/agency/WhiteLabelPreview.tsx` — viewer-tier switcher + OAuth/invite mockups
- `web/src/components/agency/ProofStack.tsx` — `5s · 60s · 48h · 90s` strip
- `web/src/components/settings/ClientsPanel.tsx` — bulk-provision UI on top of `api/provision/bulk.ts`

**Spec / copy**
- `text/persona-agency-owner.md` — note the operator-vs-channel-partner fork from gap #13
- `text/02-agency.md` — possibly fork into `02-agency-operator.md` + `02-agency-channel.md` depending on the resolution
- `web/roles.md §14 Step 6/7` — promote client-manager UI from "future" to "next cycle"

**Reference (no edit)**
- `web/boq.md` — operator brief; informs but doesn't constrain
- `donal/tony-plan-summary-2026-05-15.md` — Phase-1/Phase-2 story; required reading before writing the public agency page
- `boq-diagrams.pages.dev/workspace-dashboard-wireframe` — visual target for the portfolio dashboard
