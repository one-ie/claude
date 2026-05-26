# auth-ui — one surface, every door

**Owner:** tony@one.ie
**Surface:** `/signin` and `/signup` render the same component; URLs kept for SEO and deep-links, but the UI is mode-agnostic.
**Implementation root:** `one.ie/src/components/auth/`, `one.ie/src/lib/auth.ts`
**Sibling specs:** [`passkeys.md`](passkeys.md) (PRF/wallet lifecycle behind the door) · [`mac.md`](mac.md) (biometric root) · [`secrets.md`](secrets.md) (Resend already wired) · [`wallet.md`](wallet.md) (post-auth flow) · [`simple.md`](simple.md) ("arrive → wallet exists")

> The user never picks an auth method. They pick the door that fits the moment. The surface ranks methods by what the device can do — passkey-equipped device gets the big button; everyone else sees Google/wallet/email at equal weight.

---

## §0 — Classifier

| Prior | Verdict |
| --- | --- |
| Spec locked | ✅ Better Auth plugins (`emailAndPassword`, `passkeyWebauthn`, `suiWallet`) already wired; `magicLink` adds; Resend already configured (`src/lib/notify/email.ts`) |
| Variance known | ✅ One component, five doors, one optional inline password reveal |
| Exit scalar | ✅ Passkey return ≤1.5s · new email magic-link ≤30s round-trip · Google ≤8s · all six §10 verify rows green |
| Files known | ✅ 1 server edit + 1 component (replaces existing panel) + 5 small door components. Recon below. |

**`mode: lean`** · **`lifecycle: construction`**
Pheromone tag on close: `mode:lean lifecycle:construction surface:auth-ui`

---

## §1 — The shape (one frame, every door)

```
┌──────────────────────────────────────────────────────────┐
│  Sign in to ONE          (or "Create your identity"      │
│                           on /signup — copy only diff)   │
│                                                          │
│   ╔════════════════════════════════════════════════╗    │  ← only rendered if
│   ║  ✦  Continue with Touch ID / Face ID           ║    │    PublicKeyCredential
│   ╚════════════════════════════════════════════════╝    │    + conditional UI
│   No password. Your biometric never leaves this device.  │    available
│                                                          │
│   ┌────────────────────┐  ┌────────────────────┐        │  ← equal weight,
│   │  G  Google         │  │  ◈  Sui wallet     │        │    side-by-side
│   └────────────────────┘  └────────────────────┘        │
│                                                          │
│   ─────────── or use email ───────────                   │
│                                                          │
│   ┌────────────────────────────────────────────────┐    │
│   │  you@example.com                               │    │  ← single input,
│   └────────────────────────────────────────────────┘    │    no password
│   ┌────────────────────────────────────────────────┐    │    field yet
│   │                  Continue →                    │    │
│   └────────────────────────────────────────────────┘    │
│                                                          │
│   ▸ More ways to sign in                                 │  ← collapsed
│     · Continue with zkLogin (Sui address from Google)    │
│     · Restore from recovery phrase                       │
└──────────────────────────────────────────────────────────┘
```

**Width:** `max-w-md`. **Vertical rhythm:** every block separated by `mt-6`. Background, brand panel, gradient, KPIs all unchanged from `signin.astro` / `signup.astro`.

---

## §2 — How email collapses signin and signup (without enumerating users)

The email input is the only door that traditionally needs a mode toggle. We replace the toggle with **a single non-disclosing response** so the user types their email once and the app picks the right path *without telling the world whether the email is registered*.

```
POST /api/auth/email/continue { email }
  ↓
  Always:
    1. Send a magic link (idempotent — Better Auth dedupes).
    2. Respond { sent: true, hasPassword: bool } where `hasPassword` is true
       only if a session cookie or recent CSRF-bound state proves the caller
       already has a credential reference (i.e., they're on a "use password
       instead" return path). For unauthenticated callers, `hasPassword` is
       always omitted — every email gets the inbox state.
  ↓
  Default UI:    "We sent you a link to <email>"
  Optional CTA:  "Have a password? Use it instead" → expands password field
                 (which then submits to /sign-in/email — wrong password reveals
                 nothing because the user opted into that path)
```

This kills the enumeration channel: an attacker probing emails sees the same `{ sent: true }` and the same UI for every address. Real users get the inbox state; users who *know* they have a password click "Use password instead" and try it. Better Auth's `/sign-in/email` returns a generic "invalid credentials" — which is fine because the user already self-disclosed they expect a password.

The user never sees "sign in vs sign up." They type email, click Continue, get the inbox panel — and have an inline escape hatch if they remember a password.

After the link click, Better Auth `magicLink.verify` mints a session and the **session-create hook** in `auth.ts` (T2) calls `ensureHumanUnit()` to create the `human:{slug}` unit + personal group. On first land the user can optionally set a password under `/settings/security` — never required.

**Why this is the elegance trick:** every email gets the same response, every user gets the same UI, and the password path is opt-in by user knowledge, not server disclosure.

---

## §2a — Binding to the existing ephemeral wallet (the gap that bites if missed)

By the time a user reaches `/signin` or `/signup`, `passkeys.md` State 1→2 has *already* run: there's an ephemeral Ed25519 seed in IndexedDB, and the user may have made transactions with it. **Every door in §3 must bind that seed, not destroy it.**

Bind rules per door:

| Door | What happens to the existing IDB seed |
| --- | --- |
| **Passkey (register-anonymous)** | The PRF output wraps the **existing seed** (envelope-encrypt in place per `passkeys.md` State 3). New seed is never generated. `createAccountWithPasskey()` already supports this — verify call site passes the existing seed bytes; if it doesn't today, it must after this plan. |
| **Passkey (authenticate, returning device)** | OS picks the resident credential. PRF unwraps the *server-stored* seed envelope. If an unbound IDB seed exists, prompt: "Keep this session's wallet, or restore the passkey-bound wallet?" (default: restore — passkey is the authoritative root). |
| **Google OAuth** | Better Auth creates the user. We attach the IDB seed to the user record as an **opaque encrypted blob** (the existing State-2 seed AES-wrapped under a Google-OAuth-derived KEK is **not safe** — Google can't sign — so instead we store the seed as the "pending" State-2 ciphertext and prompt the user on first land to enroll a passkey to wrap it properly). Until the passkey enrollment, the seed lives in IDB only. **No silent destruction.** |
| **Sui wallet** | The IDB seed is *not* the user's wallet — the dapp-kit wallet is. Offer: "Sweep this session's funds to your wallet?" before proceeding. Default: yes, then discard the IDB seed. |
| **Magic link (new email)** | Same as Google OAuth — seed stays in IDB; first-land surface prompts passkey enrollment. |
| **Magic link / password (existing email)** | Pull the user's server-stored seed envelope. If IDB has a different unbound seed, prompt: "You used a different wallet on this device — sweep funds, then restore your account wallet." |

**The invariant:** *no auth flow ever silently overwrites an IDB seed*. Either the seed is bound (passkey path), swept (wallet path), or kept pending with a clear next-step prompt (Google / magic-link path). This adds T2.5 in §6 — a `useExistingSeed()` hook used by every door component.

This subsection cites `passkeys.md` State 2→3 as the authority for *how* PRF wraps a seed; auth-ui only owns *when* and *which UI* prompts the bind.

---

## §3 — Door table

| Door | Render condition | Server endpoint | Client | New behavior |
| --- | --- | --- | --- | --- |
| **Passkey** | `window.PublicKeyCredential && PublicKeyCredential.isConditionalMediationAvailable()` | `/api/auth/passkey-webauthn/{authenticate,register-anonymous}/{options,}` | `signInWithPasskey()` first; if `NotAllowedError` and intent is signup, fall through to `createAccountWithPasskey()` (`src/components/u/lib/vault/passkey-cloud.ts`) | one button covers both modes — discoverable credentials make new vs returning identical from the user's side |
| **Google OAuth** | always | `/api/auth/sign-in/social` (Better Auth) | `authClient.signIn.social({ provider: "google", callbackURL: redirect })` | new in this plan — `socialProviders.google` added to `auth.ts` (T1) |
| **Sui wallet** | always | `/api/auth/wallet/*` (existing `suiWallet` plugin) | existing `WalletSignIn` | unchanged, restyled to match equal-weight row |
| **Email — magic link** | always | `/api/auth/magic-link/{send,verify}` (Better Auth `magicLink` plugin) | `authClient.signIn.magicLink({ email, callbackURL })` | new in this plan — uses `sendEmail()` from `src/lib/notify/email.ts` (Resend already wired) |
| **Email — password (opt-in)** | only when user clicks "Have a password? Use it instead" on the inbox panel | `/api/auth/sign-in/email` | `authClient.signIn.email({ email, password })` | unchanged, never shown until user self-discloses they expect a password |
| **zkLogin** | always (under `<details>` "More ways") | `/api/auth/zklogin/start` | redirect | demoted |
| **Lost your device? — Restore wallet** | always (under `<details>` "More ways") | none — pure client flow | redirect to `/u/restore` | **This is not a sign-in door.** Typing 12 BIP39 words re-derives the PRF, then routes the user to passkey re-enroll on the new device per `passkeys.md` State 5. Framed as recovery, not auth. |

Conditional autofill (`mediation: 'conditional'`) is set on the email input so the OS can offer a saved passkey directly into the field — that's the "elegance you can feel": the user clicks the email field and the OS already proposes Touch ID, no separate button press.

---

## §4 — Components

```
src/components/auth/
  AuthSurface.tsx            ← NEW. The whole frame above. Replaces SignInWithAnything in CryptoAuthPanel.
  PasskeyButton.tsx          ← NEW. Headline CTA. Auto-hides without WebAuthn.
  GoogleButton.tsx           ← NEW. Better Auth socialProviders.google.
  WalletSignIn.tsx           ← EXISTING. Restyled token only.
  EmailContinueForm.tsx      ← NEW. Single input → POST /email/continue → expands inline.
  EmailContinueResolved.tsx  ← NEW. Renders one of: password field | "check inbox" | error.
  MoreWaysDisclosure.tsx     ← NEW. <details> wrapping zkLogin + recovery phrase.
```

`CryptoAuthPanel` becomes a 30-line shell: heading, subline, `<AuthSurface mode={mode} redirect={redirect} />`, footer copy. Existing `signin.astro` and `signup.astro` are untouched.

`SignInWithAnything.tsx` stays for now (verify with grep there are no other callers; delete in a follow-up).

---

## §5 — Server changes to `src/lib/auth.ts`

```ts
import { magicLink } from 'better-auth/plugins'
import { sendEmail } from '@/lib/notify/email'
import { ensureHumanUnit } from '@/lib/human-unit'

// inside betterAuth({...}):
socialProviders: {
  google: {
    clientId: import.meta.env.GOOGLE_CLIENT_ID,
    clientSecret:
      (globalThis as any).GOOGLE_CLIENT_SECRET ||
      import.meta.env.GOOGLE_CLIENT_SECRET,
  },
},

// Trust same-email merging from any door that proves email ownership.
// magic-link click and Google's verified email both qualify; sui-wallet was
// already trusted; password accounts auto-link only after email verification.
account: {
  accountLinking: {
    enabled: true,
    trustedProviders: ['sui-wallet', 'google', 'magic-link'],
  },
},

// Single source of truth for "auth event → human:{slug} unit + personal group".
// Every door (passkey / google / magic-link / password / wallet) routes through
// session.create, so this fires exactly once per new session regardless of door.
databaseHooks: {
  session: {
    create: {
      after: async (session) => {
        const user = await auth.api.getUser?.({ userId: session.userId })
        if (user) await ensureHumanUnit(session.userId, user)
      },
    },
  },
},

plugins: [
  bearer(),
  suiWallet({ /* unchanged */ }),
  passkeyWebauthn({ /* unchanged */ }),
  magicLink({
    sendMagicLink: async ({ email, url }) => {
      await sendEmail({
        to: email,
        from: import.meta.env.RESEND_FROM_EMAIL || 'tony@one.ie',
        subject: 'Your sign-in link for ONE',
        html: `<p>Click to sign in: <a href="${url}">${url}</a></p>
               <p>This link expires in 5 minutes.</p>`,
      })
    },
    expiresIn: 60 * 5,
  }),
],
```

**`/api/auth/email/continue` endpoint** (`src/pages/api/auth/email/continue.ts`, ~50 lines):

1. Validate email shape.
2. **Always** call `authClient.signIn.magicLink({ email, callbackURL: redirect })` — Better Auth handles new-vs-returning internally.
3. Return `{ sent: true }`. **Never disclose `hasPassword`** in the unauthenticated path.
4. Apply Better Auth's CSRF middleware: import the same origin/cookie check used by built-in routes (or wrap via `auth.handler()` if exposed) — custom routes are *not* CSRF-protected by default.
5. Rate-limit by IP + email (Better Auth's built-in `rateLimit` config or our own `metering.ts`) to prevent magic-link spamming.

**Pre-flight verification** (must pass before T1 ships):

- `src/lib/notify/email.ts:24,62` reads `process.env.RESEND_API_KEY`. The Astro CF Workers runtime exposes secrets via bindings on `globalThis`, not `process.env`. **Verify** the helper falls through to `(globalThis as any).RESEND_API_KEY` and `import.meta.env.RESEND_API_KEY`; if not, add the fallback in T1 (one-line change). Without this, magic-link sends silently fail in prod.
- `src/lib/auth-plugins/passkey-webauthn.ts:921` (`/passkey-webauthn/authenticate/options`) **must** return `allowCredentials: []` (empty array) for unauthenticated callers — that's what tells the OS to surface *any* resident credential for conditional UI. If the plugin filters by user ID it breaks autofill. Verify and fix in T1 if needed.

**Out-of-repo:** add `https://one.ie/api/auth/callback/google`, `https://dev.one.ie/api/auth/callback/google`, `http://localhost:4321/api/auth/callback/google` to the Google Cloud OAuth client. (`.env` already has `GOOGLE_CLIENT_ID` + `GOOGLE_CLIENT_SECRET`.)

---

## §6 — Tasks (lean cycle)

| # | Task | File | Verify |
| --- | --- | --- | --- |
| T1 | Add `socialProviders.google` + `magicLink` plugin + `databaseHooks.session.create.after = ensureHumanUnit` + extend `accountLinking.trustedProviders` to `['sui-wallet','google','magic-link']`. Verify pre-flight: `notify/email.ts` falls through to bindings; passkey-authenticate options return empty `allowCredentials`. | `one.ie/src/lib/auth.ts` (+ tiny patch to `src/lib/notify/email.ts` if needed; + tiny patch to `src/lib/auth-plugins/passkey-webauthn.ts` if needed) | `bun run build` clean; magic-link send works in CF Workers preview; new session via every door creates a `human:{slug}` unit |
| T2 | New endpoint: `POST /api/auth/email/continue` — non-disclosing: always send magic link, always respond `{ sent: true }`, CSRF-protected, rate-limited | `one.ie/src/pages/api/auth/email/continue.ts` (new) | identical response for registered + unregistered emails (tested with timing assertion); rate limit returns 429 after 5/min/IP |
| T2.5 | `useExistingSeed()` hook + bind helpers per §2a — every door component calls it before completing auth; ensures the IDB State-2 seed is wrapped, swept, or kept-pending per door | `one.ie/src/components/auth/useExistingSeed.ts` (new); patches in `passkey-cloud.ts` if `createAccountWithPasskey()` doesn't already accept an existing seed | seed-binding integration test: pre-seed IDB, sign in via each door, assert seed is bound or pending (never silently destroyed) |
| T3 | `PasskeyButton.tsx` — wraps `signInWithPasskey()` then `createAccountWithPasskey()` fallthrough; emits `ui:auth:passkey:{start,success,fail}` | `one.ie/src/components/auth/PasskeyButton.tsx` (new) | new visitor: Touch ID → session; returning: Touch ID → session ≤1.5s |
| T4 | `GoogleButton.tsx` — calls `authClient.signIn.social({ provider: "google", callbackURL: redirect })`; emits `ui:auth:google:start` | `one.ie/src/components/auth/GoogleButton.tsx` (new) | full OAuth round-trip lands signed in at `redirect` |
| T5 | `EmailContinueForm.tsx` + `EmailInboxPanel.tsx` — single input; on submit calls `/email/continue`; renders inbox panel with "Have a password? Use it instead" inline escape hatch (which expands a password field); emits `ui:auth:email:{link,password-opt-in,verify}` | `one.ie/src/components/auth/Email*.tsx` (new) | every email shows inbox panel; password opt-in is user-initiated only; magic-link click signs in and triggers §2a binding |
| T6 | `MoreWaysDisclosure.tsx` — `<details>` containing zkLogin button + **"Lost your device? Restore wallet"** link (routes to `/u/restore`, framed as recovery, not sign-in) | `one.ie/src/components/auth/MoreWaysDisclosure.tsx` (new) | zkLogin functional; restore link routes to `/u/restore` per `passkeys.md` State 5 |
| T7 | `AuthSurface.tsx` — composes T3–T6 + existing `WalletSignIn`; sets conditional WebAuthn mediation on the email input; respects `mode` and `redirect` props | `one.ie/src/components/auth/AuthSurface.tsx` (new) | layout matches §1; OS passkey autofill triggers from email-field focus |
| T8 | Wire `CryptoAuthPanel.tsx` to render `<AuthSurface mode={mode} redirect={redirect} />` instead of `<SignInWithAnything />` | `one.ie/src/components/auth/CryptoAuthPanel.tsx` | `/signin` + `/signup` render new layout, brand panel unchanged |
| T9 | Add Google OAuth redirect URIs in Google Cloud Console (out-of-repo) | manual | Google round-trip green on localhost + dev.one.ie + one.ie |

No edits to `signin.astro` or `signup.astro` — they already pass `mode` and `redirect` into `CryptoAuthPanel`.

---

## §7 — Design-system contract

| Token | Value | Where |
| --- | --- | --- |
| Page bg | `bg-[#0a0a0f]` | unchanged from `signin.astro:30` |
| Card border | `border-white/5` (default) / `border-white/10` (focus) | matches existing |
| Primary CTA (passkey) | `bg-white text-black hover:bg-zinc-100` with violet pulse dot left of label | new, matches existing badge dot at `CryptoAuthPanel:38` |
| Secondary CTAs (Google, wallet) | `bg-white/[0.04] border border-white/10 text-white hover:bg-white/[0.08]` | equal weight row |
| Email input | `bg-white/[0.03] border border-white/10 placeholder:text-zinc-600 text-white focus:border-violet-400/40` | matches design system tokens |
| Continue button | same as secondary CTA, full-width | |
| Divider | `text-[10px] uppercase tracking-[0.18em] text-zinc-600` with `h-px bg-white/5` flanking | matches "Now in the world" label `signin.astro:99` |
| Disclosure trigger | `text-zinc-400 hover:text-white text-xs` with caret | |
| Inline error | `text-rose-400 text-xs` with subtle shake animation on submit | |
| "Check inbox" state | violet-tinted card `bg-violet-500/[0.06] border border-violet-500/20` with envelope icon + email echoed back | |

shadcn primitives: `Button`, `Input`, `Label`. All present in `one.ie/src/components/ui/`. No new shadcn additions.

---

## §8 — Microcopy

```
[heading]    Sign in to ONE                           (signin)
             Create your identity                     (signup)

[passkey]    ✦  Continue with Touch ID / Face ID
[hint]       No password. Your biometric never leaves this device.

[row]        [ G  Google ]   [ ◈  Sui wallet ]

[divider]    ─── or use email ───

[email]      [ you@example.com                               ]
             [ Continue → ]

  → after submit (every email, identical UI):
        ╔══════════════════════════════════════════════╗
        ║  ✉  Check your inbox                         ║
        ║  We sent a link to you@example.com.          ║
        ║  It's good for 5 minutes.                    ║
        ║  [ Resend ]   [ Use a different email ]      ║
        ║                                              ║
        ║  ▸ Have a password? Use it instead           ║   ← user-initiated only
        ╚══════════════════════════════════════════════╝

  → if user clicks "Use it instead":
        [ password ____________________________________ ]
        [ Sign in ]                          Forgot password?

[disclosure]    ▸ More ways to sign in
                  · Continue with zkLogin (Sui address from Google)
                  · Lost your device? — Restore wallet  →  /u/restore
```

Footer (existing copy at `CryptoAuthPanel:48-69`) — three bullets stay; first becomes:
> **Touch ID / Face ID.** Cryptographic signatures prove you. Nothing to type, nothing to leak.

---

## §9 — Conditional WebAuthn — the small detail that sells the elegance

```html
<input
  type="email"
  autocomplete="username webauthn"   ← key bit
  ...
/>
```

```ts
// On AuthSurface mount, if conditional UI is supported:
if (await PublicKeyCredential.isConditionalMediationAvailable?.()) {
  startAuthentication({ ...options, useBrowserAutofill: true })
    .then(authResp => /* sign in via /passkey-webauthn/authenticate */)
    .catch(() => { /* user ignored — no-op */ })
}
```

Effect: on page load, the OS shows saved passkeys directly under the email field as autofill suggestions. The user clicks one → Touch ID → signed in, without ever seeing the email or password journey. **This is what makes "supporting everything" actually feel like one elegant surface.**

---

## §10 — Verify (W4 gate, all ten green)

| # | Check | How | Pass |
| --- | --- | --- | --- |
| 1 | Returning passkey via conditional UI | open `/signin` in profile with saved passkey, click email field, pick credential | session in ≤1.5s, no extra clicks |
| 2 | New visitor passkey signup | clean profile, click primary button | session in ≤5s |
| 3 | Google OAuth round-trip | click Google → consent → callback | redirected to `redirect` param signed in |
| 4 | Email magic-link new user | type unseen email → Continue → check inbox → click link | session minted, `human:{slug}` unit created |
| 5 | Email password opt-in (existing user) | type known-password email → Continue → click "Have a password?" → submit | session minted inline (no redirect) |
| 6 | UI signals | check `/api/signal` log | every door used emits `ui:auth:<door>:{start,success,fail}` |
| 7 | **No enumeration** | hit `/email/continue` with 100 random emails (50 registered, 50 not), record response body + timing | response body identical for all 100; p95 timing delta ≤50ms between groups |
| 8 | **`ensureHumanUnit()` fires for every door** | sign in via passkey / Google / magic-link / password / wallet from a clean DB; query TypeDB for `human:{slug}` | one human unit + one personal group + one chairman role per door, every time |
| 9 | **Account linking** | sign up via magic-link `tony@x.com`, sign out, click Google with same email | one user record, two accounts (magic-link + google), no duplicate `human:{slug}` |
| 10 | **§2a seed binding** | seed IDB before `/signin`, sign in via each door, inspect IDB + server | passkey: seed wrapped in place; google/magic-link: seed kept in IDB with passkey-enrollment prompt on next page; wallet: sweep prompt shown; **never silent destruction** |

`bun run verify` (biome + tsc + vitest) clean. `auth.integration.test.ts` extended with one case per door + one enumeration test + one binding test (7 added total).

Cycle close pheromone: `mark()` `auth-ui:passkey-primary`, `auth-ui:google`, `auth-ui:wallet`, `auth-ui:email-link`, `auth-ui:email-password-optin`, `auth-ui:seed-binding`, `auth-ui:no-enumeration` paths each at chain depth 1.

---

## §13 — Production hardening (block-on for prod)

The §1–§12 plan ships a polished *front-of-house*. §13 covers the *back-of-house* without which a real attack or a real broken flow shows up within a week of prod traffic.

### §13.1 — Open-redirect validation

Every door takes a `redirect` param; `/email/continue` puts it in the magic-link URL. Without an allow-list, attacker phishes via `https://one.ie/signin?redirect=https://evil.com/steal-session`.

**Rule:** all `redirect` and `callbackURL` values pass through `validateRedirect(url)` → returns `url` if same-origin or in `BETTER_AUTH_TRUSTED_ORIGINS`, else returns `/app`. Centralized in `src/lib/auth-redirect.ts` (new). Used by `/email/continue`, every button's `callbackURL`, and `signin.astro` / `signup.astro` SSR.

### §13.2 — Composite rate-limit `(IP, email)`

§5's `5/min/IP` is rotated by any attacker. Add per-email ceiling: **3/hour, 10/day**. Either composite key in `metering.ts:checkRateCeiling` or a thin wrapper in `src/lib/auth-rate-limit.ts`.

Storage **must** be DO-backed or KV-backed (current `metering.ts` may be per-isolate in-memory only — verify in W1 R7). Per-isolate counters don't enforce in CF Workers production.

### §13.3 — Brute-force lockout on `/sign-in/email`

Better Auth's password endpoint is unprotected by §5 plan. After **5 failed attempts** for `(IP, email)` within 15 min, return `429` with `Retry-After: 900`. Failed attempts increment via Better Auth `databaseHooks.account.update.before` hook OR a wrapper endpoint. Reset on successful sign-in.

### §13.4 — Magic-link replay + cross-device click

W1 R4 must explicitly verify Better Auth `magicLink` plugin is **single-use** (`disableSignUp: false, expiresIn: 300, maxConcurrentLinks?`). If not single-use, attacker who reads the inbox replay-attacks indefinitely.

Cross-device decision: **session lands on the device that clicks the link.** Show a one-tap warning on the inbox panel: "Click the link on this device — opening it elsewhere will sign you in there." (Acceptable; alternative is a bounce-with-token-back, more complexity for marginal gain.)

### §13.5 — Error states (per door, per failure mode)

| Door | Failure | UI state |
| --- | --- | --- |
| Passkey | `NotAllowedError` (user cancelled) | inline gray text "Passkey cancelled. Try again or use a different door." |
| Passkey | unsupported / no PRF | button hidden + `aria-live` note "Touch ID/Face ID isn't available on this browser yet." |
| Google | OAuth `access_denied` | "Google sign-in cancelled." inline error |
| Google | network / 5xx | "Couldn't reach Google. Try again." with Retry button |
| Magic-link | expired (`/api/auth/magic-link/verify` returns 410) | full-page state at `/auth/link-expired`: "This link expired. Get a new one." + email input |
| Magic-link | already used (200 with same token) | full-page state at `/auth/link-used`: "This link was already used. If that wasn't you, secure your inbox." + send-fresh button |
| Magic-link | rate-limited | inbox panel shows "Too many requests — wait a few minutes." |
| Password | wrong | "Email or password incorrect. (3 attempts left.)" |
| Password | locked out | "Too many attempts. Try again in 15 minutes, or use a magic link." |
| Wallet | user rejected | "Sign request rejected." |
| Wallet | wrong network / no SUI | "Switch to Sui Mainnet to continue." |
| Email continue | invalid email shape | inline below input, focus stays in field |
| Network (any door) | offline | global toast "You're offline. Reconnect to sign in." |

Every error emits `ui:auth:<door>:fail` per `.claude/rules/ui.md`.

### §13.6 — Loading / pending states

| Door | Pending UI |
| --- | --- |
| Passkey | button → spinner inside button, label "Waiting for biometric…" (≤30s), disabled |
| Google | button → "Redirecting to Google…" + spinner; full-page transition |
| Magic-link send | Continue button → "Sending…" 600ms minimum (UX), then inbox panel |
| Password submit | button → "Signing in…" |
| Wallet | button → "Signing message in wallet…" |

`aria-busy="true"` on the active door; surface stays interactive (other doors clickable but the busy one is locked).

### §13.7 — CF Workers env binding fallback (audit, not just RESEND)

T1 already covers `RESEND_API_KEY`. Add the same `(globalThis as any).X || import.meta.env.X` fallback for **every** runtime secret used: `RESEND_FROM_EMAIL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `BETTER_AUTH_SECRET`, `WALLET_NONCE_SECRET`, `SUI_SESSION_SECRET`, `PASSKEY_CHALLENGE_SECRET`, `BETTER_AUTH_TRUSTED_ORIGINS`. Codify the pattern in `src/lib/env.ts` (new): `runtimeEnv('NAME')` helper. Every auth call site uses it.

### §13.8 — Mobile layout

`AuthSurface` adapts at `<sm` breakpoint:

```
[Passkey CTA]                       (full width)
[Google] [Sui]                      (still 2-up — they fit)
or use email
[email input]
[Continue]
▸ More ways
```

Brand panel (`signin.astro:62-108`) is desktop-only already (`hidden lg:flex`) — keep. KPIs / cycle ticker hidden on mobile. The form panel `<section>` becomes the whole viewport with `py-12 px-5`. Touch targets ≥ 44pt per `/u/CLAUDE.md` Apple HIG rules.

### §13.9 — Accessibility

- **Focus order:** Passkey → Google → Wallet → Email input → Continue → Disclosure → "More ways" children
- **Focus management:** when the inbox panel renders, focus moves to its heading (`tabindex="-1"`); when password reveals, focus moves into the password field
- **`aria-live="polite"`** on the inbox panel and any error region
- **`aria-label`** on icon-only buttons (Sui logomark, Google G)
- **Keyboard activation** of `<details>` disclosure (default browser behavior is fine; just verify)
- **Reduced motion:** the violet pulse + shake-on-error respect `prefers-reduced-motion`
- **Color contrast** on `text-zinc-500` on `bg-[#0a0a0f]` measures ≥ 4.5:1 (verify with axe in W4 row 14)

### §13.10 — Existing-user migration safety

Current users with sessions and enrolled passkeys must keep working through the `databaseHooks.session.create.after` change. Concretely:

- W1 R6 must verify `ensureHumanUnit()` is a true no-op when the unit already exists (idempotent INSERT-IGNORE pattern, not "throws if exists")
- Add W4 row 11: existing-session-survives-deploy (write a session under old code, deploy, fetch /api/auth/session, expect same user)
- Don't delete `SignInWithAnything.tsx` until after rollout (already in §11; reaffirm here)
- Deprecated `/api/auth/wallet/*` routes stay mounted — `auth.ts` `suiWallet` plugin replaces them but old client links may still hit them

### §13.11 — Magic-link arrival hardening

The verify endpoint must:

1. Validate the token (Better Auth handles signature)
2. Check single-use + not-expired (R4 verifies plugin does this)
3. Check the *clicking* request's IP/UA isn't on a deny-list (basic anti-bot)
4. **Not** invalidate the user's existing sessions (don't kick them off other devices)
5. Set the cookie with `SameSite=Lax` (default), `Secure` in prod, `HttpOnly`

If any check fails → `/auth/link-expired` or `/auth/link-used` route per §13.5.

### §13.12 — Tests added for hardening

Append to W4 (rows 11-18, brings total to 18):

```
11 existing-session-survives-deploy
12 redirect-allowlist-rejects-evil-com
13 composite-rate-limit-per-email-ignores-IP-rotation
14 password-lockout-after-5-fails
15 magic-link-replay-fails
16 magic-link-expired-shows-route
17 axe-core-no-violations
18 mobile-viewport-renders (vitest + happy-dom @ 390px)
```

---

## §14 — v1.1 followups (defer-OK)

Each becomes a separate small TODO, not blocking the auth-ui ship. Listed so they don't get forgotten.

| Item | Why defer | Likely TODO |
| --- | --- | --- |
| Password reset / "Forgot password?" | Magic-link is the de-facto reset (gets you in without a password); a real reset flow is needed once we have password-only users | `TODO-auth-pwreset.md` |
| 2FA / step-up auth | Owner-tier ops (key rotation, federation peer-add) should require fresh biometric within 5 min | `TODO-auth-stepup.md` |
| Email change UX | `auth.ts` already has `changeEmail.enabled: true`; needs `/settings/email` form + verification | `TODO-settings-email.md` |
| Account deletion / GDPR forget | Maps to existing `/api/memory/forget/:uid` for the human unit; needs UI + email + cooldown | `TODO-account-delete.md` |
| Server-side audit signals | Emit `audit:auth:{login,fail,new-device,password-change}` to D1 `owner_audit` per `mac.md` patterns | `TODO-auth-audit.md` |
| Multi-device sign-out / session list | `/settings/sessions` shows active sessions, allows revoke | `TODO-settings-sessions.md` |
| Sign-in monitoring dashboard | Pheromone tags `auth-ui:*` already deposit; need a `/dashboard?surface=auth` view | folded into existing `/dashboard` |
| i18n | All copy hardcoded English; adopt `astro-i18n` once a second locale is committed | `TODO-i18n.md` |
| Better Auth version pin + upgrade test | Plugin API may change; lockfile + upgrade smoke test | folded into deploy CI |
| Remove `SignInWithAnything.tsx` + deprecated `/api/auth/wallet/*` | Wait two release cycles after auth-ui ships, then prune | `TODO-auth-cleanup.md` |
| Collapse `/signin` + `/signup` to one URL | Both render the same component now; SEO can keep aliases | follow-up |

---

## §15 — Out of scope

- **Passkey enrollment for an existing email user** — `registerPasskeyForSignin()` already exists; UI lives in `/settings/security`, not here.
- **Email verification** — Better Auth supports it; we don't enforce since magic-link click already proves email ownership.
- **Recovery flow UI** — `/u/restore` owns the BIP39-paste → PRF re-derive → passkey re-enroll sequence per `passkeys.md` State 5. auth-ui only links to it.
- **Cross-subdomain SSO** — `auth.ts` already configures `crossSubDomainCookies` for `*.one.ie`; this plan does not touch that wiring.
- **Removing `SignInWithAnything.tsx`** — leave for follow-up cleanup.
- **Collapsing `/signin` and `/signup` into a single URL** — both routes render the same `AuthSurface` after this change; URL collapse is a follow-up if SEO allows.

---

## §16 — Cross-references reconciled

- [`passkeys.md`](passkeys.md) — auth-ui is the doorway; lifecycle State 1→2→3 still owned there. No change.
- [`secrets.md`](secrets.md) — uses existing Resend wiring; no new secret introduced.
- [`website.md`](website.md) — `/signin` and `/signup` now host one component, five doors. Update on close.
- [`README.md`](README.md) glossary — add `auth-ui` line if cluster expansion is acceptable; otherwise inline this into `passkeys.md` §UI.

---

*One surface. Five doors. The user never picks a method — they pick the door that fits the moment, and conditional UI makes the right one already there before they think to ask.*
