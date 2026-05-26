---
mode: lean
lifecycle: construction
classifier:
  spec_locked: true
  variance_known: true
  exit_scalar: "every transactional email triggered by the backend has a defined subject, body, sender, and link target"
  files_known: true
---

# emails.md — Transactional email templates

Every backend endpoint that sends an email is listed here with its trigger,
sender address, subject, body shape, and CTA. If a feature ships and isn't
in this table, the email never goes out — or worse, goes out with default
copy nobody owns.

---

## 1. Sender policy

| From address | When |
|--------------|------|
| `noreply@one.ie` | platform-default (no parent_slug or platform-level events) |
| `noreply@<domain>` | when workspace has a verified custom domain (Pro+) |
| `noreply@<agency-domain>` | child workspace emails when agency has Pro+ + branding-lock (cascade.md §3) |

Reply-to: always the workspace's owner email if `owners.email IS NOT NULL`,
else discarded.

DKIM/SPF: handled by Cloudflare Email Routing — no per-domain config needed.
Custom domains require DNS TXT records in `/api/domain` verify flow.

---

## 2. The 7 templates

### E1. Magic-link recovery

| Field | Value |
|-------|-------|
| Trigger | `POST /api/recover { slug, email }` |
| Backend | `web/src/pages/api/recover.ts` |
| To | submitted email |
| Subject | `Re-enrol your Touch ID for {slug}` |
| CTA URL | `https://{slug}.one.ie/recover?token={one-time-token}` |
| TTL | 1h |
| UI surface | `/recover` (`ui.md §3 A6`) |

```
Hi,

Someone (hopefully you) asked to re-enrol Touch ID for the {slug}
workspace.

Click the link below within 1 hour to add a new device:

  [Re-enrol Touch ID →]

If you didn't request this, ignore this email — your workspace stays safe.

— The {brand} team
```

### E2. Invite to child workspace

| Field | Value |
|-------|-------|
| Trigger | `POST /api/provision?action=create-invite` |
| Backend | (lifecycles-ui §4.2) |
| To | invited email |
| Subject | `{agency-name} invited you to {child-slug}` |
| CTA URL | `https://{agency-domain}/u/{child-slug}?invite={token}` |
| TTL | 7 days |
| UI surface | `/u/[slug]?invite=...` redemption (cascade.md §5) |

```
Hi,

{agency-name} has set up a workspace for you on ONE.

  [Open {child-slug} →]

You'll be asked for Touch ID once. After that, you own the workspace —
your keys stay on your device.

— Powered by {agency-name}
```

### E3. Payment failed

| Field | Value |
|-------|-------|
| Trigger | Stripe webhook → `owners.payment_status = 'failed'` |
| Backend | `web/src/pages/api/billing.ts` (action=webhook) |
| To | owner.email |
| Subject | `Your {brand} payment failed — update card` |
| CTA URL | Stripe customer portal redirect (via `/api/billing?action=portal`) |
| Repeat | Daily until resolved or after 7 days drops to Free |
| UI surface | `<PaymentFailureBanner>` global (lifecycles-ui §7.1) |

```
Hi,

Your last payment for {plan} on {brand} didn't go through.

  [Update card →]

If we don't hear back by {grace_until}, your workspace drops to the
Free tier. Your data stays — just the paid features pause.

— {brand} billing
```

### E4. Payment receipt

| Field | Value |
|-------|-------|
| Trigger | x402 payment success or Stripe invoice paid |
| Backend | webhook → notification + email |
| To | payer.email |
| Subject | `Payment receipt — ${amount} for {skill\|subscription}` |
| CTA URL | `https://{domain}/wallet/transactions?id={tx_id}` |
| UI surface | `/wallet` (`ui.md §3 B11`) |

```
Hi,

You paid ${amount} for {description}.

  ┌─ Receipt ────────────────────┐
  │ Date:    {ts}                 │
  │ Amount:  ${amount}            │
  │ To:      {creator}            │
  │ Splits:  creator ${creator}   │
  │          platform ${platform} │
  │          x402     ${protocol} │
  └──────────────────────────────┘

  [View in wallet →]

— {brand}
```

### E5. Agent eval failure

| Field | Value |
|-------|-------|
| Trigger | `/api/eval` returns rubric < 0.65 on a deploy gate |
| Backend | `web/src/pages/api/agents/[id]/deploy.ts` |
| To | agent owner.email |
| Subject | `{agent-name} eval failed — deploy blocked` |
| CTA URL | `https://{domain}/u/{slug}/agents/{name}?tab=eval` |
| UI surface | `<NotificationItem>` + agent-detail Eval tab (`ui.md §3 C12`) |

```
Hi,

{agent-name} couldn't be deployed — the eval rubric dropped below 0.65.

  ┌─ Rubric ─────────────────────┐
  │ security    {sec}             │
  │ stability   {sta}             │
  │ simplicity  {sim}             │
  │ speed       {spd}             │
  │ composite   {comp}  {pass/fail}│
  └──────────────────────────────┘

  [Open Eval tab →]

The previous version is still live. Fix the prompt and re-eval to deploy.

— {brand}
```

### E6. Invite redeemed (notify the inviter)

| Field | Value |
|-------|-------|
| Trigger | `POST /api/provision?action=redeem-invite` succeeds |
| To | inviting agency owner.email |
| Subject | `{client-email} accepted your invite to {child-slug}` |
| CTA URL | `https://{agency-domain}/u/{agency-slug}/settings?section=clients` |
| UI surface | `<InboxBell>` + `/notifications` (`ui.md §3 B10`) |

```
Hi,

{client-email} just accepted your invite. {child-slug} is now live.

  [See in Clients →]

— {brand}
```

### E7. Workspace deleted (confirmation)

| Field | Value |
|-------|-------|
| Trigger | `POST /api/settings?action=delete` (W9E1) |
| To | deleted owner.email |
| Subject | `{slug} has been deleted` |
| CTA URL | none (workspace gone) |
| UI surface | none — final confirmation |

```
Hi,

You deleted {slug} on {ts}.

All chats, agents, skills, and files have been purged from R2 and D1.
This action is irreversible.

If you didn't do this, your workspace was compromised. Contact
support@one.ie immediately — we keep audit logs for 90 days.

— ONE
```

---

## 3. Cascade rules (cascade.md §3)

For child workspaces, the email From/footer respects the agency cascade:

| Child plan | Agency lock | From address | Footer attribution |
|-----------|-------------|--------------|-------------------|
| Free | yes | `noreply@<agency-domain>` | "Powered by ACME" + "Powered by ONE" |
| Free | no | `noreply@one.ie` | "Powered by ONE" only |
| Pro+ | yes | `noreply@<agency-domain>` | "Powered by ACME" only |
| Pro+ | no | `noreply@<own-domain>` | (none — child is the brand) |

The child can override their own footer in `BrandingSettings` (lifecycles-ui §5.3)
unless agency has `branding_lock = true`.

---

## 4. Implementation surface

All emails sent via Cloudflare Email Workers (`web/src/lib/email.ts` — to be created in W8 or as separate cycle).

```typescript
// web/src/lib/email.ts (sketch)
export async function sendTemplate(
  template: 'E1'|'E2'|'E3'|'E4'|'E5'|'E6'|'E7',
  to: string,
  vars: Record<string, string>,
  ctx: { brand: string, fromDomain: string }
): Promise<void>
```

Each template lives in `web/src/emails/<id>.tsx` (React Email or plain
template literal — TBD by first email-shipping cycle).

---

## 5. What's NOT in scope

- Marketing emails (newsletters, product updates) — separate system
- Admin alerts (CF Worker errors, DB pool exhaustion) — observability tooling
- SMS / push notifications — future surface

Per `.claude/rules/ui.md` no `emitClick` from emails (they're not in the UI),
but every email click that lands back on a UI page emits as normal.

---

## 6. Cross-references

- `cascade.md §3` — branding cascade rules (drives From and footer)
- `lifecycles-ui.md §4.2` — invite flow (E2)
- `lifecycles-ui.md §7.1` — PaymentFailureBanner (E3)
- `ui.md §3 A6` — `/recover` page (E1)
- `ui.md §3 B11` — `/wallet` (E4 receipt CTA)
- `ui.md §3 C12` — agent eval (E5 CTA)
- `web/src/pages/api/recover.ts` — sends E1
- `web/src/pages/api/billing.ts` — sends E3, E4
- `web/src/pages/api/provision.ts` — sends E2, E6

---

*Seven templates. One sender policy. Cascade-aware. Per-template owner so
nothing ships with placeholder copy.*
