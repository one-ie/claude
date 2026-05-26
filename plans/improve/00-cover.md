# 00-cover — gap analysis

## Promise (from text/00-cover.md + text/contents.md)

- **Headline (00-cover.md:1):** "Resell an AI brand to every client. They never leave." A typo prefix (`mo`) corrupts the very first word.
- **Audience:** agency owner / CEO. Specifically a 15-year-old agency facing AI compression — Forrester 15% role cut, Gartner 22% CMO reduction. Not founders, not developers, not end users.
- **Thesis:** white-label the platform, mark up credits, keep the corpus when clients leave. "Distribution is the only moat." (00-cover.md:36)
- **Four operational proofs (00-cover.md:23-28):** 60s to live chatbot · 48h to fully-tuned client · 90s monthly report · $5.4M ARR at 5,400 clients × $1k/mo. Each cites a chapter and page.
- **One quote:** Naval Ravikant on distribution (00-cover.md:36-38).
- **Two answers built in:** margin (mark up from $0.0001/credit floor) + vendor risk (open-source substrate, product layer in escrow, one-command export).
- **Closing CTA (00-cover.md:52):** "See the platform you'll resell."
- **TOC (00-cover.md:56-76):** 16 chapters, each with a one-sentence "the line you'll underline." Brand → Agency → Chatbots → Models → Agents → Skills → Tools → Memory → Teams → Tracking → Analytics → CRM → Learning → Development → Security → Speed.
- **contents.md** is a rough scratch outline of the same 16 sections — confirms the book structure but adds nothing the cover doesn't already promise.

## Code reality

- **Home route** is `/Users/toc/Server/one-ie/one/web/src/pages/index.astro:43` — title `"ONE — The fastest AI brand you can sell"`. Renders `PersonalizedHero` → `Buyers` → `Strategy` → `Personas`. Authed non-end-users get bounced to `/dashboard` (index.astro:11).
- **Hero copy** (`web/src/lib/personalize-map.ts:14-41`): default eyebrow "White-label · Web + Mobile", headline "The fastest AI brand you can sell", sub "One platform. Any vertical. Set your price, keep the margin." CTA `Get yours` → `/get-yours`. Agency variant exists ("Resell AI brands · white-label, multi-client, billing built in") but only fires if persona is already detected.
- **Buyers strip** (`web/src/components/Buyers.tsx:10-15`): "Trusted by" → Agencies / Organizations / Governments / AI Agents. Four flat labels, no proof.
- **Strategy** (`web/src/components/Strategy.tsx:13-35`): three pillars — Speed / Reach / Ownership. No numbers, no chapter callouts.
- **Personas** (`web/src/components/Personas.tsx`): 4 audience cards that seed the chat. No agency-specific journey emphasised.
- **README.md** (one-ie/one/README.md:4) tagline: "AI agents that learn. Build in markdown. Deploy everywhere." Audience throughout is **developer** — `npx oneie`, code examples, markdown frontmatter, SDK + MCP + CLI. Agency / white-label / resell is **never mentioned**.
- **Pages that map to the 16 TOC chapters:**
  | TOC chapter | Page that exists | Maps cleanly? |
  |---|---|---|
  | 01 Brand | `design.astro` (token editor) | partial — design system, not brand cascade |
  | 02 Agency | `partners.astro`, `scale.astro` | partial — neither explicitly markets the agency tier |
  | 03 Chatbots | `chat.astro`, `ChatDock` everywhere | yes |
  | 04 Models | none | **missing** |
  | 05 Agents | `agents.astro` | yes |
  | 06 Skills | `skills.astro` | yes |
  | 07 Tools | `tools.astro` | yes |
  | 08 Memory | none (`crm/` dir hints) | **missing** |
  | 09 Teams | none | **missing** (agents.astro is the closest) |
  | 10 Tracking | `crm/` | partial |
  | 11 Analytics | none discoverable from home | **missing** |
  | 12 CRM | `crm/` | yes |
  | 13 Learning | none | **missing** |
  | 14 Development | `create.astro`, README | partial — split across repo |
  | 15 Security | none | **missing** |
  | 16 Speed | none (numbers nowhere on home) | **missing** |
- **No proof table on home.** None of the four 00-cover numbers (60s / 48h / 90s / $5.4M ARR) appear in `index.astro`, `Hero.tsx`, `Strategy.tsx`, `Personas.tsx`, or `Buyers.tsx`.
- **No Naval quote, no Forrester / Gartner stats.**
- **No "See the platform you'll resell" CTA.** Primary CTA is `Get yours`, secondary is `Learn more` → `#strategy`.
- **`contents.md:1`** — typo: `mo# Resell` → should be `# Resell`.

## Gaps

1. **Audience mismatch on every entry point.** The cover sells to an agency CEO. `index.astro` defaults to a generic "fastest AI brand" pitch; `README.md` sells to developers. The buyer named in the thesis (agency owner facing AI compression) does not see their own page unless persona tracking has already fired.
2. **None of the four proof numbers are on the home page.** "60s · 48h · 90s · $5.4M ARR" is the cover's load-bearing claim and it appears nowhere in code.
3. **TOC promises 16 chapters; home links to ~6 of them.** No surface for Models, Memory, Teams, Analytics, Learning, Security, Speed. The chapter promises become invisible to a visitor who only sees the home page.
4. **"See the platform you'll resell" CTA does not exist.** The cover's closing call is replaced with generic `Get yours`.
5. **No moat language on home.** Naval quote, "distribution is the only moat", corpus ownership, escrow, one-command export, $0.0001 credit floor — none appear in `Hero.tsx` / `Strategy.tsx`. The Ownership pillar (Strategy.tsx:29-34) is the closest and it is vague brand prose, not the cover's substantive moat argument.
6. **Buyers strip is flat labels, not proof.** `Buyers.tsx:10-15` lists four buyer types without a single logo, number, or quote. The cover claims "12,000 contacts, 7 ICPs, 200 active clients" — the home shows zero of this.
7. **Typo in the source-of-truth file.** `text/00-cover.md:1` starts `mo# Resell` and `text/contents.md` is a scratch draft, not the structured TOC the cover references. Anyone copying from `text/` will inherit the typo.
8. **`/dashboard` redirect (index.astro:11) hides the marketing page from anyone already logged in as a non-end-user** — including agency owners returning to share the link with a peer. They cannot demo their own home page.

## Recommended improvements

1. **Fix `text/00-cover.md:1` typo.** Replace `mo# Resell an AI brand…` with `# Resell an AI brand…`. One-line edit.
2. **Promote the agency variant to the SSR default.** Edit `web/src/lib/personalize-map.ts:14-21` — make `default` use the agency framing (headline "Resell AI brands", sub "White-label, multi-client, billing built in. Keep the corpus when clients leave."). Keep `founder`, `developer` as opt-in personalisations. Outcome: the named buyer sees their own page on cold visit.
3. **Add a Proof component on the home page** between `Buyers` and `Strategy`. New file `web/src/components/Proof.tsx`, imported by `index.astro:47`. Render the four 00-cover numbers as a 4-up grid (60s · 48h · 90s · $5.4M ARR) with the same chapter callouts. No new TOC chapter — direct mirror of the cover table. Outcome: the cover's load-bearing claim becomes visible.
4. **Replace the secondary CTA on `Hero.tsx:36-40`** from `Learn more` → `#strategy` to **"See the platform you'll resell"** → `/scale` (or `/agents` if `/scale` doesn't fit). Aligns with the cover's closing line.
5. **Add a `Moat` section** after `Strategy` in `index.astro`. New `web/src/components/Moat.tsx` with three blocks: corpus ownership, $0.0001 credit floor, open-source + escrow. Quote Naval once at the top. Outcome: vendor-risk and margin questions are answered above the fold-2.
6. **Rewrite `Buyers.tsx:10-15` as social proof, not category labels.** Either real logos (if any client agreed) or "12,000 contacts · 7 ICPs · 200 active clients" as numeric trust strip. Match the cover's distribution claim.
7. **Extend `Strategy.tsx` pillars from 3 → match the 16-chapter TOC via a "What you get" grid.** Add a sixth section to `index.astro` that links each chapter (Brand · Agency · Chatbots · Models · Agents · Skills · Tools · Memory · Teams · Tracking · Analytics · CRM · Learning · Development · Security · Speed) to its page or `#section`. Build the missing pages (`models`, `memory`, `teams`, `analytics`, `learning`, `security`, `speed`) as thin Astro pages that each render the matching `text/NN-*.md` body via the markdown-driven studio pattern (`web/agent-authoring.md`). Outcome: every cover promise has a clickable destination.
8. **Update `README.md` opening (line 4 + lines 55-114).** Add an "If you are an agency" panel near the top with three lines: white-label, mark up credits, keep the corpus. Keep the developer narrative — but stop letting it be the only one. Outcome: README and home tell the same story to the same buyer.
9. **Drop or gate the dashboard redirect on `index.astro:11`.** Either remove for `agency`/`owner` roles or add `?marketing=1` bypass. Outcome: returning agency owners can re-view and share their own home.

## Files to touch

- `/Users/toc/Server/one-ie/one/text/00-cover.md`
- `/Users/toc/Server/one-ie/one/web/src/pages/index.astro`
- `/Users/toc/Server/one-ie/one/web/src/lib/personalize-map.ts`
- `/Users/toc/Server/one-ie/one/web/src/components/Hero.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/Buyers.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/Strategy.tsx`
- `/Users/toc/Server/one-ie/one/web/src/components/Proof.tsx` (new)
- `/Users/toc/Server/one-ie/one/web/src/components/Moat.tsx` (new)
- `/Users/toc/Server/one-ie/one/web/src/components/Chapters.tsx` (new — 16-chapter grid)
- `/Users/toc/Server/one-ie/one/web/src/pages/models.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/memory.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/teams.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/analytics.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/learning.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/security.astro` (new)
- `/Users/toc/Server/one-ie/one/web/src/pages/speed.astro` (new)
- `/Users/toc/Server/one-ie/one/README.md`
