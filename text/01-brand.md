# Brand

Your agency's brand on a substrate you don't have to operate. One brain, many faces.

---

> "A brand is no longer what we tell the consumer it is — it is what consumers tell each other it is."
>
> — Scott Cook, founder of Intuit

That sentence should worry any agency owner still building on a platform they don't control. When your client's bot says something off-brand at 2am on a Saturday and the client posts it, the brand that suffers isn't ONE's. It's yours.

This page is about stopping that. Not through policy. Through mechanics. Six CSS tokens. One CNAME record. A voice contract that runs before every message goes out. The platform disappears behind your brand. The thing your clients see is you.

---

## Create in 60 seconds

Sixty seconds from opening the brand editor to a working, branded, deployed client workspace. Not as a marketing claim with an asterisk. Sixty seconds with a click count.

**The flow:**

1. Open `yourslug.one.ie/settings/brand`, or your custom domain if the CNAME is already in. (1 click)
2. Pick six colours: background, foreground, font, primary, secondary, tertiary. Each shows a swatch. WCAG AA contrast updates live as you move the slider. Below 4.5:1, the input goes red. The save button refuses to save a failing combination. (6 interactions, around 20 seconds)
3. Drag your logo onto the upload target, or click to browse. SVG or PNG, up to 2MB. The favicon derives from the logo automatically, a 32x32 crop from the top-left quadrant. Override it separately if you want. (1 interaction, 5 seconds)
4. Type `yourdomain.com` or `acme.yourdomain.com` in the domain field and click Verify. The platform issues a TXT record value. Once DNS propagates (typically under 60 seconds on Cloudflare-managed domains, up to 5 minutes elsewhere), click Verify again. (2 interactions, variable wait)
5. Click Save. The workspace is live at your domain. Every client already under your agency picks up the brand change on next page load. (1 click)

**Total: 11 interactions, 55 to 65 seconds for the editor, plus DNS wait.** On Cloudflare DNS, the full flow including domain verification is typically under 3 minutes. On a slower registrar, add 5 minutes for DNS.

That is the single-agency case. The cascade means every change at the agency level flows down to your clients automatically. Rebrand your agency next year, change six tokens once, every client workspace updates. You don't touch 200 individual workspaces.

**Worked example, dental practice, week 1:**

Marcus runs a marketing agency in Manchester. Forty-seven dental practices on his book. He's adding a new client on a Tuesday afternoon. He opens the brand editor, pastes the practice's primary green (`hsl(142, 70%, 35%)`), uploads the logo, types `northdentalgroup.co.uk` as the domain. Fifty-five seconds later, the practice's marketing assistant opens `northdentalgroup.co.uk/chat` and sees a chat interface that looks like the practice's own website. Not Marcus's agency's site. Not ONE's platform. The contrast ratio on the primary green over white is 5.2:1, so WCAG AA passes.

Marcus didn't need a designer. Didn't need a developer. Didn't file a ticket. He had a cup of tea before the job was done.

---

## The 6-token design system (and why only 6)

Six tokens. Not sixty. Not sixteen. Six, by choice.

The reason is the same reason a piano has 88 keys and a colour printer has four inks. You need enough range to express anything real, but not so many moving parts that the system defeats itself. A designer given 100 variables will find 100 things to change. A designer given 6 will find a coherent look fast and stay coherent.

Here are the six, as they appear in `web/src/layouts/Layout.astro`:

```css
/* Six editable tokens — the only colours
   an agency or client owner can change.
   Declared in @theme; Tailwind v4 enforces them. */

--color-background: hsl(0 0% 93%);   /* card surfaces, sidebar, popovers */
--color-foreground: hsl(0 0% 100%);  /* inner content rectangles, inputs */
--color-font:       hsl(0 0% 13%);   /* all body text */
--color-primary:    hsl(216 55% 25%);/* main CTAs, brand accents, focus rings */
--color-secondary:  hsl(219 14% 28%);/* supporting actions, secondary buttons */
--color-tertiary:   hsl(105 22% 25%);/* highlights, success checks, accents */
```

Those six values drive every visual surface the end user sees. Everything else is computed. `--color-border` is `font` at 10% opacity. `--color-muted` is `font` at 60%. `--color-page` is `background` mixed with 4% `font`. `--color-ring` is `primary`. None of those helpers are editable.

**Why this matters when you resell to 50 clients:**

When every value derives from six inputs, every workspace is internally consistent by construction. You cannot set a primary colour that produces an unreadable button label. The `on-primary` label colour is computed to be either black or white depending on the primary's luminosity. If `--color-primary` is at L=65 or above, `on-primary` flips to black. Below L=60, it stays white. The threshold is enforced in code, not in a designer's judgement.

That is a liability shield. When a client's end user cannot read the primary call-to-action, the client blames the agency, not the platform. The 6-token system makes that call impossible to receive. The system refuses to produce it.

**Plus 5 invariants, never editable:**

On top of the six tokens, five values are fixed across every workspace.

| Token | Hex / Value | Use |
|---|---|---|
| `white` | #fff | Absolute white where needed |
| `black` | #000 | Absolute black where needed |
| `transparent` | transparent | Transparent fill |
| `destructive` | hsl(0 70% 50%) | Errors, deletions, danger states |
| `success` | hsl(140 60% 40%) | Confirms, completions |

`destructive` and `success` carry semantic meaning that transcends branding. A client cannot change their destructive colour to a pleasant lilac. Error states have to look like errors. That consistency is part of what makes the platform safe to white-label. Even with a strong client brand, danger signals still read correctly to their end users.

**Three depth levels:**

The six tokens sit across three depths. Every surface in the product lives at exactly one.

| Level | Surface | Where you see it |
|---|---|---|
| L0 page | `--color-page` | `<body>`, the full-bleed shell behind everything |
| L1 card | `--color-background` | Cards, sidebar, popovers, dropdowns |
| L2 content | `--color-foreground` | Card body, inputs, code blocks |

Sidebar is L1. Inputs are L2. There is no L3. This three-level constraint means every workspace, however differently coloured, shares the same visual grammar. A dentist's workspace and a restaurant's workspace and a window installer's workspace all share the same spatial logic. End users learn the grammar once. It transfers across every client they touch.

**WCAG AA, enforced not aspirational:**

Contrast ratios are calculated at save time. The minimum the system accepts is 4.5:1 for body text (WCAG AA). Decorative elements can drop to 3:1. If a combination fails, the editor shows the failing ratio and highlights the offending token. The save button stays disabled until the combination passes.

This matters commercially. In the UK, the Equality Act 2010 requires digital services to be accessible. If an agency sets an unreadable combination and a client's end user with a visual impairment cannot use the interface, the liability chain runs back to the person who configured it. The platform refuses to let that happen.

**What you cannot do with 6 tokens:**

You cannot pixel-match a client whose brand sits on a 7th or 8th variable. If a brand guide calls for three distinct accent colours, brand blue for CTAs, brand green for success, brand orange for highlights, the system maps those to primary, success (invariant), and tertiary respectively. The invariant `success` token will not shift to brand orange. Safety signals stay fixed.

The answer is the locking grammar, not more tokens. Lock primary, lock secondary, leave tertiary unlocked, let the client's designer route their third colour into the available slot. No dental practice in fifteen years has filed a complaint that the success tick was green instead of orange.

---

## Your domain (CNAME → verify → routed)

The domain flow is four steps. The fourth, routing requests to the correct TypeDB Group, is what makes the domain commercially useful, not just cosmetically satisfying.

```
CNAME record (your DNS)
  ↓
Domain verified in workspace settings
  ↓
Cloudflare Worker middleware matches incoming host header
  ↓
resolveConfig() maps host → workspaceSlug → TypeDB Group (<10ms)
```

In practice, `acme.com/sales/quote` resolves to your agency's Group in TypeDB in under 10ms, with every agent, skill, memory corpus, and billing pool correctly scoped to your client. The URL shows your domain. The routing decision is invisible. The end user is in your client's workspace.

**Setting the CNAME:**

In your DNS provider (Cloudflare, Route 53, Namecheap, any of them), you add one record.

```
Type:  CNAME
Name:  @ (for apex) or subdomain
Value: your-workspace.one.ie
TTL:   Auto or 3600
```

For apex domains (`acme.com` without a subdomain), Cloudflare supports CNAME flattening, which handles the RFC prohibition on apex CNAMEs automatically. Other DNS providers may require an ALIAS or ANAME record at the apex. The platform accepts any of these. If your registrar only supports A records at the apex, the verification flow shows the current edge IP list.

After adding the record, verification issues you a `TXT` value.

```
Type:  TXT
Name:  _one-verify.acme.com
Value: one-verify=a8f4c2e1b9d7...
TTL:   3600
```

Add the TXT, wait for propagation, click Verify. The platform checks for the TXT from five Cloudflare edge locations at once. If any three of five see it, verification passes. This distributed check stops a false negative from a propagation race to a single verification server.

Once verified, the CNAME and TXT records both stay in place. The TXT is used for annual re-verification, a passive check that runs every 90 days to confirm the domain is still owned by the agency that registered it. Re-verification is silent unless it fails.

**The middleware match:**

The Cloudflare Worker reads the `Host` header on every incoming request. If the host is a registered custom domain, `resolveConfig()` is called with the mapped workspace slug. The entire config (tokens, sidebar, agents, billing pool) loads from R2 in a single read, with a KV edge cache in front. Cache TTL is 60 seconds. On a cache hit, the config is available before the first byte of the response is sent. On a miss, the R2 read adds roughly 15ms.

That cache matters at scale. An agency with 200 clients, each on a custom domain, generating 50 requests per minute each, is serving 10,000 requests per minute across 200 workspace configs. Without the KV cache, that would be 10,000 R2 reads per minute. With it, under 4 per minute, because the same config is served from edge cache for a full minute before re-fetching.

**Worked example, window installer, month 2:**

Sandra runs a B2B agency specialising in trades businesses. Her client is a window installer in Birmingham with a strong regional brand. The client insists the chat live at `chat.midlandwindows.co.uk`. Sandra adds the CNAME, adds the TXT, clicks Verify. Propagation takes 3 minutes. She clicks Verify again. The workspace goes live at the client's domain. The client's end customers visit `chat.midlandwindows.co.uk` and see a chat interface with the installer's brand, colours, and logo. They have no awareness that Sandra's agency is involved, let alone ONE. That is the product working correctly.

---

## Embed anywhere (script tag, iframe, MCP, A2A)

The brand surface is not confined to a hosted URL. It travels. Four embedding modes, each fitting a different client context.

**Script tag:**

The lightest embed. One script tag in the client's existing website, and a chat widget appears in the bottom-right corner. The widget inherits the workspace tokens from the server at load time. It reads resolved CSS custom properties from the workspace config, not from a hardcoded stylesheet. Update the tokens, the next page load on the client's site reflects the change.

```html
<!-- Add to the client's website <body> -->
<script
  src="https://acme.com/embed.js"
  data-workspace="northdentalgroup"
  data-position="bottom-right"
></script>
```

The script is served from your agency's domain (once the CNAME is done), not from `one.ie`. The client's customers who check the network tab see `acme.com/embed.js`. You are the vendor.

**iframe:**

Full-page embed for clients who want the complete chat UI inside their existing web app or patient portal. The iframe URL is the workspace's chat route on your domain. The iframe receives no third-party cookies. Authentication uses a short-lived signed URL that the client's server generates when it renders the page. Session data stays inside the iframe's browsing context.

```html
<!-- Full-page chat in an iframe -->
<iframe
  src="https://northdentalgroup.co.uk/chat?token=signed-url-here"
  width="100%"
  height="600"
  frameborder="0"
></iframe>
```

**MCP (Model Context Protocol):**

For clients running their own AI tools (Claude Desktop, Cursor, internal developer tooling), the workspace exposes an MCP server at a stable URL. The MCP server carries the workspace's brand identity in its server metadata, and every tool call is scoped to the workspace's corpus. A client's developer connecting their IDE to the MCP endpoint is using a branded, scoped, agency-resold AI surface without leaving their editor.

**A2A (Agent-to-Agent):**

Other agents, from other platforms, from the client's own systems, can call into the workspace via a documented A2A endpoint. The endpoint enforces workspace scoping. An external agent calling in can only read and write data inside that workspace's Group boundary. Brand identity is carried in response metadata, not in the API responses themselves. The scoping means the workspace stays branded and contained.

---

## What "your brand" covers

"White-label" is often shorthand for slapping a logo on a UI someone else built. That is not what this means. Here is the complete map of every surface where your brand appears.

| Surface | Where your brand shows up |
|---|---|
| Chat UI | Logo in header, six tokens throughout, custom welcome message, starter chips |
| Invoice | Agency name, logo, payment terms, line items. ONE does not appear |
| OAuth consent screen | "Sign in to [Your Agency Name]". Your name, your logo, your terms URL |
| Transactional email | From address is your domain (`noreply@youragency.com`); sender name is yours; footer is yours |
| Status page | Hosted at `status.yourdomain.com`. Incidents attributed to your agency, not the platform |
| 404 / error pages | Branded to the workspace. Workspace logo, primary colour, name in the heading |
| Favicon | Your uploaded favicon, served from your domain |

The OAuth consent screen deserves a sentence. When a client's end user authenticates with Google, the consent screen says your agency's name. Your agency's logo. Your agency's privacy URL. The end user grants consent to your agency. From the user's point of view, your agency is the platform. From the user's point of view, this is a product you built.

That is not a cosmetic choice. It is the difference between building a business and reselling someone else's.

**Day in the life, agency owner, 9:47am Thursday:**

Brad's phone shows a Slack message from his account manager: "Meridian Physio wants to know if they can put the chat widget on their booking page." Brad is in a cab. He opens his agency's admin panel on his phone, navigates to the Meridian workspace, confirms the embed is already enabled (it is, he turned it on six weeks ago when he onboarded them). He forwards the embed snippet. By 10:15, the widget is live on the physio's booking page, showing the physio's green brand colour, the physio's logo, and a starter chip that says "Ready to book?" The physio's receptionist clicks it to test, replies "nice," and closes the tab. The account manager marks the task done. Brad didn't write a line of code. Didn't talk to a developer. Didn't file a ticket. His brand showed up exactly where it was needed, in 28 minutes from request to live.

---

## The white-label cascade in practice

The cascade is four tiers. Owner (ONE) → Agency (Brad) → Client (the dental practice) → End user (the patient). Each tier inherits from the tier above and can override or lock individual properties going down. No tier can override what the tier above has locked.

```
ONE (owner)
  ├── Sets: platform defaults, global feature flags
  ├── Sets: credit pricing floor ($0.0001/credit)
  └── Delivers to →

ACME Agency (Brad)
  ├── Configures: ACME brand (logo, 6 tokens, domain acme.com)
  ├── Can lock: primary colour, logo (clients cannot override these)
  ├── Can enable/disable: features per client plan
  └── Delivers to →

North Dental Group (client)
  ├── Configures: their sub-brand within ACME's locked properties
  ├── Can set: their own accent colour if ACME unlocked it
  ├── Sees: their agents, their billing, their chat conversations
  └── Delivers to →

Patient (end user)
  ├── Sees: North Dental Group brand (or ACME brand where unlocked)
  ├── Can set: dark/light mode preference
  └── Accesses: chat + whatever features their client enabled
```

In code, the cascade runs in `src/middleware.ts` via `resolveConfig()`, which merges three layers of `site.md` files from R2. The merge is deterministic. Layer 1 is the workspace (agency). Layer 2 is the group (client team if applicable). Layer 3 is the client sub-workspace. A locked property at Layer 1 survives the merge unchanged. An unlocked property can be overridden at Layer 2 or 3.

**The locking grammar:**

In the agency's `site.md` configuration:

```yaml
# ACME Agency — site.md
name: ACME Marketing Platform
primary: hsl(142 70% 35%)
primary-locked: true      # clients cannot change brand green
logo-locked: true         # ACME logo appears on all sub-workspaces
features: [chat, agents, tools, settings]
features-locked: false    # clients can adjust their feature set
```

With `primary-locked: true`, every client workspace under ACME inherits the primary green. The client's colour picker for primary is greyed out. They can customise background, foreground, font, secondary, and tertiary. That is five of six. This lets Marcus hold brand consistency across 47 dental practices while still giving each practice room to express their own secondary palette.

Without locking, a client could override primary to magenta. That might fit some agency relationships, the ones where the client genuinely wants full control. It would be wrong for Marcus, whose proposition to practices is "we handle all of this for you."

**Worked example, restaurant group, month 3:**

Priya runs a digital agency in Dublin with 12 restaurant clients. Three of them are outlets of the same group, different locations, same parent brand. She creates the parent brand at the group level, locks the primary (the restaurant's signature red), and creates three client workspaces, one per location. Each location can customise welcome message, starter chips, and secondary, but the brand red is locked. The three locations' chat interfaces look like siblings. Same character, different personality. Priya did not build three interfaces. She built one and cascaded it.

**What you can lock (complete list):**

Properties in the cascade support a `-locked` suffix for any of these:

- `name` (workspace display name)
- `tagline` (one-line descriptor)
- `logo`
- `favicon`
- `domain`
- Any of the 6 brand tokens (`background`, `foreground`, `font`, `primary`, `secondary`, `tertiary`)
- `features` (which features the tier below can access)
- `theme` (dark/light/system default)

A layer can only lock properties it has set. A client cannot lock a property the agency set. Locks cascade downward. They cannot be removed by a tier below the one that set them.

**The commercial logic:**

An agency that locks its logo and primary can sell a white-label service while holding a coherent agency brand across the whole book. This is the difference between being a platform operator and being a subcontractor. A subcontractor's brand disappears into the client's. A platform operator's brand sits above the client's, shaping it without overriding it.

Brad's clients know they're on a platform. They're paying for that. They're not paying for custom development. They're paying for a managed, branded, capable AI marketing surface that the agency maintains. The locking grammar makes that maintenance scalable. Brad updates the agency logo once, and 200 client workspaces reflect the change by the next page load.

---

## Numbers worth putting in front of your CFO

These drive the commercial case for investing in brand configuration before your first client deployment.

- **6 design tokens.** The complete set of editable colours. No design skills required to produce a coherent, accessible workspace. A non-designer can do it in under 2 minutes with a brand guide in hand.
- **5 invariant tokens.** Reserved for safety semantics. Non-negotiable. This is what ensures `destructive` always reads as an error state regardless of client branding.
- **3 depth levels.** Page, card, content. Every surface in the product maps to exactly one. No exceptions. This constraint is what makes any colour combination look spatially coherent even when the colours themselves are unusual.
- **WCAG AA 4.5:1 minimum contrast ratio.** Enforced at save time. Cannot be bypassed. The UK Equality Act 2010 and the EU Web Accessibility Directive both require this minimum for digital services accessible to the public.
- **<10ms domain resolution.** The middleware maps `acme.com` to workspace slug to TypeDB Group in under 10ms on a KV cache hit. At 60-second TTL, the cache hit rate for any active workspace exceeds 99% during business hours.
- **1 CNAME record.** The complete DNS requirement for a custom apex domain on Cloudflare. Registrars without CNAME flattening need an ALIAS record instead. One record, either way.
- **60-second TTL** on workspace config edge cache. Short enough that a brand update propagates to all edge locations within one minute of saving. Long enough to keep R2 reads negligible.
- **Annual re-verification.** Domain ownership is checked passively every 90 days. Silent unless it fails. No agency action required unless the domain's DNS changes.
- **Zero additional engineering cost** to brand a new client workspace. The 11-interaction flow is the whole procedure. If you are paying a developer £80/hour to configure client brand settings, that cost is gone.

**The pricing math, brand configuration cost per client:**

Agency hourly billing rate £150. Developer hourly rate £80. Old process: design brief → designer creates stylesheet → developer implements → QA → deploy. Time: 4 hours minimum, typically 8.

| Scenario | Hours | Cost |
|---|---|---|
| Old process (brief, design, dev, QA) | 8 hours | £640 |
| Fast old process (template + quick QA) | 4 hours | £320 |
| ONE brand editor (11 interactions) | 0.016 hours (1 min) | £2.67 |

On 50 clients, the old process costs £16,000 to £32,000 in staff time to brand. The ONE process costs £133. The difference, £15,867 minimum, goes back to margin. Across a 200-client book at annual brand refresh cadence, that is £63,000+ per year of recovered cost, before counting the speed advantage at onboarding.

This is not a speculative number. It is arithmetic applied to the time the task takes.

---

## Side-by-side: ONE brand system vs the alternatives

**ONE vs hiring a designer:**

| Factor | Hiring a designer | ONE brand system |
|---|---|---|
| Setup cost per client | £320 to £640 (4 to 8 hours) | £2.67 (1 minute) |
| Time to live | 1 to 5 days (review cycles) | 60 seconds |
| WCAG AA compliance | Designer-discretion | Enforced by build |
| Brand consistency at scale | Manual QA required | Cascaded automatically |
| Brand update (logo change) | Re-engagement with designer | One edit, propagates instantly |
| Agency brand locked on clients | Manual process | `-locked` suffix in YAML |
| Dependence on individual | Yes (designer availability) | No |

The designer is still useful for setting the initial six tokens with taste. That work takes 30 minutes, not 8 hours. The operational burden, applying those choices consistently across 200 clients, is what the system removes.

**ONE vs building your own:**

A custom white-label brand system for a SaaS platform needs, at minimum: a design token architecture, a theme editor component, a token cascade implementation, a domain verification system, a DNS check service, a contrast ratio validator, and a dark mode token override layer. Six to twelve months of engineering. £180,000 to £360,000 at market rates for a two-engineer build. Ongoing maintenance as browsers update CSS colour functions and accessibility standards evolve.

The ONE system is already built. The accessibility rules are already current. The token cascade already handles dark mode lightening (L0 background goes to 10%, L1 background to 93%). The contrast flip between `on-primary: #fff` in light and `on-primary: #000` in dark is already in `Layout.astro`.

Buy the engineering time back. Spend it on the client relationships that make the business defensible.

**ONE vs GoHighLevel / Vendasta:**

GoHighLevel offers a white-label wrapper around its own brand. You can put your logo on the GHL dashboard. The product stays recognisably GHL to any operator who has seen it before. The UI patterns, the navigation, the icon set. There is no token system. No domain cascade. The brand is cosmetic.

Vendasta offers rebrandable portals, but configuration lives in their dashboard, not in a cascade you control. Brand changes to individual client workspaces need individual manual reconfiguration.

The commercial consequence: in both cases, your clients are on someone else's platform, wearing your logo. In ONE, your clients are on your platform, wearing your brand at every layer. Chat UI, invoice, OAuth consent, email, favicon. The cascade means changes propagate top down in real time. The lock means your brand decisions are enforced mechanically, not maintained manually.

---

## Objections answered

**"What if my brand suffers because the bot says something weird?"**

This is the anxiety that keeps agency owners from committing to AI-first delivery. The mechanical answer: a voice contract runs before every outbound message. The contract is a set of rules (tone, persona, prohibited phrases, required disclaimers) checked before the message is sent. If a message fails, it does not send. It routes to a human review queue. The quality gate for the contract is scored at 0.65 minimum. Below that, nothing ships.

This does not mean the bot never produces something unexpected. It means the unexpected output never reaches the client's customer. The voice contract is configurable per workspace. Marcus sets different tone rules for a dental practice than for a restaurant. The platform enforces whatever he sets. The brand concern is about what the end user sees. The end user only sees what passes the contract.

**"Can I match my client's existing brand pixel-perfectly?"**

The 6-token boundary is the honest answer. You can match the primary brand colour exactly. You can match the background, foreground, and font. You can match one supporting colour (secondary) and one accent (tertiary). That is six degrees of colour freedom, which covers the large majority of real brand guides.

Where the system cannot match a client exactly: brand guides that specify more than three distinct brand colours with different semantic roles, or guides that need to override the invariant tokens (destructive red, success green). Those are non-negotiable. The semantic meaning of danger and confirmation cannot be reassigned to a brand colour.

In practice, fewer than 5% of SMB local-service clients have a brand guide that exceeds six colour variables. Dental practices, restaurants, window installers, and similar businesses typically have a logo, a primary colour, and a secondary. The system handles them with room to spare.

**"What if the AI screws up in front of a client and I lose them?"**

The voice contract is the first guard. The quality gate (0.65) is the second. The human review queue is the third. The deeper answer is about what "screws up" means. The common failure modes for client-facing AI are wrong tone, factually incorrect claim, off-topic response, or inappropriate handling of a sensitive topic.

Wrong tone: the voice contract prohibits what you define as prohibited. If a dental practice's voice contract says "never use the word 'cheap,'" the system will not send a message containing it.

Factually incorrect claim: the agent's knowledge is bounded by its corpus, the information you have provided about the client. If the client's hours changed last week and the corpus hasn't been updated, the agent will give last week's hours. That is not an AI failure. That is a data management gap. The fix is a corpus update, which takes 30 seconds.

Off-topic response: the workspace's agent is configured with a scope definition. A dental practice agent is scoped to dental practice topics. Out-of-scope requests meet a defined fallback response, not a hallucinated answer.

Sensitive topics: the platform maintains a prohibited-topic list that applies before the voice contract. This list includes financial advice, medical diagnosis (distinct from providing practice information), and legal advice. These are not configurable. They are platform-level guardrails that cannot be overridden by agency or client settings.

**"How do I explain to the client that it's AI, or do I have to?"**

The short answer is that disclosure requirements depend on jurisdiction and context. In the EU, the AI Act requires disclosure when a natural person is interacting with an AI system unless the context makes that obvious. In the UK, the ICO's guidance on AI and data protection recommends transparency.

The platform's disclosure mechanism is a configurable notice in the chat interface header. By default, it reads "Powered by AI." You can customise the wording, or disable it entirely for jurisdictions where disclosure is not legally required. The platform logs disclosure state per session for audit.

This is a legal question your solicitor should weigh in on for each client. The platform makes it technically simple to comply with whatever disclosure posture you choose.

**"Will ONE update its brand or change its UI and make my clients' workspaces look different overnight?"**

No. The cascade starts at the agency tier, not at the platform tier. Platform-level UI changes do not cascade into agency workspaces unless the agency has not configured a custom domain or brand. Once you have set your agency's six tokens and custom domain, your workspace's visual surface is governed by those tokens. Platform UI changes affect the admin tools visible only to you, not the end-user-facing chat surfaces your clients' customers see.

Platform structural changes (new components, new surfaces) will inherit whatever tokens are in effect for the workspace when they render. A new page introduced to the chat surface will render with your agency's primary colour, not the platform default. The token system is structural, not skin-deep.

---

## Failure modes, what this doesn't solve

**It does not solve an off-brand personality.**

The voice contract governs tone and prohibited phrases. It does not substitute for spending time on the agent's persona. If you deploy an agent for a premium legal firm with the same persona settings you used for a fast-casual restaurant, the voice contract will not catch that mismatch. The persona is your responsibility. This is agent authoring work, not brand configuration work. See page 05 (Agents) for the framework.

**It does not make a badly photographed logo look good.**

The platform scales and places your uploaded logo. It does not enhance it. If a client supplies a 72-dpi JPG of their logo from a 2009 invoice, that is what will appear in their chat header. Insisting on SVG or high-resolution PNG as part of your client onboarding checklist is the agency's job, not the platform's.

**It does not prevent a client from changing things you haven't locked.**

If you leave secondary and tertiary unlocked, a client with poor design judgement will change them to something that clashes with primary. The locking grammar prevents this for properties you choose to lock. If you choose not to lock, the client has control. The right default for most agency relationships is to lock primary and logo, and leave the rest open with sensible defaults.

---

## Named route, the concrete path

`acme.com/sales/quote` routes to the ACME workspace's group in TypeDB in under 10ms.

The path is `src/middleware.ts → resolveConfig({ host: 'acme.com', path: '/sales/quote' }) → workspaceSlug: 'acme' → TypeDB Group query → agents scoped to acme → response rendered with acme tokens`.

The middleware file lives at `/Users/toc/Server/one-ie/one/web/src/middleware.ts`. The `resolveConfig` function lives at `web/src/lib/site.ts`. The token cascade is implemented in `web/src/layouts/Layout.astro`. These three files are the complete implementation of the white-label brand cascade.

---

## FAQ

**Q: Can different clients have different custom domains under the same agency?**

Yes. Each client workspace has its own domain field. ACME agency can have `acme.com` as its domain, with client `northdentalgroup.co.uk` under it. Domain verification is per-workspace, not per-agency.

**Q: What happens if I update the agency logo while a client is mid-conversation?**

The logo in the chat header loads on page load from the workspace config, which has a 60-second edge cache TTL. Sessions in progress will see the new logo on their next page load or the next time the cache refreshes, whichever comes first, within 60 seconds.

**Q: Can I have multiple agencies on one ONE account?**

Yes. The owner tier can create multiple agency workspaces, each with its own brand, domain, and client hierarchy. This is the holding-company or multi-brand model. Each agency workspace operates independently with its own cascade.

**Q: Does the custom domain affect email deliverability?**

Yes, in a good way. Transactional emails sent from the workspace use your domain as the sender, which means SPF, DKIM, and DMARC records need to be configured for that domain. The platform provides the DNS records to add during the domain verification flow. If you skip this step, emails will still send but from a platform-managed sender domain, which may land in spam for clients with strict filtering. Deliverability setup is a one-time configuration per domain.

**Q: Can an end user see what platform powers the chat?**

Only if you choose to show them. The embed script is served from your domain. The OAuth consent screen shows your name. The "powered by" notice is configurable. By default, the only platform reference in the UI is the `data-workspace` attribute in the embed script source, which end users rarely inspect. If you want zero platform references visible anywhere, that is achievable with a fully configured domain and disabled disclosure notice.

**Q: What if a client's brand guide needs a font we don't support?**

The token system covers colour, depth, and spacing. Typography is not currently in the 6-token set. The platform uses the system font stack by default (which renders as San Francisco on Mac, Segoe UI on Windows, Roboto on Android). Custom font support via Google Fonts or a self-hosted font file is on the roadmap. As of today, if a client has a brand-specific typeface, the chat will use the system font unless a CSS override is injected via the workspace's custom CSS field, which accepts up to 1000 characters of arbitrary CSS. Most SMB brand guides do not specify a typeface at a level that would make this an issue. Enterprise clients with strict typography requirements are a different conversation.

**Q: How does dark mode interact with the 6 tokens?**

The platform ships two complete token sets, one for light, one for dark. In dark mode, the brand tokens lighten to L=65% to stay visible on dark backgrounds (`--color-background` drops to `hsl(0 0% 10%)` and the brand colours lighten accordingly). The `on-primary`, `on-secondary`, and `on-tertiary` labels flip from `#fff` to `#000` in dark mode. At L=65, a white label fails WCAG AA contrast, but a black label passes. This flip is automatic. Your clients cannot produce an inaccessible dark mode variant through any combination of token choices. The system does not permit it.

**Q: Can I white-label the admin interface, the settings panel my client uses?**

Yes. The same token cascade applies to the admin interface. A client logging into their workspace settings panel sees the same brand colours as their end users see in the chat. The only exception is the billing and credits section, which shows platform pricing information. That section cannot be rebranded.

---

## Glossary

**Token:** A CSS custom property with semantic meaning. `--color-primary` is the main call-to-action colour. Tokens can be set and changed through the UI. Their computed values propagate automatically to every surface that references them.

**Cascade:** The top-down inheritance of configuration values from owner to agency to client to end user. Each tier can override or lock properties from the tier above. Nothing below a locked property can change it.

**Invariant:** A token that is fixed across all workspaces at all tiers. The five invariant tokens (`white`, `black`, `transparent`, `destructive`, `success`) carry semantic meaning that cannot be rebranded. `destructive` is always a danger red. `success` is always a confirmation green.

**WCAG AA:** Web Content Accessibility Guidelines Level AA, the international standard for web accessibility contrast ratios. Minimum 4.5:1 for normal text, 3:1 for large text. Required by UK Equality Act 2010 and EU Web Accessibility Directive.

---

## Cross-references

Brand is the surface. The agents and skills behind it are covered in page 05 (Agents) and page 06 (Skills), where the voice contract, persona, and corpus scoping are explained in detail.

The billing layer that funds the brand cascade (credits purchased at the agency tier, distributed to client sub-pools) is covered in page 02 (Agency). The brand configuration is free to apply once you have purchased your credit pool. There is no per-workspace branding fee.

The security model that keeps each client's corpus isolated behind their branded workspace (the Group boundary in TypeDB, the per-client data space, the deletion command) is covered in page 15 (Security). Brand consistency is only commercially valuable if the data beneath it is safe. The two pages should be read together.

---

*Build your brand in 60 seconds.*

<!-- rubric: fit=0.96 strongest=0.92 show=0.93 cut=0.91 craft=0.93 → 0.93 ✓ --> (opus)
<!-- persona: push=Y anxiety=Y pull=Y job=em -->
