# Secrets — three stores, one job each

Application of the pattern in `mac.md`: biometric gates a key, ciphertext or signatures come out. The pattern applies at three scales with three different stores — each store handles the thing it's best at, no overlap.

---

## One-line summary

**Keychain for anything a browser touches. dotenvx for anything a teammate touches. Vault for everything else.**

---

## The decision — 2 seconds, 3 questions

```
Does a browser want to autofill it?        → iCloud Keychain
Does a teammate need it?                   → dotenvx (in the repo)
Else                                       → ~/.vault.age (personal root)
```

Every secret has exactly **one** home. Duplication is where drift happens.

---

## The three stores

| Store | What lives there | Gate | Recovery |
|---|---|---|---|
| **iCloud Keychain** | Website logins, credit cards, 2FA TOTP, passkeys | Touch ID / Face ID | Apple ID Recovery Key (paper 1) |
| **dotenvx** (repo) | Team-shared env vars (DB URL, API keys, deploy tokens) | `.env.keys` on disk (FileVault covers at rest) | CI secret store + teammate redistribution |
| **`~/.vault.age`** | Personal root creds, recovery keys, crypto seeds, rare/catastrophic | Touch ID (Secure Enclave) | Break-glass age key (paper 2) |

Three recovery papers total: FileVault (covers paper 1 + paper 2 at rest), Apple ID Recovery Key (paper 1), break-glass age key (paper 2).

---

## 1. iCloud Keychain — browser autofill

**What goes in:** every website login, credit cards, shipping addresses, 2FA TOTP codes, passkeys for sites that support them.

**Setup:**
- System Settings → Apple ID → iCloud → **Passwords & Keychain → On**
- System Settings → Apple ID → **Advanced Data Protection → On** *(Phase 8 of `mac-agent.md`; makes iCloud Keychain end-to-end encrypted — Apple can't read it)*
- Safari → Settings → AutoFill → **Passwords: On**

**On Chrome:** install the [iCloud Passwords Chrome extension](https://chromewebstore.google.com/detail/icloud-passwords/pejdijmoenmkgeppbflobdenhhabjlaj). Same keychain, different browser.

**Why it belongs here:** autofill 20x/day. A vault-based flow would be unusable at this frequency. Apple's E2E-with-ADP gives equivalent protection to a third-party password manager without adding a vendor.

**Recovery:** Apple ID Recovery Key on paper. If Apple ID is lost without the recovery key, the keychain is gone — hence ADP + paper.

---

## 2. dotenvx — team repo secrets

**What goes in:** every env var the team's backend needs (database URLs, Stripe keys, Cloudflare tokens, Anthropic keys for the shared product).

**Shape:**

```
repo/
├── .env.production       ← committed, encrypted by dotenvx
├── .env.keys             ← gitignored, chmod 600, each dev's copy
└── wrangler.toml (or similar deploy config)
```

**Setup (once per project):**
```bash
dotenvx encrypt
echo ".env.keys" >> .gitignore
git add .env.production && git commit
```

**Each teammate, once per machine:**
Paste the shared `.env.keys` (distributed out-of-band — Signal, password-manager handoff).

**Deploy (local or CI):**
```bash
dotenvx run -- wrangler deploy
```

At deploy time, dotenvx decrypts and exports the real values into the subprocess; wrangler reads them and pushes to Cloudflare's native secret store. Worker code reads `env.X` at runtime.

**Scoped keys for LLM-agent workloads:**

```
.env.production    ← full creds (humans, deploy)
.env.agent         ← read-only subset (anything an LLM reaches)
```

Give the LLM process only `DOTENV_PRIVATE_KEY_AGENT`. A prompt-injection that tricks the agent into calling `delete_user` hits 403 because the credential never had the scope. See `agents.md` Pattern C.

**CI:**
- GitHub Actions repo secret: `DOTENV_PRIVATE_KEY_PRODUCTION` (+ `CLOUDFLARE_API_TOKEN` or equivalent)
- CI step runs `dotenvx run -- wrangler deploy`

**Why it belongs here, not in the vault:** teammates + CI can't Touch ID your Mac. Team-shared credentials need a team-shared distribution mechanism. The vault is personal by design.

**Rotation:** `dotenvx rotate`, commit new encrypted file, redistribute `.env.keys` out-of-band.

---

## 3. `~/.vault.age` — personal root

**What goes in:** the kind of secret where the answer to "what if this leaks?" is "call the police."

- Apple ID Recovery Key, FileVault recovery key, break-glass age key (inside the vault too, belt-and-braces)
- Crypto wallet seeds, BIP39 phrases, hardware wallet backup codes
- Personal API keys (your own Anthropic, OpenAI, AWS root — not team)
- Personal server SSH passphrases, DB root passwords on your side-projects
- The "secrets map" — a list of categories pointing at where each credential actually lives

**What does NOT go in:** website passwords (Keychain's job), team env vars (dotenvx's job). Putting those in the vault costs you 20 Touch IDs a day for zero security gain.

**Shape (sections map to the category, not the project):**

```ini
# ~/.vault.age (plaintext when decrypted)

[map]
# where everything actually lives — grep this when you forget
gmail                 → keychain
openai-personal       → [api] here
stripe-prod           → dotenvx .env.production in one.ie repo
metamask-main         → [crypto] here
apple-id-recovery     → paper 1 + here
break-glass-age       → paper 2 + here
github-personal-pat   → [api] here

[recovery]
filevault_recovery_key = XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
apple_id_recovery_key  = YYYY-YYYY-YYYY-YYYY-YYYY-YYYY-YYYY

[api]
ANTHROPIC_API_KEY_PERSONAL = sk-ant-...
OPENAI_API_KEY_PERSONAL    = sk-...
GITHUB_PAT_PERSONAL        = ghp_...

[crypto]
metamask_main_seed = ...
sui_personal_seed  = ...

[runbook]
If Mac is compromised: pause all agents, rotate GitHub PAT + Anthropic key + Cloudflare token.
```

Edit with `v` (per `mac.md` §1.5) — Touch ID, nano opens, save, Touch ID re-seals. Vault is encrypted to SE + break-glass age key.

---

## Solo side-projects — `envr` (optional)

For personal projects that are *your* code, *your* creds, never touched by a team, you can skip dotenvx and let `envr` inject vault sections straight into a subprocess. Per-project section in the vault, no per-repo file.

```bash
cd ~/code/my-side-project
envr pnpm dev          # Touch ID fires once, env vars in subshell, gone on exit
```

`envr` shell function (if you want it):

```bash
envr() {
  local project vault
  if [ -f .envr-name ]; then
    project="$(cat .envr-name)"
  elif [ -f package.json ]; then
    project="$(jq -r '.name // empty' package.json 2>/dev/null)"
  fi
  [ -z "$project" ] && project="$(basename "$PWD")"

  vault=$(age -d -i ~/.config/age/se.key ~/.vault.age) || {
    echo "envr: could not decrypt vault" >&2
    return 1
  }

  (
    [ -f .env ] && set -a && . ./.env && set +a
    eval "$(
      printf '%s\n' "$vault" | awk -v p="$project" '
        /^\[.+\]$/ { s = substr($0, 2, length($0)-2); m = (s == "_global" || s == p); next }
        m && /^[A-Za-z_][A-Za-z0-9_]*=/ { print "export " $0 }
      '
    )"
    exec "$@"
  )
}
```

Add sections like `[my-side-project]` to your vault. `envr` picks the section by folder name.

**When NOT to use `envr`:**
- Anything with teammates → dotenvx
- Anything that needs to run in CI → dotenvx (CI can't Touch ID)
- Anything with >1 dev machine that stays in sync → dotenvx

`envr` is a nicety for "just me, just my laptop" projects. Nothing more.

---

## Users of the product — same pattern, portable

The app (`one.ie`) applies this same shape for the wallets it generates for users:

| This file (you) | The user's browser |
|---|---|
| Secure Enclave age key | WebAuthn passkey (PRF extension) |
| `~/.vault.age` | Passkey `largeBlob` (encrypted wrapped seed) |
| Break-glass age key paper | 12 BIP39 words |

Same three-store shape, portable via WebAuthn + iCloud / Google Password Manager. Spec: `passkeys.md`.

## A fourth class — derived, never stored

Not every secret needs a store. Some are computed on demand from a biometric and live for milliseconds:

- **Substrate owner API key** — `HKDF(owner_prf, "api-key:owner:v1")`. Derived on Touch ID, used as bearer, evicted from memory on tab close. Never written to Keychain, dotenvx, or vault. Server stores only `hash(key)`. See `owner.md`.
- **Agent wallet KEKs** — `HKDF(owner_prf, "agent-key:{uid}:v1")`. Derived once when owner spawns an agent, used to wrap the agent's seed, then evicted. Ciphertext lives in D1; KEK never persists.

Rule: **anything derivable from the PRF goes nowhere.** It's faster than reading from disk and impossible to leak from disk because it isn't there. The vault, dotenvx, and Keychain hold the secrets that *can't* be derived (recovery keys, team-shared API tokens, website logins). Everything biometric-derived is computed on demand.

`SUI_SEED` was the anti-pattern: a derivation seed sitting in env vars on every machine. **Removed.** Per-actor seeds are generated at spawn and wrapped under the owner PRF; nothing in env or repo derives keys system-wide.

---

## Multi-machine (the vault, not dotenvx)

dotenvx distributes itself — clone the repo, paste `.env.keys`, done. The vault needs explicit re-encryption on each new machine.

```bash
age -d -i ~/.config/age/se.key ~/.vault.age \
  | age -r "$AGE_SE_RECIPIENT_MAC_1" \
        -r "$AGE_SE_RECIPIENT_MAC_2" \
        -r "$AGE_BREAKGLASS_RECIPIENT" \
        -o ~/.vault.age.new
mv ~/.vault.age.new ~/.vault.age
```

Copy the ciphertext to the second Mac over any channel. Lose a machine → re-encrypt without its recipient.

---

## Multi-line secrets (the vault)

INI parser reads one key per line. For PEM / JSON / private-key blobs: base64 at rest, decode at runtime.

```bash
base64 -i ./mycert.pem | pbcopy          # paste result into vault
```

```ts
const pem = Buffer.from(process.env.MYCERT_B64, 'base64').toString()
```

---

## Rotation cadence

| What | Cadence | How |
|---|---|---|
| iCloud Keychain passwords | On leak / annually for critical accounts | Safari → Passwords → edit; iCloud syncs |
| dotenvx private key | On teammate departure / suspected leak | `dotenvx rotate`, redistribute `.env.keys` |
| Vault SE identity | Yearly / on Mac compromise | `age-plugin-se keygen`, re-encrypt vault |
| Break-glass age key | Every 2 years / on paper compromise | Transition window with old + new recipients |
| Personal API keys (in vault) | On suspected leak | Edit with `v`, update vendor side |

---

## Self-audit (quarterly — run with `mac.md` §1.16)

- [ ] Keychain: ADP on, 2FA on for Apple ID, trusted devices pruned
- [ ] dotenvx: `.env.keys` in every `.gitignore`, no plaintext secrets in `git log -S sk-`
- [ ] Vault: `v` opens, canary decrypts with paper key, sections match the `[map]`
- [ ] No secret appears in more than one store
- [ ] Every API key has exactly one rotation path documented

---

## What this replaces

- "Which store do I use?" → three questions, 2 seconds
- Per-project `.env` ceremony → dotenvx for team, `envr` for solo side-projects, nothing else
- Third-party password managers → iCloud Keychain with ADP
- "Where did I put that key?" → the `[map]` section in the vault
