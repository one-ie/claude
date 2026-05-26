# Mac Setup

## Welcome

You're about to spend an afternoon setting up a Mac that will protect you for years.

Not by being complicated — by being *simple enough that you'll actually follow it*. One fingerprint unlocks everything. Two pieces of paper in two different places can rebuild everything from scratch. No master password to forget. No third-party app holding your secrets. No single point of failure.

When you're done, this is your daily life:

- **Open the vault** — type `v`, press your finger, your secrets appear
- **Push to GitHub** — `git push`, press your finger, it goes signed
- **Run an agent** — Touch ID fires once, the agent works within its rules forever
- **Lose the Mac** — get a new one, sign in, restore from paper, back in an hour

The lifecycle is four moments:

```
Day one   →  Set it up (this doc, one afternoon, done once)
Every day →  Touch ID. That's it.
Every quarter →  10-minute check: prove the papers still work, rotate anything stale
New Mac   →  Run mac-agent, restore from backup + paper, one hour
```

That's the whole thing. The rest of this document is the detail behind those four moments.

---

> **If you're setting up with someone else** — do every stage together, same pace, both Macs. The installs run in parallel. The conversations that happen while you wait are half the value. You'll understand this system much better having explained it to each other than having read it alone.

---

**Machine:** MacBook Air M5, 24 GB.
**Adversary:** assume targeted. Phishing, supply-chain, rogue extension, malicious MCP / hook, compromised dep, evil maid, Apple ID takeover, coerced biometric. Design rule: any single loss is recoverable; no loss is silent.

---

## The pattern — two roots, one biometric, paper resurrects

| Root | Custodian | Gates | Resurrected by |
| --- | --- | --- | --- |
| **Apple ID** (ADP on) | Apple, E2EE — no Apple-side reset | iCloud Keychain: passwords, passkeys, TOTP, autofill | **Recovery Key** on paper (§1.2) |
| **SE identity** | this Mac, non-exportable | SSH / Git signing, `~/.vault.age`, wallet passkeys | **Break-glass** age key on paper (§1.3) |

Both roots unlock via Touch ID. Neither private key leaves the device. No master password, no third-party custody, no Secret Key to print. Lose Mac → Apple ID + SE reference + break-glass paper rebuild everything. Lose Apple ID → Recovery Key paper. Lose both paper envelopes *and* the Mac → you're done; keep them geographically separate.

The SE identity is the human root in the agent-era sense: no agent, no ownership chain, no Move code can produce your biometric signature. It's physics, not policy. This is the safety floor beneath every agent and sub-agent rooted in you — the one asymmetry that scales. See `agents.md` §Safety floor for the full peer-agent framing, and `owner.md` for the role this hardware root authorizes — the substrate `owner`, exactly one per deployment, from which all other authority descends.

| Data | Store | Key source |
| --- | --- | --- |
| Passwords, passkeys, TOTP, autofill | iCloud Keychain (Passwords.app) | Apple ID |
| SSH + Git signing | Secretive | SE identity |
| Recovery keys, backup codes, API tokens, runbooks | `~/.vault.age` | SE + break-glass recipients |
| Per-project `.env` injection | `dotenvx` (team) / `envr` (solo) → `secrets.md` | SE identity |
| Web3 signing | WebAuthn passkey → `passkeys.md` | SE identity |

---

## Threat model — what's defended, what's accepted

| Attack | Defense |
| --- | --- |
| Phishing / credential reuse | Passkeys (domain-bound); TOTP in Keychain where passkeys unavailable; never SMS |
| Stolen / lost Mac | FileVault + non-exportable SE keys; `~/.vault.age` is ciphertext at rest |
| Apple ID takeover | ADP + Recovery Key paper + passkey on Apple ID + second passkey on second Apple device |
| New fingerprint enrolled under coercion | `current-biometry` invalidates the SE identity; break-glass paper restores |
| Supply chain (deps, brew taps, scripts) | Pinned lockfiles; `socket.dev`; no `curl \| bash`; `age-plugin-se` hash-verified before install |
| Malicious MCP / Claude hook / agent | Deny-by-default allowlist; no `--dangerously-skip-permissions` near wallets or `$HOME`; on-chain authority bounded by Sui Move (`agents.md`), not `settings.json`; routing substrate's `warn()` accumulation makes consistently-failing agents toxic and unreachable — no explicit block needed |
| Keylogger / rogue accessibility helper | Terminal Secure Keyboard Entry; Safari as sole autofill surface; quarterly extension audit |
| Memory / core-dump / swap leak | `ulimit -c 0`; FileVault covers swap and `/tmp`; nano writes no swap/undo/history so plaintext never hits disk beyond a 600-mode tmp file |
| Coerced biometric (you at keyboard) | Hot wallet only on this machine; cold funds on hardware wallet offline; panic = power off (FileVault re-locks) |
| Rogue on-chain agent | Scope bounded by Sui Move for both human-owned and peer agents (`agents.md`); co-sign first, then scoped autonomy; biometric root uncrossable regardless of ownership depth |
| **Accepted** | Simultaneous loss of Mac + Apple ID + paper. Mitigate by geographic separation of the three. |

---

## 1. Security

### 1.1 macOS baseline

```bash
# Encryption, firewall, SIP, auto security updates
fdesetup status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
spctl --status
csrutil status   # must be "enabled"
sudo softwareupdate --schedule on
# Note: --setloggingmode was removed in recent macOS; firewall logging is on by default.
```

In **System Settings**:
- Privacy & Security → FileVault ON; recovery key printed on paper, stored offline, second copy dropped into `~/.vault.age` (§1.5). If the GUI wizard doesn't print a personal key, run `sudo fdesetup changerecovery -personal` to generate and print one.
- Privacy & Security → App Store and identified developers
- Lock Screen → require password immediately; screen saver after 10 min (5 is annoying at home; tighten if shared space)
- General → Sharing → off for everything you don't use; AirDrop → Contacts Only
- Analytics + personalized ads → off
- Touch ID → enroll (this is also what `current-biometry` binds the SE identity to)

**Note on FileVault recovery keys:** never paste a recovery key into any chat or browser window. Write only on paper. Verify with `sudo fdesetup validaterecovery` — type the paper key at that prompt, expect `true`. If a key leaks, rotate with `sudo fdesetup changerecovery -personal` and write the new one.

Touch ID for sudo:
```bash
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
sudo vi /etc/pam.d/sudo_local    # uncomment pam_tid.so
```

**Lockdown Mode**: breaks JIT, link previews, managed profiles, some attachments, FaceTime from unknown callers. If you hold real funds and run AI agents, you *are* a target — turn it on for the everyday Apple ID and accept the papercuts, or run a second user account with it on for crypto work.

### 1.2 Apple ID — root #1

Holds the entire iCloud Keychain (passkeys, TOTP, passwords). Treat it as a root, not a convenience.

- Long unique passphrase — generated once, stored in `~/.vault.age`, never memorised
- **Passkey** on the Apple ID itself; **second passkey** registered from a second Apple device (iPad / iPhone) — survives an in-progress takeover or a sync failure
- 2FA ON; **Advanced Data Protection** ON (E2EE; Apple cannot reset)
- **Recovery Key** generated, printed, stored offline with the FileVault paper — *this is the real recovery path under ADP*
- **Recovery Contact** — convenience only; do not rely on it as your sole path back
- Quarterly: prune trusted phone numbers and devices; revoke anything stale

### 1.3 Secure Enclave identity — root #2

```bash
brew install age age-plugin-se
mkdir -p ~/.config/age && chmod 700 ~/.config/age
age-plugin-se keygen --access-control=current-biometry --output ~/.config/age/se.key
chmod 600 ~/.config/age/se.key
# The file header contains "# public key: age1se1..." — that's the recipient.
SE_RECIPIENT=$(grep "public key:" ~/.config/age/se.key | awk '{print $NF}')
```

`age-plugin-se` is now in homebrew-core (formulae are reviewed and bottled by Homebrew). The old `remko/tap` is a 404 — don't use it.

**Verify before install.** `age-plugin-se` is the root of trust for everything in `~/.vault.age`. `brew info age-plugin-se` → for belt-and-braces, cross-check against a signed release at `github.com/remko/age-plugin-se`. Paranoid path: build from source. A compromised binary = full vault compromise.

**Three files make this root survivable — lose any one and the others rebuild it:**

1. **The SE private key** — inside the chip, non-exportable, gated by `current-biometry` so any new fingerprint enrollment invalidates it (tamper-evident under duress).
2. **`~/.config/age/se.key`** — a *reference* to the SE slot, not the key. Without it the slot can't be located even on the same Mac. Back it up in Time Machine, offsite snapshot, and an encrypted USB you control. Treat like the vault.
3. **Break-glass age key** — generated once, printed, stored offline with the FileVault and Apple ID paper. Decrypts the vault when the Mac is gone or the SE is invalidated.

```bash
age-keygen -o /tmp/breakglass.key
grep "public key" /tmp/breakglass.key   # → AGE_BREAKGLASS_RECIPIENT
# print /tmp/breakglass.key on paper, store offline, then:
rm -P /tmp/breakglass.key
```

In `~/.zshrc`:
```bash
export AGE_SE_RECIPIENT="age1se1qg...yourvalue..."
export AGE_BREAKGLASS_RECIPIENT="age1...paperkeyvalue..."
```

Every future encryption uses `-r "$AGE_SE_RECIPIENT" -r "$AGE_BREAKGLASS_RECIPIENT"`. The paper decrypts only when you need it, so rotate it only on compromise.

**Canary**: keep `~/.vault-canary.age` containing a known string, re-encrypted to both recipients whenever you edit the vault. The quarterly audit (§1.16) decrypts it with *only* the break-glass key — the one moment per quarter you prove the paper still works.

### 1.4 iCloud Keychain — passwords, passkeys, TOTP

Passwords.app (macOS Sequoia+) is the UI; iCloud Keychain is the store. With Advanced Data Protection on it's E2EE — Apple holds ciphertext, only your devices decrypt.

- **Passkeys** wherever offered: Apple ID, GitHub, Google, Cloudflare, Shopify, X, PayPal. Phishing-resistant, domain-bound.
- **TOTP** in the same Keychain entry as the login. Never SMS. Never email-only.
- Safari autofill handles passwords + passkeys + TOTP everywhere.
- Turn off Chrome/Firefox built-in password saving. One store.
- **Second passkey** on top-tier accounts (Apple ID, GitHub, Google, primary email, exchanges), registered from a *second* Apple device (iPad / iPhone). iCloud sync is usually enough — a separately-registered passkey survives an Apple-ID takeover in progress or a sync failure.

### 1.5 `~/.vault.age` — the one encrypted file

Everything that isn't a password, passkey, TOTP, or SSH key lives here. One file, one Touch ID prompt, plain text inside.

In `~/.zshrc`:
```bash
ulimit -c 0                       # no core dumps
setopt HIST_IGNORE_SPACE          # leading-space commands skip history

v() {
  local tmp; tmp=$(mktemp -t vault) && chmod 600 "$tmp"
  trap 'rm -P "$tmp" 2>/dev/null' EXIT INT TERM
  age -d -i ~/.config/age/se.key ~/.vault.age > "$tmp" 2>/dev/null || echo "# new vault" > "$tmp"
  nano "$tmp"   # nano/pico writes no swap, undo, or history files by default
  local recipients=(-r "$AGE_SE_RECIPIENT")
  [[ -n "$AGE_BREAKGLASS_RECIPIENT" ]] && recipients+=(-r "$AGE_BREAKGLASS_RECIPIENT")
  age "${recipients[@]}" -o ~/.vault.age "$tmp"
}
```

Touch ID gated. Plaintext never persists beyond a 600-mode tmp file. macOS `nano` is pico-compatible and writes no swap, undo, or history files by default — the `.swp` / `.viminfo` / undo-history leak class doesn't apply. On APFS `rm -P` is best-effort — **FileVault is what actually prevents at-rest leakage of the tmp file**, so FileVault must be on (§1.1) for this pattern to hold. (Earlier revisions used `vim -n -i NONE …` with hardening flags; swapped to nano because most users don't know vim.)

**Terminal**: View → Secure Keyboard Entry (on). Blocks other apps from keylogging the focused terminal.
**Paste discipline**: never paste a seed or master key anywhere. Secrets flow *out* of `v`, not in.

What goes in:
- Apple ID master passphrase, Recovery Key, Recovery Contact info
- FileVault recovery key (second copy; paper is primary)
- 2FA backup codes (GitHub, Google, exchanges)
- Hardware-wallet seed *location* — never the phrase itself (metal only)
- Exchange API keys used from scripts
- Contract / wallet addresses to watch
- Offsite-backup encryption key (§1.13)
- "If my Mac is compromised" runbook as the first entry

`~/.vault.age` is ciphertext — safe in Time Machine, iCloud Drive, USB. Only the SE (or the paper break-glass) decrypts it.

### 1.6 SSH + Git signing

```bash
brew install --cask secretive
```

Generate an Ed25519 key inside Secretive, add the public key to GitHub as **both** auth and signing, and point `~/.ssh/config` at the Secretive agent per the app's walkthrough. Every `ssh` or `git push` triggers Touch ID.

Sign every commit with the same key:
```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/secretive.pub       # path Secretive gave you
git config --global commit.gpgsign true
git config --global tag.gpgsign true
mkdir -p ~/.config/git
echo "you@host $(cat ~/.ssh/secretive.pub)" >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

GitHub: fine-grained PATs only, 30–90 day expiry. Passkey + TOTP fallback. "Require SSH signing" on important repos.

### 1.7 Dev secrets

See `secrets.md`. **Three stores: iCloud Keychain (browser), dotenvx (team repo), `~/.vault.age` (personal root).**

For local solo side-projects, the vault also supports per-project injection via `envr <cmd>` — finds the current project, decrypts vault, overlays the `[project]` section, runs the command. Same SE identity from §1.3, Touch ID per invocation, no per-repo setup. Teams use dotenvx instead (CI can't Touch ID).

### 1.8 Crypto

See `passkeys.md` for the Sui wallet pattern — same shape in the browser: Secure Enclave, biometric gate, one private key that never leaves hardware.

Non-negotiables for real funds:
- **Hardware wallet** (Ledger/Trezor/GridPlus) for cold holdings. A dev machine running AI agents should never hold the *root* signing key.
- **Seed phrase** on metal, offline. Never typed, photographed, synced, pasted into a prompt.
- Separate **hot wallet** (small, for testing) from cold holdings
- Dedicated **web3 browser profile** (§1.9)
- **Watch-only** wallets on this Mac
- Revoke token approvals quarterly (`revoke.cash`)
- Verify contract addresses from two independent sources before signing
- Every support DM, airdrop, unsolicited link = hostile

**Agent-held wallets are fine on this machine** — as long as they're scoped by Sui Move (`agents.md`). The root passkey stays in the Secure Enclave; agent authority is cryptographically bounded via co-sign, scoped-autonomy modules, or capability objects. "Can't exceed scope," not "shouldn't."

### 1.9 Browsers

Two contexts, not four browsers:
- **Everyday + dev** — Safari (first-class iCloud Keychain / passkey / TOTP autofill) with uBlock Origin
- **Web3** — a separate profile (or Brave). Wallet extensions only here. No email, no socials, no other extensions.

Audit extensions quarterly — every one reads every page.

### 1.10 Network

- **LuLu** (Objective-See) — outbound firewall; review rules monthly for surprise destinations
- **Tailscale** with tag-based ACLs — default any-to-any mesh is too broad for a crypto dev machine
- **Mullvad / ProtonVPN** on untrusted Wi-Fi
- **BlockBlock / KnockKnock / OverSight** (Objective-See) — persistence + mic/cam alerts; cheap signal on compromise

### 1.11 Claude Code + agents

Largest new attack surface. An agent with shell access is a confused deputy waiting to happen. Assume every untrusted input (issues, scraped pages, PR bodies, tool output) contains hostile instructions.

- **Never** `--dangerously-skip-permissions` near wallets, live `.env`, or `$HOME`. Scoped project dirs only.
- Deny-by-default allowlist in `~/.claude/settings.json`: block `rm -rf`, `curl | sh`, `sudo`, writes outside the project, network to new hosts. Use `/update-config`.
- MCP servers run arbitrary code as you — audit before install, pin versions, prefer first-party.
- Review hooks before saving. A `PreToolUse` hook can exfiltrate every tool input.
- Never auto-approve tool calls that *follow* an untrusted read — treat as prompt-injection zone.
- Sensitive work → Docker or a VM with no Keychain / SSH-agent forwarding.
- **On-chain authority** is bounded by Sui Move (`agents.md`), not shell config. Scoped wallets, capabilities, pause + revoke. Shell allow/deny is line two; Move is line one.

### 1.12 Supply chain

- Pin versions; commit lockfiles; never `curl | bash`
- Vet new deps before install: downloads, maintainer history, publish spikes, typosquats
- `npm audit`, `pip-audit`, `trivy`, [socket.dev](https://socket.dev) on every repo
- Containers: non-root user; never mount the Docker socket into an agent-accessible container
- Brew taps from non-core maintainers → read the formula, verify SHA256 against an upstream signed release before `brew install`

### 1.13 Backups

- **Time Machine** → encrypted external SSD, rotated; one copy offsite
- **Offsite** — Arq or Backblaze with a **client-side** encryption key you control. Store that key in **both** `~/.vault.age` **and** on the break-glass paper (§1.3). A lost Mac must never cascade into lost backups.
- **Every backup must include:** `~/.vault.age`, `~/.config/age/se.key` *(load-bearing — without it the SE slot is unfindable)*, `~/Library/Keychains/`, source, `~/Documents`. iCloud Keychain syncs itself.
- **Test a restore every quarter** — untested backup = no backup.
- Seed phrases live on metal only, never in any backup.

### 1.14 Incident prep

- Find My Mac enabled → remote wipe
- Every API key, token, wallet catalogued in `~/.vault.age`, tagged by service
- Know the rotate URL for: GitHub, Anthropic, OpenAI, AWS, Cloudflare, Google, exchanges
- The first entry in `~/.vault.age` is the "If my Mac is compromised" runbook

### 1.15 Recovery matrix

What you lose → how you recover. Any *single* loss is survivable by construction. Two simultaneous losses from {Mac, Apple ID, paper} is the accepted failure mode; keep them geographically separated.

| Loss | Recovery path |
| --- | --- |
| Forget a password | iCloud Keychain autofills it; no memory needed |
| Forget screen-lock / Mac admin password | FileVault recovery key (paper, offline) |
| Mac dead or stolen | New Mac → Apple ID sign-in restores iCloud Keychain. Restore `~/.vault.age` + `~/.config/age/se.key` from backup. Generate a new SE identity (§1.3). Use the **break-glass** age key to decrypt the old vault and re-encrypt to the new SE recipient. |
| Apple ID locked out | Recovery Contact, or Recovery Key (paper). Without either, ADP accounts are unrecoverable — this is the tradeoff of end-to-end iCloud encryption. |
| SE identity invalidated (new fingerprint enrolled, or `current-biometry` tripped) | Break-glass age key decrypts `~/.vault.age`. Generate a fresh SE identity, re-encrypt. |
| `~/.config/age/se.key` reference file deleted | Restore from backup. Without backup, the SE slot can't be located — fall back to break-glass. |
| Break-glass paper destroyed | Generate a new break-glass *while* the SE still works and re-encrypt the vault. Don't defer — this is a silent single-point-of-failure. |
| Hardware-wallet device lost | Seed phrase on metal → restore onto a replacement device. |
| Seed metal destroyed *and* hardware wallet lost | Funds unrecoverable. Why the metal stays offsite. |
| Second Mac compromised | Re-encrypt `~/.vault.age` without that machine's SE recipient; rotate any secret it saw. |

### 1.16 Quarterly verification — *prove it, don't check a box*

Presence ≠ working. Each item is an action that produces evidence.

**Roots + resurrection**
- [ ] **Decrypt the canary with only the break-glass key** — `age -d -i <paper-key-typed-in> ~/.vault-canary.age`. This is the one moment per quarter you confirm the paper still works and you can still read it. If this fails, everything else is cosmetic.
- [ ] `v` opens `~/.vault.age`, Touch ID fires, file edits round-trip. Re-encryption writes to **both** `$AGE_SE_RECIPIENT` and `$AGE_BREAKGLASS_RECIPIENT`.
- [ ] Locate all three paper envelopes (FileVault, Apple ID Recovery Key, break-glass). Physically. Readable.
- [ ] `~/.config/age/` is 700; `se.key` is 600. Reference file present in last Time Machine snapshot.

**Apple ID**
- [ ] ADP still on. Passkey on Apple ID still enrolled. Second passkey on the second Apple device still enrolled.
- [ ] Trusted devices + phone numbers list pruned — no stale entries.

**macOS baseline**
- [ ] `fdesetup status` = on. `csrutil status` = enabled. `spctl --status` = assessments enabled.
- [ ] Firewall + stealth mode on. Screen locks immediately. Touch ID for sudo (`sudo -k; sudo -v` prompts for TID).
- [ ] Terminal → Secure Keyboard Entry on.

**Accounts**
- [ ] Passkeys enrolled on: Apple ID, GitHub, Google, primary email, exchanges.
- [ ] TOTP (Passwords.app) — not SMS — for every non-passkey 2FA.
- [ ] GitHub PATs: all within expiry; none unused > 90 days.

**Dev + agent surface**
- [ ] `ls ~/.ssh/id_*` returns nothing. SSH routes through Secretive only. `git log --show-signature -1` verifies.
- [ ] `~/.claude/settings.json` allowlist reviewed; hooks re-read; MCP servers list re-vetted; versions pinned.
- [ ] Agent workspace is a project dir, not `$HOME`. No scoped agent has on-chain authority exceeding its Move capabilities (`agents.md`).

**Crypto**
- [ ] Hardware wallet firmware current. Seed metal located + legible.
- [ ] Token approvals revoked (`revoke.cash`) for every hot wallet.
- [ ] Web3 browser profile still isolated — no email, socials, or non-wallet extensions.

**Network + backups**
- [ ] LuLu running, rules reviewed for surprise outbound hosts. Tailscale ACLs pruned.
- [ ] **Restore test**: pick one file from last quarter's backup, decrypt it, diff against current. If the restore fails, the backup was never real.
- [ ] Offsite backup key present in `~/.vault.age` *and* on break-glass paper.

**Walk the matrix**
- [ ] Read §1.15 top to bottom. No row produces a new surprise. If one does, fix it this quarter, not next.

---

## 2. Day one — Tony + Donal

Two people, two new Macs. Work through each stage together — same commands, same pace. Takes about 2 hours total, most of it waiting for downloads.

**What you'll have by end of day:** a Mac where your fingerprint is the only key, your secrets never touch disk in plaintext, every git commit is signed, and if the machine is stolen tomorrow it's an encrypted brick.

**What to have ready:** two sheets of paper, two pens. You'll write down two keys each — the only things that ever need to be physical.

---

> **How to work with Claude today**
> Open Claude Code in Terminal. For every stage below, just say which stage you're on and I'll run the commands. You confirm, watch, and learn. I'll explain what just happened after each milestone.

---

---

### Stage A — Disk encryption + Apple ID
*~20 min. Mac restarts once. No terminal yet.*

Both of you do this simultaneously on your own Mac.

**A1. FileVault on**
System Settings → Privacy & Security → FileVault → Turn On
- Choose **"Create a recovery key, do not use iCloud"**
- A key appears. **Write it on paper now.** Don't photograph it.
- Restart when asked.

**A2. Apple ID hardening** (after restart, while encryption runs in background)
System Settings → Apple ID:
- iCloud → **Advanced Data Protection → On** — this makes iCloud E2EE. Apple cannot see your data and cannot reset your account. The Recovery Key you're about to generate is the only way back in if Apple locks you out.
- Password & Security → Recovery Key → Generate
- **Write this on the same paper as your FileVault key.** Two keys, one paper, one offline envelope.

**A3. Quick System Settings pass**
- Lock Screen → Require password: Immediately / Screen saver: 5 min
- Touch ID → enrol your fingerprint if not done — everything from here gates on this
- Sharing → off for everything unused; AirDrop → Contacts Only
- Privacy & Security → Analytics → off; Apple Advertising → off
- Firewall → On; Options → Enable stealth mode

**A4. Touch ID for sudo**
```bash
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
sudo sed -i '' 's/#auth/auth/' /etc/pam.d/sudo_local
```
Now your fingerprint unlocks `sudo`. No more typing your password for commands.

**A5. Verify — all four must pass**
```bash
fdesetup status   # FileVault On
csrutil status    # enabled
spctl --status    # assessments enabled
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate  # enabled
```

> **What just happened:** your disk is encrypted. If either Mac is stolen right now, it's an unreadable brick. Your Apple ID is end-to-end encrypted — Apple itself cannot hand your data to anyone. Your fingerprint now gates every privileged action.

---

### Stage B — Homebrew (the foundation)
*~10 min. One command that unlocks everything else.*

```bash
xcode-select -p || xcode-select --install   # CLT first if missing
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
eval "$(/opt/homebrew/bin/brew shellenv)"
brew analytics off
brew update && brew doctor
```

`brew doctor` says "Your system is ready to brew." — that's the green light.

> **What just happened:** Homebrew is the package manager for everything. `brew analytics off` means Homebrew doesn't phone home with what you install. One principle: nothing installs on this Mac except through Homebrew or the App Store, and every tap gets its SHA256 verified.

---

### Stage C — Install everything in parallel
*~15 min of downloads. Three tabs, all at once.*

Open three terminal tabs. Paste one block per tab. Come back when all three finish.

**Tab 1 — your security stack:**
```bash
brew install age age-plugin-se && \
brew install --cask secretive && \
brew install lulu && \
brew install --cask blockblock
```

**Tab 2 — your dev stack:**
```bash
brew install mise gh git starship jq ripgrep fd uv && \
brew install zsh-autosuggestions zsh-syntax-highlighting zoxide eza bat git-delta fzf lazygit && \
brew install cloudflared sui && \
brew install --cask ghostty && \
brew install --cask zed && \
brew install --cask orbstack && \
brew install --cask font-monaspace-nerd-font
```

> `typedb` console is optional — only needed if you run `bun run bootstrap` against a local database. Cloud users skip. `brew install typedb/tap/typedb`.

**Tab 3 — your network stack:**
```bash
brew install --cask tailscale && \
brew install --cask mullvad-vpn
```

While the downloads run, verify `age-plugin-se` — it becomes the root of trust for your vault. It ships in homebrew-core (reviewed and bottled by Homebrew), which is already a meaningful trust raise over a third-party tap. For belt-and-braces:
```bash
brew info age-plugin-se                  # note the bottle SHA
# open github.com/remko/age-plugin-se/releases — confirm upstream looks healthy
```

> **What just happened:** your full environment is installed. `secretive` keeps SSH keys inside the SE chip. `lulu` blocks unexpected outbound connections. `age-plugin-se` is what lets the SE chip encrypt your vault. `orbstack` replaces Docker Desktop. `mise` manages every runtime version per project. `cloudflared` lets any localhost server answer real webhooks through a named Cloudflare tunnel. `sui` is the Move toolchain — build, test, deploy. `jq` / `ripgrep` / `fd` / `uv` are the search / JSON / Python defaults every script assumes.

---

### Stage D — Your vault (the moment everything clicks)
*~15 min. After this, Touch ID is the only key you'll ever need day-to-day.*

**D1. SE identity — the key that lives in the chip**
```bash
mkdir -p ~/.config/age && chmod 700 ~/.config/age
age-plugin-se keygen --access-control=current-biometry --output ~/.config/age/se.key
chmod 600 ~/.config/age/se.key
```
It prints `age1se1q...` — copy that value. It's a reference to a key that physically cannot leave your Mac's security chip.

**D2. Break-glass key — write it on paper, then delete it**
```bash
age-keygen -o /tmp/breakglass.key && cat /tmp/breakglass.key
```
Write both lines on paper — the `# public key: age1...` line and the `AGE-SECRET-KEY-...` line. This paper goes in a **different location** from the envelope with your FileVault + Apple ID keys. Then:
```bash
rm -P /tmp/breakglass.key
```

**D3. Configure ~/.zshrc**
```bash
cat >> ~/.zshrc << 'EOF'

ulimit -c 0
setopt HIST_IGNORE_SPACE
export AGE_SE_RECIPIENT="age1se1q..."    # your value from D1
export AGE_BREAKGLASS_RECIPIENT="age1..." # public key from your paper

v() {
  local tmp; tmp=$(mktemp -t vault) && chmod 600 "$tmp"
  trap 'rm -P "$tmp" 2>/dev/null' EXIT INT TERM
  age -d -i ~/.config/age/se.key ~/.vault.age > "$tmp" 2>/dev/null || echo "# new vault" > "$tmp"
  nano "$tmp"   # nano/pico writes no swap, undo, or history files by default
  local recipients=(-r "$AGE_SE_RECIPIENT")
  [[ -n "$AGE_BREAKGLASS_RECIPIENT" ]] && recipients+=(-r "$AGE_BREAKGLASS_RECIPIENT")
  age "${recipients[@]}" -o ~/.vault.age "$tmp"
}
EOF
source ~/.zshrc
```

**D4. Open the vault for the first time**
```bash
v
```
Touch ID fires. Your vault opens. Add your recovery keys from the paper envelope in front of you:
```
[recovery]
filevault_recovery_key = [from paper]
apple_id_recovery_key  = [from paper]

[runbook]
If compromised: pause all agents. Rotate GitHub PAT, Anthropic key, Cloudflare token.
```
Save (`:wq`). Vault re-encrypts automatically.

```bash
# Canary — proves the break-glass paper works at quarterly audit
echo "vault-canary-$(date +%Y-%m-%d)" | \
  age -r "$AGE_SE_RECIPIENT" -r "$AGE_BREAKGLASS_RECIPIENT" -o ~/.vault-canary.age
```

> **What just happened:** your vault exists. It's an encrypted file that opens with your fingerprint and nothing else. The break-glass key on paper means if this Mac is destroyed, you can still decrypt the vault on a new machine. The canary means every quarter you can prove the paper still works. Type `v` any time to open it.

**Celebrate this one.** Both of you type `v`. Watch Touch ID fire. Watch your vault open. This is the moment — your fingerprint is now the only credential you own.

---

### Stage E — GitHub, signed commits, runtimes
*~20 min. After this you can push code.*

**E1. SSH key in Secretive**
Open Secretive → Create key → Ed25519 → name "GitHub" → copy the public key.

```bash
SECRETIVE_PUB="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/$(ls $HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys | head -1)"
```

**E2. Add to GitHub + authenticate**
```bash
gh auth login --web   # browser opens → click Authorize
gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key  # default scopes don't cover key uploads
gh ssh-key add "$SECRETIVE_PUB" --title "$(hostname -s)-$(date +%Y-%m-%d)" --type authentication
gh ssh-key add "$SECRETIVE_PUB" --title "$(hostname -s)-$(date +%Y-%m-%d)-signing" --type signing
gh auth setup-git
```

**E3. Sign every commit**
```bash
git config --global gpg.format ssh
git config --global user.signingkey "$SECRETIVE_PUB"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
mkdir -p ~/.config/git
echo "$(whoami)@$(hostname) $(cat $SECRETIVE_PUB)" >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

**E4. Runtimes + Claude Code**
```bash
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc && source ~/.zshrc
mise use -g node@lts && mise use -g bun@latest && mise use -g python@3.13
command -v claude || npm install -g @anthropic-ai/claude-code
cloudflared tunnel login   # one-time browser prompt; authorises dev tunnels
```

`mise` owns every runtime — node, bun, python. Don't layer `nvm`, `pyenv`, `fnm`, or a global `wrangler` on top. Project lockfiles pin `wrangler`; `bun install` inside a repo pulls the exact version. Two managers fighting over `PATH` is how nights get lost.

---

### Stage F — Everything passes
*The finish line. Run together.*

```bash
fdesetup status                  # FileVault On
v                                # Touch ID → vault opens
ssh -T git@github.com            # Secretive prompt → "Hi username!"
git log --show-signature -1      # verified signature
docker run hello-world           # OrbStack works
claude                           # Claude Code starts
brew doctor && mise doctor       # clean bills of health
```

LuLu opens on first connection attempt — approve: `api.anthropic.com`, `github.com`, `registry.npmjs.org`. Deny anything you don't recognise.

> **What just happened:** every check passed. Your fingerprint signs commits. Your vault holds your secrets. Your outbound connections are monitored. Both Macs are as secure as a personal machine can be without a hardware wallet or dedicated air-gap.

**Celebrate this.** You both built something most developers never have — a machine where no single loss is catastrophic, every key is hardware-backed, and the security model is simple enough that you'll actually follow it.

---

### What you have

| What | Where | If you lose this Mac |
|------|-------|----------------------|
| Passwords, passkeys, TOTP | iCloud Keychain | Restored when you sign into Apple ID on new Mac |
| SSH + git signing | Secretive (SE chip, non-exportable) | Regenerate in Secretive on new Mac, re-add to GitHub |
| Secrets, API keys, runbooks | `~/.vault.age` | Restore from backup, decrypt with break-glass paper |
| FileVault recovery | Paper envelope 1 | Needed if you forget your Mac login password |
| Apple ID recovery | Paper envelope 1 | Needed if Apple locks you out |
| Break-glass vault key | Paper envelope 2 (different location) | Needed to decrypt vault on a new Mac |

**Two envelopes. Different places. Any one of them + this Mac = full recovery. Lose both envelopes AND the Mac = unrecoverable. Keep them apart.**

---

### Stage G — The terminal

*~20 min. Optional but deeply satisfying. This is what other engineers will ask you about.*

A good terminal setup isn't decoration — it's information. At a glance you see: where you are, what branch, whether the working tree is clean, how long the last command took, whether it succeeded. The tools below replace the defaults with faster, cleaner versions that show you more with less noise.

**G1. Ghostty config**

Ghostty reads `~/.config/ghostty/config`. This config uses the one.ie dark palette directly — the same near-blacks, navy, forest green, and pure white that the site uses. Big, clear, modern.

```bash
mkdir -p ~/.config/ghostty
cat > ~/.config/ghostty/config << 'EOF'
# Font — Monaspace Neon: GitHub's monospace, ligatures, four optical sizes
font-family            = "Monaspace Neon"
font-size              = 15
font-feature           = calt, liga, ss01, ss02, ss03, ss04, ss05

# one.ie dark palette
# background: hsl(0 0% 10%) — card surface
# foreground: hsl(0 0% 13%) — content area
# font:       hsl(0 0% 100%) — pure white
# primary:    hsl(216 55% 25%) — navy blue
# tertiary:   hsl(105 22% 25%) — forest green

background             = #191919
foreground             = #ffffff
cursor-color           = #1d3963
cursor-style           = bar
cursor-blink           = true
selection-background   = #1d3963
selection-foreground   = #ffffff

# ANSI 16 — mapped to one.ie palette
palette = 0=#191919
palette = 1=#c0392b
palette = 2=#394e32
palette = 3=#8a6914
palette = 4=#1d3963
palette = 5=#4a3560
palette = 6=#2c4a5a
palette = 7=#d4d4d4
palette = 8=#2d2d2d
palette = 9=#e74c3c
palette = 10=#4d6b40
palette = 11=#d4a017
palette = 12=#2d5a8e
palette = 13=#7d5c9f
palette = 14=#3d6b80
palette = 15=#ffffff

# Window
background-opacity          = 0.96
window-padding-x            = 14
window-padding-y             = 10
macos-titlebar-style        = hidden
macos-option-as-alt         = true
mouse-hide-while-typing     = true
shell-integration-features  = cursor,sudo,title
EOF
```

Restart Ghostty. View → Secure Keyboard Entry → On.

> View → Secure Keyboard Entry → On. Do this every time you open a new terminal.

**G2. Starship prompt**

One command, reads your project, shows exactly what you need — nothing more.

```bash
mkdir -p ~/.config
cat > ~/.config/starship.toml << 'EOF'
# one.ie palette — same tokens as design.astro dark mode
# navy  #2d5a8e  (primary hsl 216 55% 25% — lighter for readability on black)
# green #4d6b40  (tertiary hsl 105 22% 25% — bright variant)
# red   #e74c3c  (errors)
# amber #d4a017  (durations, warnings)
# dim   #666666  (time, metadata)

format = """
$directory$git_branch$git_status$nodejs$bun$python$rust$golang
$character"""

[directory]
style             = "bold #2d5a8e"
truncation_length = 3
truncate_to_repo  = true
read_only         = " 󰌾"

[git_branch]
format = "[ $branch]($style) "
style  = "bold #4d6b40"

[git_status]
format    = "([$all_status$ahead_behind]($style) )"
style     = "bold #e74c3c"
ahead     = "⇡$count"
behind    = "⇣$count"
diverged  = "⇕⇡$ahead_count⇣$behind_count"
modified  = "!$count"
untracked = "?$count"
staged    = "+$count"
deleted   = "✘$count"

[character]
success_symbol = "[❯](bold #2d5a8e)"
error_symbol   = "[❯](bold #e74c3c)"

[nodejs]
format = "[ $version]($style) "
style  = "bold #4d6b40"

[bun]
format = "[ $version]($style) "
style  = "bold #4d6b40"

[python]
format = "[$version ]($style)"
style  = "bold #4d6b40"
symbol = " "

[rust]
format = "[ $version]($style) "
style  = "bold #e74c3c"

[golang]
format = "[ $version]($style) "
style  = "bold #2d5a8e"

[cmd_duration]
format   = "[ $duration]($style) "
style    = "bold #d4a017"
min_time = 2_000

[time]
disabled     = false
format       = "[$time]($style) "
style        = "dimmed #666666"
time_format  = "%H:%M"
EOF
```

**G3. zsh — the complete shell config**

Append to `~/.zshrc` (below the security block already there):

```bash
cat >> ~/.zshrc << 'EOF'

# --- Shell quality of life ---

# Plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zoxide — learns where you go, replaces cd
eval "$(zoxide init zsh --cmd cd)"

# fzf — fuzzy finder: Ctrl+R for history, Ctrl+T for files
source <(fzf --zsh)

# Starship prompt
eval "$(starship init zsh)"

# --- Better defaults ---

# eza replaces ls
alias ls='eza --icons --group-directories-first --color=always'
alias ll='eza --icons --group-directories-first --color=always -la --git'
alias lt='eza --icons --tree --level=2 --color=always'

# bat replaces cat — syntax highlighting, git diff markers
alias cat='bat --style=plain --paging=never'

# Git shortcuts
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline -15 --graph --decorate'
alias gd='git diff'
alias lg='lazygit'

# Useful
alias reload='source ~/.zshrc && echo "reloaded"'
alias path='echo $PATH | tr ":" "\n"'
EOF
source ~/.zshrc
```

**G4. Beautiful git diffs with delta**

```bash
git config --global core.pager 'delta'
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global delta.line-numbers true
git config --global delta.syntax-theme 'base16'
```

Now `git diff` and `git log -p` look like a proper code editor.

**G5. Verify it all feels right**

```bash
# Should show the Starship prompt with git info
cd ~/  &&  mkdir /tmp/test-repo && cd /tmp/test-repo && git init && touch file.ts
# prompt should show: ~/t/test-repo  main  ?1  ❯

# ls with icons and git status
ls

# history search
# press Ctrl+R — fzf fuzzy history search opens

# navigate
cd /tmp && cd ~/   # zoxide learns these
z tmp              # jumps to /tmp — type less, go anywhere

# git diff
# make a change to any file, run: git diff
# delta renders it beautifully

# lazygit
lg   # full TUI git client — q to quit
```

> **What just happened:** your terminal now tells you everything you need at a glance. `autosuggestions` shows your history as grey text — press → to accept. `syntax-highlighting` colours commands red (invalid) or green (valid) as you type. `zoxide` means you never type a full path again. `delta` means git diffs are readable. `lazygit` means you can manage branches, stage hunks, and resolve conflicts without leaving the terminal.

**Other engineers will ask what your setup is. Tell them it's all in a `.zshrc` they can copy.**
