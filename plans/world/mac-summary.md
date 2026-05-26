# mac-summary — what this Mac is, in plain English

One page. What it protects, how it works, what you get, how to use it.

---

## What it protects

| Threat | What stops it |
|---|---|
| Someone steals the Mac | Whole-disk encryption (FileVault). The disk is gibberish without your password. |
| Someone forgets your password *(you)* | Paper recovery keys. Two papers, two different places. |
| Malware reaches for the internet | Firewall + stealth mode. Apps ask permission; you approve them once. |
| Impersonation on GitHub | Every commit is cryptographically signed by a key that lives in the Mac's Secure Enclave. Nobody can forge "from Tony". |
| Stolen SSH key | The SSH key never leaves the Secure Enclave chip. There is no file to steal. |
| Typed sudo password leaked by keylogger | Touch ID replaces password prompts for `sudo`. |
| Bad actor trying to change your Apple ID recovery | Stolen Device Protection: new devices can't edit recovery for a week. |
| Secrets leaking into `.swp` / history / swap / core dumps | Vault opens only into a 600-mode tmp file; `nano` writes no swap or history; core dumps disabled; FileVault covers what's left. |
| You lose this Mac completely | Paper 2 (break-glass key) decrypts your vault on any new Mac. |

---

## How it works — layered, each layer standalone

1. **Hardware root** — the Mac's Secure Enclave chip holds keys that never leave it. Your fingerprint is the only way to use them. You can't copy it, exfiltrate it, or convince it to sign without a finger on the sensor.
2. **Disk encryption** — FileVault turns the whole disk into ciphertext at rest. Recovery key is on paper.
3. **Vault (`~/.vault.age`)** — a single encrypted file that contains your recovery keys, runbook, and agent notes. Encrypted twice: to the Secure Enclave (fingerprint opens it) and to a paper key (only used if the Mac is gone).
4. **SSH + git signing** — every outbound connection and every commit gets authenticated with the Secure Enclave key via Secretive. GitHub sees "verified, from Tony's Mac".
5. **Paper fallback** — if the Mac or Apple ID is ever lost, two pieces of paper bring everything back. One paper lost = annoying. Both lost = gone forever.

Each layer works alone. No single compromise cascades.

---

## Benefits

- **You own your keys.** No third-party password manager, no cloud-hosted vault, no "trust us". The chip on the board + the paper in your drawer are the whole trust chain.
- **Non-transferable security.** Your fingerprint is physics, not policy. Nobody can phish it, copy it, or coerce it remotely.
- **Proof of authorship.** Every commit is signed. When you (or someone reading your code later) checks git log, "verified" means it really was you on this Mac.
- **Fast daily use.** Touch ID replaces password typing for the things you do every day — sudo, ssh, git, vault.
- **Recovery is real.** You can prove the recovery path works every 3 months without calling anyone.
- **Paranoid when you want it, invisible when you don't.** Siri, Safari suggestions, short idle timer — all still on. Security only kicks in where it buys something.

---

## How to use it — day to day

**Open your vault:**
```
v
```
Touch ID → nano opens the file → edit → `Ctrl-O` save, `Ctrl-X` quit → Touch ID re-seals.

**Make a signed commit:**
```
git commit -m "message"
```
Secretive prompts once per session, Touch ID fires, commit is signed. GitHub shows "Verified".

**SSH anywhere:**
```
ssh user@server
```
Secretive prompts, Touch ID fires, connection authenticated. No password, no key file on disk.

**Sudo without typing a password:**
```
sudo anything
```
Touch ID instead of password prompt.

**Switch runtime versions per project:**
```
mise use node@20    # this project uses node 20
mise use python@3.12
```

**Start a new repo — signed from commit #1:**
```
git init . && git add -A && git commit -m "init"
```
Already signed. No extra setup per project.

---

## How to apply it — broader

**For building on one.ie / agents / Sui wallets:**
The Mac's Secure Enclave identity is the "human root" — the thing agents can't fake. When you spawn an agent, it gets its own scoped wallet under caps *you* set with one Touch ID. The agent can then spawn its own sub-agents, pay for tools, or work overnight, but it can never touch the caps — only your finger can. See `agents.md` Pattern D.

**For every other secret** (website logins, team repo creds, personal root keys):
Three stores, one job each. iCloud Keychain for browser autofill. dotenvx for team repo env vars. Your vault for everything else. Decision rule is 2 seconds, 3 questions. Full spec: `secrets.md`.

**For sensitive work on other machines:**
Your vault holds the canonical copy of every personal root credential. On a new or temporary machine, use SSH (through Secretive) and age-encrypted scratch files. Never copy the SE key off this Mac — there's no need to; SSH does the work remotely.

**For someone joining your workflow:**
Give them `mac.md` (the architecture) + `mac-agent.md` (the step-by-step) and they can reproduce this setup on their own Mac in about 2 hours. No secrets in the docs — just the pattern.

**For quarterly health checks:**
Run `v`. Find both papers. Decrypt the canary with Paper 2. If any of those fails, everything else is theatre.

---

## The shape of it, in one paragraph

Your fingerprint unlocks a chip that signs commits, opens SSH connections, and decrypts your vault. Everything else — password manager replacements, recovery flows, agent wallets — builds on that single root. If the Mac survives, your fingerprint gets you in. If the Mac dies, two pieces of paper get you back. If both papers burn, nothing else matters; so don't let both papers burn.

---

## Where to look when something breaks or you want to extend

- **Use it** — you're using it now. `v`, `git commit`, `ssh` — that's the daily surface.
- **Change something** — `mac-agent.md` (the skill) has every command, safe to re-run, resumes where it left off.
- **Understand a decision** — `mac.md` (the architecture) has the threat model row for every piece.
- **Apply it to agents** — `agents.md` for the four human↔agent patterns.
- **Next check** — 2026-07-22. Five minutes.
