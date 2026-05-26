# mac-agent — Claude skill for safe Mac setup

When the user says "set up my Mac" or "run mac-agent", follow this skill exactly.

**Principle:** value first, then protect it. Get everything working so the person understands what they're securing. The only exception is FileVault — that key must be written immediately when FileVault is enabled, because forgetting your Mac password before writing it down locks you out forever. Everything else waits until the end, when the person has felt their vault open, their commits sign, and their GitHub authenticate. Then we ask them to write two pieces of paper. They'll understand why.

**Bias:** balance ease and security. Only disable a feature if it's genuinely attack surface (firewall, AirDrop-to-everyone, unsigned commits). Don't nuke conveniences (Siri, Safari search suggestions, short idle timers) reflexively — each costs daily friction and buys little. When in doubt, keep the default on and let the user tighten later.

**Three human moments, in order:**
1. ⏸ FileVault key — written at the moment it's generated (unavoidable — 30 seconds)
2. ⏸ Browser click — `gh auth login` (unavoidable — 30 seconds)
3. ⏸ Papers at the end — after everything works (the moment that matters — 5 minutes)

Everything else runs as commands.

**Safe to re-run** — every step checks state before acting. If interrupted, restart from the top.

---

## Resume checkpoint (this machine — Mac "Anthonys-MacBook-Air", user `toc`, 2026-04-22)

If you're a fresh Claude conversation, run the Phase 1 scan first — it will reconfirm reality. The state below is recorded only so you can skip what's already done.

**Done:**
- Phase 2 full: firewall + stealth on, auto-updates on, Touch ID for sudo, screen-lock password immediate, 10-min idle, AirDrop Contacts Only
- FileVault ON, personal recovery key rotated once (an earlier one was burned by being pasted into chat), validated against paper, and now stored in the vault `[recovery]` section
- Phase 3 full: Homebrew + analytics off; CLI tools installed (age, age-plugin-se, mise, gh, git, starship, jq, rg, fd, uv, cloudflared, sui, zoxide, eza, bat, delta, fzf, lazygit); apps installed (Secretive, BlockBlock Helper, LuLu, Ghostty, Zed, OrbStack, Tailscale, Mullvad VPN)
- Phase 4 full: SE key at `~/.config/age/se.key` (access-control `current-biometry`); `~/.zshrc` has `AGE_SE_RECIPIENT`, `AGE_BREAKGLASS_RECIPIENT=""` placeholder, `ulimit -c 0`, `HIST_IGNORE_SPACE`, `v()` function (**nano, not vim** — see bug list below); `~/.vault.age` contains FileVault recovery key under `[recovery]`, encrypted to SE only
- `.zprofile`: `eval "$(/opt/homebrew/bin/brew shellenv)"`; duplicated PATH lines in `.zshrc` cleaned up
- Phase 5a–c: Secretive GitHub key created (ecdsa-sha2-nistp256, SE-backed, SHA256:dYic/8On0Fqvfs8f5sJEZCYfqcFQsoi70ysMxe6+sn4); public key file `~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/0e4585a11c2080893478c7fc7da85cbf.pub`; `~/.ssh/config` has Secretive IdentityAgent; `gh auth` authenticated as `tonyoconnell` with `admin:public_key` + `admin:ssh_signing_key` scopes; both auth + signing keys uploaded to GitHub; `gh auth setup-git` done; git global config: `user.name="Tony O'Connell"`, `user.email="tony@one.ie"`, `gpg.format=ssh`, `commit.gpgsign=true`, `tag.gpgsign=true`, `user.signingkey=<ecdsa pubkey inline>`, `gpg.ssh.allowedSignersFile=~/.config/git/allowed_signers`; `~/.config/git/allowed_signers` has `tony@one.ie` + pubkey; `ssh -T git@github.com` greeted "Hi tonyoconnell" after Touch ID; GitHub host key accepted into `~/.ssh/known_hosts` (ED25519 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU — published value)
- Phase 5d: `eval "$(mise activate zsh)"` in `.zshrc`; mise installed node v24.15.0, bun 1.3.13, python 3.13.13 globally; Claude Code already present as `claude 2.1.117`
- Phase 6 verification: all 18 checks pass
- Phase 7: Ghostty config (`~/.config/ghostty/config`), Starship (`~/.config/starship.toml`), zsh QoL block appended (autosuggestions/syntax-highlighting/zoxide/fzf/starship/aliases), delta configured as git pager
- Phase 8: **complete.** Apple ID Recovery Key generated on iPhone (Mac blocked by Stolen Device Protection new-device delay until 2026-04-28; iPhone is the intended path — Apple says so in the SDP dialog). Break-glass age key generated, written on paper in separate location from Paper 1, secret wiped from `/tmp/breakglass.key` via `rm -P`, public key `age15gd3rn6cs84fpemndvd72ep42gpu2mhpmemq6sz3s04qr2ctju3sw06nzk` exported as `AGE_BREAKGLASS_RECIPIENT` in `.zshrc`. Vault re-encrypted to both recipients (verified: piv-p256 + X25519 stanzas). `~/.vault-canary.age` created for quarterly audit. Apple ID Recovery Key also inside `.vault.age`.

**Mac setup complete.** Quarterly audit: run `v` to prove SE still opens; separately `age -d -i <paper-key-typed-into-file> ~/.vault-canary.age` to prove break-glass paper still works; physically locate both papers.

**Known-fixed bugs in earlier skill versions** — if you see these in git blame, they're resolved:
- `remko/tap/age-plugin-se` (404) → `age-plugin-se` in homebrew-core
- `--access-control=biometry-current` → `current-biometry`
- `grep "recipient" ~/.config/age/se.key` → `grep "public key:" ~/.config/age/se.key`
- `socketfilterfw --setloggingmode on` removed — flag no longer exists on recent macOS
- **`v()` used `vim` — most users don't know vim.** Swapped to `nano` (friendlier: arrow keys, Ctrl-O save, Ctrl-X exit). Tried `nano -R` (restricted mode) first but `nano` on macOS is pico-compatible and doesn't accept `-R`; bare `nano` works. Consider installing GNU nano via brew if restricted-mode matters.
- **`gh auth login --web` doesn't grant `admin:public_key` or `admin:ssh_signing_key` scopes by default.** After login, run: `gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key` before `gh ssh-key add`. Skill doc should prepend this to Phase 5a.
- Secretive needs manual first-launch (Applications → Secretive) before its `Data/PublicKeys` dir exists; skill should tell user to open the app explicitly.
- **`v()` encrypted to `$AGE_SE_RECIPIENT` only, silently stripping break-glass on every save.** Fixed to conditional: builds recipient array from SE, appends break-glass only if `$AGE_BREAKGLASS_RECIPIENT` is non-empty. Handles both phase-4-only-SE and phase-8-onwards-both states.
- **Apple Stolen Device Protection blocks Mac from editing Apple ID recovery settings for ~1 week after the Mac first appears as a signed-in device.** The SDP dialog explicitly says "To manage your recovery key now, use your other Apple devices." Skill should tell the user to generate the Apple ID Recovery Key on their iPhone; do NOT suggest disabling SDP.

**Pasted-secret lesson** — if the user pastes any key/password/token into chat, it's burned. Rotate immediately (`sudo fdesetup changerecovery -personal` for FileVault; equivalent rotate for others), write the new one on paper only, and verify with `validaterecovery` typed into the terminal (not chat). Never ask for secrets to be pasted here.

---

## Phase 1 — Scan

Run first. Report ✓ done and ✗ missing. Do not fix yet — just show the full picture.

```bash
echo "=== SCAN ===" && echo ""
fdesetup status
csrutil status
spctl --status
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "firewall: check manually"
xcode-select -p 2>/dev/null && echo "CLT: ok" || echo "CLT: missing"
command -v brew &>/dev/null && echo "brew: $(brew --version | head -1)" || echo "brew: missing"
command -v age &>/dev/null && echo "age: ok" || echo "age: missing"
command -v age-plugin-se &>/dev/null && echo "age-plugin-se: ok" || echo "age-plugin-se: missing"
[ -f ~/.config/age/se.key ] && echo "SE key: ok" || echo "SE key: missing"
[ -f ~/.vault.age ] && echo "vault: ok" || echo "vault: missing"
ls ~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent &>/dev/null && echo "secretive: ok" || echo "secretive: missing"
command -v mise &>/dev/null && echo "mise: ok" || echo "mise: missing"
command -v gh &>/dev/null && echo "gh: ok" || echo "gh: missing"
gh auth status 2>/dev/null && echo "gh auth: ok" || echo "gh auth: missing"
node --version 2>/dev/null && echo "node: ok" || echo "node: missing"
bun --version 2>/dev/null && echo "bun: ok" || echo "bun: missing"
command -v claude &>/dev/null && echo "claude: ok" || echo "claude: missing"
```

Say to the user: *"Here's where we are. I'll work through each phase. Skip anything that's already done."*

---

## Phase 2 — Security baseline (all commands, no human needed)

### 2a. Firewall, stealth mode, auto-updates
```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
sudo softwareupdate --schedule on
# Note: --setloggingmode was removed in recent macOS; firewall logging is always on by default now.
```

### 2b. Lock screen + AirDrop

Only what buys real security at zero ease cost. Siri and Safari suggestions stay on — they're conveniences, not attack surface worth the trade. If the user wants tighter privacy later, they can flip those individually.

```bash
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
defaults -currentHost write com.apple.screensaver idleTime 600
defaults write com.apple.sharingd DiscoverableMode -string "Contacts Only"
```

- Password required immediately after sleep/screensaver (pure win)
- 10-min idle screensaver (5 min is annoying at home; adjust if the user wants stricter)
- AirDrop → Contacts Only (real CVE history, zero ease cost)

### 2c. Touch ID for sudo
```bash
if ! grep -q "pam_tid" /etc/pam.d/sudo_local 2>/dev/null; then
  sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
  sudo sed -i '' 's/#auth/auth/' /etc/pam.d/sudo_local
  echo "Touch ID for sudo: enabled"
else
  echo "Touch ID for sudo: already on"
fi
```

### 2d. Xcode CLT
```bash
if ! xcode-select -p &>/dev/null; then
  xcode-select --install
  echo "Click Install in the dialog. Come back when it finishes."
  # wait for user confirmation before continuing
else
  echo "CLT: $(xcode-select -p)"
fi
```

---

## ⏸ PAUSE 1 — FileVault (one key, right now)

Check:
```bash
fdesetup status
```

If already on — skip ahead.

If off, tell the user:

> "One thing before we install anything. Open **System Settings → Privacy & Security → FileVault → Turn On**.
>
> Choose **'Create a recovery key, do not use iCloud'**.
>
> A key appears on screen. **Write it on paper right now.** Don't photograph it. Don't paste it anywhere. Just write it.
>
> Then restart when macOS asks. Come back after the restart — encryption runs in the background, you don't need to wait."

Also: System Settings → Touch ID & Password → make sure at least one fingerprint is enrolled. Touch ID is the gate to everything.

Wait for confirmation: FileVault is on and the key is written.

---

## Phase 3 — Install everything (parallel)

### 3a. Homebrew
```bash
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew analytics off
brew update
echo "Homebrew: $(brew --version | head -1)"
```

### 3b. All tools — three parallel background shells

Run these as three `run_in_background` Bash calls so brew parallelises. Wait for all three to finish before continuing. No human needed.

**Group 1 — security tools:**
```bash
brew install age age-plugin-se lulu && \
brew install --cask secretive blockblock
```
Note: `age-plugin-se` is in homebrew-core as of 2025. The old `remko/tap` is a 404 — don't use it.

**Group 2 — dev tools + shell QoL:**
```bash
brew install mise gh git starship jq ripgrep fd uv cloudflared sui && \
brew install zsh-autosuggestions zsh-syntax-highlighting zoxide eza bat git-delta fzf lazygit && \
brew install --cask ghostty zed orbstack font-monaspace-nerd-font
```

**Group 3 — network:**
```bash
brew install --cask tailscale mullvad-vpn
```

Wait for all three groups to complete before continuing.

### 3c. Verify age-plugin-se before trusting it
```bash
brew info age-plugin-se | grep -E "sha|SHA|homepage"
```
`age-plugin-se` ships in homebrew-core (formulae are reviewed + bottled by Homebrew); this raises the bar versus a third-party tap. Still, tell the user: *"This plugin guards your vault. If you want belt-and-braces, cross-check the installed version at `/opt/homebrew/Cellar/age-plugin-se/<ver>` against the signed release at github.com/remko/age-plugin-se/releases."*

---

## Phase 4 — SE identity + vault (the person feels this working)

### 4a. SE key
```bash
if [ ! -f ~/.config/age/se.key ]; then
  mkdir -p ~/.config/age && chmod 700 ~/.config/age
  age-plugin-se keygen --access-control=current-biometry --output ~/.config/age/se.key
  chmod 600 ~/.config/age/se.key
  echo "SE key created."
else
  echo "SE key already exists."
fi
SE_RECIPIENT=$(grep "public key:" ~/.config/age/se.key | awk '{print $NF}')
echo "SE recipient: $SE_RECIPIENT"
```

### 4b. Configure ~/.zshrc
```bash
if ! grep -q "AGE_SE_RECIPIENT" ~/.zshrc; then
  SE_RECIPIENT=$(grep "public key:" ~/.config/age/se.key | awk '{print $NF}')
  cat >> ~/.zshrc << EOF

# Age / vault (break-glass recipient added in final phase)
export AGE_SE_RECIPIENT="$SE_RECIPIENT"
export AGE_BREAKGLASS_RECIPIENT=""

ulimit -c 0
setopt HIST_IGNORE_SPACE

v() {
  local tmp; tmp=\$(mktemp -t vault) && chmod 600 "\$tmp"
  trap 'rm -P "\$tmp" 2>/dev/null' EXIT INT TERM
  age -d -i ~/.config/age/se.key ~/.vault.age > "\$tmp" 2>/dev/null || echo "# new vault" > "\$tmp"
  nano "\$tmp"   # friendlier than vim; macOS ships pico-compat so no -R flag
  local recipients=(-r "\$AGE_SE_RECIPIENT")
  [[ -n "\$AGE_BREAKGLASS_RECIPIENT" ]] && recipients+=(-r "\$AGE_BREAKGLASS_RECIPIENT")
  age "\${recipients[@]}" -o ~/.vault.age "\$tmp"
}
EOF
  source ~/.zshrc
  echo ".zshrc configured."
else
  echo ".zshrc already configured."
fi
```

Note: vault is initially encrypted to SE only. Break-glass recipient is added in the final phase after the key is generated and the person understands what it's for.

### 4c. Create vault
```bash
if [ ! -f ~/.vault.age ]; then
  SE_RECIPIENT=$(grep "public key:" ~/.config/age/se.key | awk '{print $NF}')
  TMPVAULT=$(mktemp -t vault) && chmod 600 "$TMPVAULT"
  cat > "$TMPVAULT" << 'EOF'
# vault

[recovery]
filevault_recovery_key =
apple_id_recovery_key  =
offsite_backup_key     =

[runbook]
If Mac is compromised: pause all agents, rotate GitHub PAT + Anthropic key + Cloudflare token.

[agents]
# one section per agent — added when agents are created
EOF
  age -r "$SE_RECIPIENT" -o ~/.vault.age "$TMPVAULT"
  rm -P "$TMPVAULT"
  echo "Vault created."
fi
```

### 4d. Let them feel it

```bash
echo "Opening vault — Touch ID will fire..."
v
```

Tell the user: *"Type `v` in your terminal. Touch ID fires. Your vault opens. This is yours — nobody else can open it. Add the FileVault recovery key you wrote on paper into the [recovery] section now, while the paper is in front of you."*

Wait for them to save and close the vault.

---

## Phase 5 — SSH, GitHub, runtimes

### 5a. SSH key in Secretive

Tell the user:
> "Open Secretive from Applications (first launch creates its data dir). Click **+** in the top right. Name: 'GitHub'. Type: Ed25519 (or ECDSA p256 — both SE-backed). Require authentication: yes. Save."

Wait for the key to appear in Secretive's list.

Also wire SSH to route through Secretive's agent:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if ! grep -q "com.maxgoedjen.Secretive" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config << 'EOF'
Host *
    IdentityAgent /Users/$USER/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
EOF
  chmod 600 ~/.ssh/config
fi

SECRETIVE_DIR="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys"
SECRETIVE_PUB="$SECRETIVE_DIR/$(ls $SECRETIVE_DIR | head -1)"
echo "Public key: $(cat $SECRETIVE_PUB)"
```

### ⏸ PAUSE 2 — GitHub login (one browser click)

```bash
gh auth login --web
# After login, refresh scopes so we can upload SSH keys — default scopes don't include these:
gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key
```

Tell the user: *"Two browser rounds: first to authorize gh itself, then to grant SSH-key scopes. Both show 8-char one-time codes."*

After login:
```bash
gh ssh-key add "$SECRETIVE_PUB" --title "$(hostname -s)-$(date +%Y-%m-%d)" --type authentication
gh ssh-key add "$SECRETIVE_PUB" --title "$(hostname -s)-$(date +%Y-%m-%d)-signing" --type signing
gh auth setup-git
echo "SSH key added to GitHub."
```

### 5b. Configure git signing
```bash
git config --global gpg.format ssh
git config --global user.signingkey "$SECRETIVE_PUB"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
mkdir -p ~/.config/git
echo "$(whoami)@$(hostname) $(cat $SECRETIVE_PUB)" >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

Ask the user for their name and email, then:
```bash
git config --global user.name "Name here"
git config --global user.email "email here"
```

### 5c. Let them feel it
```bash
ssh -T git@github.com
```
Secretive prompts. Touch ID fires. GitHub says "Hi username!" — they've just felt their first Touch ID authenticated git operation. Agents spawning on this Mac work the same way: Touch ID fires once, then the agent runs within its rules—and can spawn sub-agents under those caps with no further Touch ID.

### 5d. Runtimes + Claude Code
```bash
if ! grep -q "mise activate" ~/.zshrc; then
  echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
fi
source ~/.zshrc

mise use -g node@lts
mise use -g bun@latest
mise use -g python@3.13

if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi

echo "Node: $(node --version)"
echo "Bun: $(bun --version)"
echo "Claude: $(claude --version 2>/dev/null || echo 'installed')"
```

---

## Phase 6 — Verification (everything must pass before terminal + papers)

Run this. Everything must be ✓. Fix any ✗ before continuing to the final phase.

```bash
echo ""
echo "=== VERIFICATION ==="
echo ""

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1 — fix before continuing"; }

fdesetup status | grep -q "On" && pass "FileVault on" || fail "FileVault OFF"
csrutil status | grep -q "enabled" && pass "SIP enabled" || fail "SIP disabled"
spctl --status | grep -q "enabled" && pass "Gatekeeper on" || fail "Gatekeeper off"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled" && pass "Firewall on" || fail "Firewall off"
grep -q "pam_tid" /etc/pam.d/sudo_local 2>/dev/null && pass "Touch ID for sudo" || fail "Touch ID for sudo missing"
[ -f ~/.config/age/se.key ] && pass "SE key present" || fail "SE key missing"
[ -f ~/.vault.age ] && pass "Vault present" || fail "Vault missing"
command -v age-plugin-se &>/dev/null && pass "age-plugin-se installed" || fail "age-plugin-se missing"
command -v mise &>/dev/null && pass "mise installed" || fail "mise missing"
command -v gh &>/dev/null && pass "gh installed" || fail "gh missing"
gh auth status &>/dev/null && pass "GitHub authenticated" || fail "GitHub not authenticated"
# SSH test requires user to accept GitHub host key on first run (yes/no prompt) — may fail here if not pre-accepted; skip in automated verify
[ -f ~/.ssh/known_hosts ] && grep -q "github.com" ~/.ssh/known_hosts && pass "GitHub host key pinned" || fail "ssh -T git@github.com — accept the host key prompt"
# Runtimes via mise shims — activate in case this subshell hasn't inherited it
eval "$(mise activate zsh)" 2>/dev/null
mise x -- node --version &>/dev/null && pass "Node $(mise x -- node --version)" || fail "Node missing"
mise x -- bun --version &>/dev/null && pass "Bun $(mise x -- bun --version)" || fail "Bun missing"
command -v claude &>/dev/null && pass "Claude Code installed" || fail "Claude Code missing"
git config --global --get commit.gpgsign | grep -q true && pass "Git commit signing on" || fail "Git commit signing off"
git config --global --get gpg.format | grep -q ssh && pass "Git signing format=ssh" || fail "Git signing format wrong"

echo ""
```

---

## Phase 7 — Terminal (Ghostty, Starship, zsh, delta)

All idempotent writes. No human needed. Place before papers so the papers stay the emotional peak.

### 7a. Ghostty config
```bash
mkdir -p ~/.config/ghostty
cat > ~/.config/ghostty/config << 'EOF'
font-family            = "Monaspace Neon"
font-size              = 15
font-feature           = calt, liga, ss01, ss02, ss03, ss04, ss05

background             = #191919
foreground             = #ffffff
cursor-color           = #1d3963
cursor-style           = bar
cursor-blink           = true
selection-background   = #1d3963
selection-foreground   = #ffffff

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

background-opacity          = 0.96
window-padding-x            = 14
window-padding-y            = 10
macos-titlebar-style        = hidden
macos-option-as-alt         = true
mouse-hide-while-typing     = true
shell-integration-features  = cursor,sudo,title
EOF
```

### 7b. Starship prompt
```bash
mkdir -p ~/.config
cat > ~/.config/starship.toml << 'EOF'
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

### 7c. zsh QoL block
```bash
if ! grep -q "zsh-autosuggestions" ~/.zshrc; then
  cat >> ~/.zshrc << 'EOF'

# --- Shell quality of life ---
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(zoxide init zsh --cmd cd)"
source <(fzf --zsh)
eval "$(starship init zsh)"

alias ls='eza --icons --group-directories-first --color=always'
alias ll='eza --icons --group-directories-first --color=always -la --git'
alias lt='eza --icons --tree --level=2 --color=always'
alias cat='bat --style=plain --paging=never'
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline -15 --graph --decorate'
alias gd='git diff'
alias lg='lazygit'
alias reload='source ~/.zshrc && echo "reloaded"'
alias path='echo $PATH | tr ":" "\n"'
EOF
fi
source ~/.zshrc
```

### 7d. delta for git diffs
```bash
git config --global core.pager 'delta'
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global delta.line-numbers true
git config --global delta.syntax-theme 'base16'
```

Tell the user: *"Open a fresh Ghostty window. View → Secure Keyboard Entry → On. Your prompt now shows directory, git branch, runtime versions, and command duration."*

---

## ⏸ PAUSE 3 — Papers (now you know what you're protecting)

Everything is working. They've opened the vault with Touch ID. They've pushed a signed commit. They've seen GitHub authenticate. Now they understand what they'd lose.

Say to the user:

> "Your Mac is working. Your vault opens with your fingerprint. Your commits are signed. Your GitHub is authenticated.
>
> Now we make it recoverable. Two pieces of paper. Five minutes."

**Paper 1 — Apple ID Recovery Key**

Prefer Mac path:
> "System Settings → Apple ID → Sign-In & Security → Account Recovery → Recovery Key → Turn On. Apple generates a 28-char key. Write it on paper. Apple will ask you to confirm. While you're here, enable Advanced Data Protection if not already (iCloud → Advanced Data Protection)."

**If Stolen Device Protection blocks with a multi-day delay** ("…cannot be used to edit your account information until …"), do it on iPhone instead: *Settings → [your name] → Sign-In & Security → Account Recovery → Recovery Key*. Apple's SDP dialog literally points you at your other Apple devices. **Never** suggest turning SDP off — it's real security.

Wait for confirmation Paper 1 is written.

**Paper 2 — Break-glass vault key** (separate location from Paper 1)

Generate the key. `age-keygen -o <file>` writes the secret to the file and prints only the public key to stderr — safe for us to capture:
```bash
age-keygen -o /tmp/breakglass.key 2>&1 | tee /tmp/breakglass.pub.log
BREAKGLASS=$(grep "^Public key:" /tmp/breakglass.pub.log | awk '{print $NF}')
rm -f /tmp/breakglass.pub.log
ls -la /tmp/breakglass.key
echo "Captured break-glass public key: $BREAKGLASS"
```

Tell the user — in **their own terminal**, not pasting here:
```
cat /tmp/breakglass.key
```
*"Write both lines on paper: the `# public key: age1…` line AND the `AGE-SECRET-KEY-1…` line. Different physical location from Paper 1. Do NOT paste the secret line into chat — if you do, we rotate."*

Wait for confirmation both lines are on paper.

```bash
rm -P /tmp/breakglass.key
echo "Break-glass secret wiped from /tmp."

# Wire public key into .zshrc
sed -i '' "s|export AGE_BREAKGLASS_RECIPIENT=\"\"|export AGE_BREAKGLASS_RECIPIENT=\"$BREAKGLASS\"|" ~/.zshrc

# Re-encrypt vault to SE + break-glass (Touch ID fires on decrypt)
SE_RECIPIENT=$(grep "public key:" ~/.config/age/se.key | awk '{print $NF}')
TMPVAULT=$(mktemp -t vault) && chmod 600 "$TMPVAULT"
trap 'rm -P "$TMPVAULT" 2>/dev/null' EXIT
age -d -i ~/.config/age/se.key ~/.vault.age > "$TMPVAULT"
age -r "$SE_RECIPIENT" -r "$BREAKGLASS" -o ~/.vault.age "$TMPVAULT"

# Canary for quarterly audit (decrypting it with the paper key proves the paper still works)
echo "vault-canary-$(date +%Y-%m-%d)" | \
  age -r "$SE_RECIPIENT" -r "$BREAKGLASS" \
  -o ~/.vault-canary.age

rm -P "$TMPVAULT"

# Verify — should show 2 recipient stanzas
echo "Vault recipients: $(strings ~/.vault.age | grep -cE '^-> ')  (expect 2)"
```

Open vault so they can paste in the Apple ID Recovery Key they wrote on Paper 1. **Tell the user to `exec zsh` first** so the updated `AGE_BREAKGLASS_RECIPIENT` is in scope for the `v()` function:
```bash
exec zsh
v
```

Tell the user: *"Add your Apple ID Recovery Key under `[recovery] apple_id_recovery_key = …`. Ctrl-O, Enter, Ctrl-X. Touch ID fires to re-seal. Because `v()` uses conditional recipients, this save keeps both SE and break-glass."*

---

## Done

Tell the user:

> "You're set up. Here's what you have:
>
> **What works:**
> - Touch ID opens your vault
> - Touch ID signs every commit
> - Touch ID authenticates to GitHub
> - All your dev tools are installed
>
> **What's on paper (keep in two separate places):**
> - Paper 1: FileVault key + Apple ID Recovery Key
> - Paper 2: Break-glass vault key
>
> **If you lose the Mac:**
> New Mac → sign into Apple ID → restore from backup → use break-glass paper to decrypt old vault → rebuild SE identity → done.
>
> **Quarterly audit (~3 months):**
> 1. Run `v` — Touch ID opens the vault. Proves SE still works.
> 2. Physically locate Paper 1 and Paper 2 in their separate locations.
> 3. (Stricter) Type the break-glass secret into a fresh 600-mode tmp file and decrypt the canary:
>    ```
>    TMPKEY=$(mktemp) && chmod 600 $TMPKEY
>    nano $TMPKEY     # paste the AGE-SECRET-KEY-1… line from Paper 2, save
>    age -d -i $TMPKEY ~/.vault-canary.age && echo '✓ break-glass paper still works'
>    rm -P $TMPKEY
>    ```
>    Expect a `vault-canary-YYYY-MM-DD` line back. This is the only way to verify Paper 2 didn't fade / smudge / get moved."

---

## What the human did

| Moment | Action | Why it can't be automated |
|--------|--------|--------------------------|
| ⏸ Pause 1 | FileVault on + write one key | Key is shown once by macOS, must be written immediately |
| ⏸ Pause 2 | Click Authorize in browser | OAuth browser flow, requires a human |
| ⏸ Pause 3 | Write two papers + Apple ID Recovery Key | Biometric enrollment + physical paper can't be done by an agent |

Everything else ran as commands. Total human time: ~8 minutes.

This Mac's SE identity is now the human identity root—the one capability agents can never produce. Post-setup, agents spawned on this Mac operate as economic peers on Sui under caps the human sets once at the root; agents can spawn sub-agents within those caps without requiring further Touch ID. See `agents.md` Pattern D for the full scope architecture.
