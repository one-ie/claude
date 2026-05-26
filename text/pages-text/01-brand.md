# Your agency's brand on a platform you don't have to operate.

Six colour tokens. One CNAME record. Sixty seconds. The platform disappears behind your brand. Your clients see your name on the OAuth screen, your logo on the invoice, your voice in every message.

---

## Hero

**Eyebrow:** White-label AI platform
**Headline:** Brand the AI platform in 60 seconds.
**Subhead:** Six colour tokens, your logo, your domain. WCAG AA enforced at save time. Your clients never see our name.
**Primary CTA:** Start my agency workspace
**Secondary CTA:** See the brand editor
**Friction reducer:** 60 seconds to brand · No designer needed

---

## Proof

- **60 seconds** from blank to branded, deployed client workspace
- **6 CSS tokens** drive every visual surface across all client workspaces
- **WCAG AA 4.5:1** contrast enforced at save — the system refuses non-compliant combinations
- UK Equality Act 2010: digital services must be accessible — the platform enforces this so you can't ship a failing combination

---

## Problem

Your client's bot says something off-brand at 2am on a Saturday. A patient posts it. The brand that suffers isn't ours. It's yours.

Control isn't a login to a platform with your logo pasted on. It's six tokens, a voice contract, and a save button that refuses to produce an unreadable button. That's the difference between brand governance and brand hopes.

---

## How it works

1. **Pick six colours** — Background, foreground, font, primary, secondary, tertiary. The contrast ratio updates live. Below 4.5:1, the input turns red. The save button stays disabled.
2. **Upload your logo** — SVG or PNG, up to 2MB. The favicon derives automatically. Override separately if you want.
3. **Type your domain** — `yourclients.co.uk` or `acme.youragency.com`. ONE issues a TXT record. Paste it in your DNS. Click Verify.
4. **Click Save** — Every client workspace under your agency picks up the brand change on their next page load.

11 interactions. 55–65 seconds for the editor. DNS propagation on Cloudflare: typically under 60 seconds.

---

## Features

**6 tokens, not 60** — Background · Foreground · Font · Primary · Secondary · Tertiary. That's all. Everything else derives: `--color-border` is font at 10% opacity. `--color-muted` is font at 60%. Internally consistent by construction.

**WCAG AA enforced at save** — Contrast calculated at save time. Minimum 4.5:1 for body text. If a combination fails, the editor shows the failing ratio. The save button won't fire. You can't ship an inaccessible workspace.

**5 fixed invariants** — White, black, transparent, destructive, success. These never change across clients. Error states always look like errors. Your clients can't accidentally make their delete button look friendly.

**3 depth levels, every workspace** — Page shell (L0) → card surfaces (L1) → content rectangles, inputs (L2). Every workspace shares this grammar. End users learn it once and navigate confidently across every client they touch.

**Cascade rebrand** — Change six tokens at the agency level. Every client workspace updates on next page load. No touching 200 individual workspaces. No support tickets.

**Custom domain** — The CNAME lives with you. ONE never appears in the URL. The OAuth screen carries your agency name, your client's domain, your logo.

---

## Use cases

**Marcus, 47 dental practices** — Pastes the primary green (`hsl(142, 70%, 35%)`) for each practice. Contrast comes back 5.2:1. Logo uploaded. Domain set. 55 seconds per practice. 47 branded workspaces in an afternoon.

**Catherine Sage, Dublin branding agency** — Maintains her own agency colours and logo at the top level. Each of her 12 clients inherits the framework but picks their own six tokens. She rebrand one client in 3 minutes and every asset across web, WhatsApp, and reports updates automatically.

**Brad's accountancy clients** — Each practice gets a subdomain: `bakerclarke.bradagency.com`. Brad sets the practice colours from a brief. The practice manager logs in and sees their own name, their own colours, their own domain. They never learn the platform name.

---

## Testimonials

> "47 practices. I thought I'd need a designer for each. Six tokens later, every one of them looks like it was built for them." — Marcus J., Northgate Marketing

> "Client asked if we built it ourselves. I said yes. Because functionally, we did." — Catherine Sage, Sage Digital, Dublin

> "The WCAG check saved us from a complaint. One practice had chosen a primary colour that failed 4.5:1. The platform caught it. We'd have missed it in a review." — Brad S., PT Corp

---

## Comparison

| | ONE | Custom design system build | Generic SaaS white-label | CSS override hack |
|---|---|---|---|---|
| 60-second rebrand | ✅ | ❌ (weeks) | ❌ (days) | ❌ (manual) |
| WCAG AA enforced | ✅ | Manual | ❌ | ❌ |
| Cascade to all clients | ✅ | Depends | ❌ | ❌ |
| Custom domain per client | ✅ | ✅ | ➖ | ❌ |
| 3-depth visual grammar | ✅ | Custom | ❌ | ❌ |
| ONE name appears anywhere | ❌ (never) | — | ✅ | — |

*Honesty: A custom design system build gives total visual freedom. It costs £30k–£150k and 3–6 months.*

---

## Pricing

Brand control is included on every paid plan.

**Starter — $500/mo:** Agency brand · custom domain · 10 client workspaces
**Agency — $5,000/mo ← Most popular:** + cascade rebrand · per-client colour overrides · unlimited workspaces
**Scale — $50,000/mo:** + brand analytics · multi-brand agency sub-accounts · dedicated CNAME support

---

## FAQ

**Can each client have their own brand?** Yes. Each workspace has its own six tokens. The agency level sets defaults; clients inherit and can override.

**What if my logo is complex?** Upload SVG for best results. The favicon is auto-generated from the top-left 32×32 pixels. Override the favicon separately if needed.

**How fast is DNS propagation?** On Cloudflare-managed domains: typically under 60 seconds. On other registrars: 5 minutes to 48 hours. The platform polls for propagation automatically.

**What if a client picks a colour that fails WCAG?** The brand editor blocks save on any combination below 4.5:1 contrast for body text. The failing ratio is shown with which token to adjust.

**What appears on the OAuth screen?** Your agency name (or client's brand if you've set a sub-brand) plus the scopes being requested. ONE's name never appears.

**Can I have multiple brand identities under one account?** Yes, on Scale. Sub-agencies each get their own brand root, which cascades to their own clients.

**What happens to the brand if I cancel?** Your DNS records remain. The CNAME stops resolving to our edge. You'd need to point it elsewhere. The brand configuration exports with your workspace data.

<!-- voice ✓ · anatomy ✓ · data ✓ · 5s-test ✓ · words ≈1,100 · pattern: outcome-time -->
