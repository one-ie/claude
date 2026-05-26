# mac-setup — CLI product plan

**Goal:** Package `mac.md` + `mac-agent.md` as a standalone CLI so anyone can run `npx mac-setup` in Terminal and get a hardened Mac without Claude Code.

**Classifier:** mode: lean | lifecycle: construction

---

## What we're building

A TypeScript CLI distributed as `@oneie/mac-setup` on npm. Users run:

```
npx mac-setup           # guided full setup, resumes if interrupted
npx mac-setup scan      # print current system state
npx mac-setup verify    # run 18-check pass/fail verification
npx mac-setup status    # show saved progress
npx mac-setup reset     # clear state, start over
```

The tool automates everything automatable from `mac-agent.md`, pauses for the three moments that require a human (FileVault key, GitHub OAuth, break-glass paper), and resumes exactly from the last completed phase if interrupted.

---

## Package location

New package: `one-ie/one/setup/` — same structure as `mcp/` and `sdk/`.

```
one-ie/one/setup/
├── package.json        # name: @oneie/mac-setup; bin: mac-setup → ./dist/index.js
├── tsconfig.json       # same shape as mcp/tsconfig.json
├── src/
│   ├── index.ts        # commander entrypoint
│   ├── state.ts        # ~/.config/mac-setup/state.json — read/write/resume
│   ├── phases/
│   │   ├── phase1-scan.ts
│   │   ├── phase2-security.ts
│   │   ├── phase3-install.ts
│   │   ├── phase4-vault.ts
│   │   ├── phase5-github.ts
│   │   ├── phase6-verify.ts
│   │   ├── phase7-terminal.ts
│   │   └── phase8-papers.ts
│   └── utils/
│       ├── run.ts       # execShell() + sudoRun() helpers
│       ├── prompt.ts    # @clack/prompts wrappers for human pauses
│       └── report.ts    # verification table + status board
```

---

## Dependencies

| Package | Role |
|---|---|
| `commander` | subcommand routing |
| `@clack/prompts` | spinners, confirmations, text inputs |
| `chalk` | colours in verification report |
| `tsc` (build-only) | compile to ESM dist/ |

Build: `bun run build` → `tsc`. Same `"type": "module"` + `prepublishOnly: tsc` as `mcp/`.

---

## Automation map

Every phase from `mac-agent.md` maps to one tier:

| Phase | Tier | CLI behaviour |
|---|---|---|
| 1 — Scan | AUTO | spinner → status table |
| 2a–c — Security baseline | AUTO | spinners per command group; `sudo` prompts natively |
| 2d — Xcode CLT | HUMAN (1 click) | opens installer dialog; waits for Enter |
| Pause 1 — FileVault | HUMAN | step-by-step System Settings path; waits for Enter confirmation |
| 3a–c — Homebrew + all tools | AUTO | `Promise.all` over 3 brew groups; single spinner |
| 4a–c — SE key + vault | AUTO | Touch ID fires natively via `age-plugin-se` |
| 4d — FileVault key into vault | HUMAN | instructs user to `v` in a new tab; waits for Enter |
| 5a — Secretive key | HUMAN | step-by-step app instructions; waits for Enter |
| Pause 2 — GitHub OAuth | BROWSER | `open` GitHub URL; polls `gh auth status` until authed |
| 5b — git name/email | HUMAN (text input) | `@clack/prompts text()` — two inputs, then automated |
| 5c–d — runtimes + Claude Code | AUTO | spinners |
| 6 — Verification | AUTO | 18-check pass/fail table |
| 7a–d — Terminal config | AUTO | idempotent file writes |
| Pause 3 — Apple ID Recovery Key | HUMAN | Mac or iPhone path; waits for Enter |
| Pause 3 — Break-glass key | AUTO generate / HUMAN write | key displayed in bordered box; waits for confirmation; wiped after |
| Pause 3 — Re-encrypt vault + canary | AUTO | Touch ID fires natively |
| Done | — | summary + quarterly audit instructions |

---

## Resume

State is persisted to `~/.config/mac-setup/state.json` after every completed phase.

```json
{
  "filevault_on": true,
  "phase2_done": true,
  "homebrew_done": true,
  "brew_packages_done": true,
  "se_recipient": "age1se1q...",
  "vault_created": true,
  "gh_authed": true,
  "git_user_name": "Tony O'Connell",
  "git_user_email": "tony@one.ie",
  "verification_passed": true,
  "terminal_done": true,
  "breakglass_pubkey": "age15gd3r...",
  "setup_complete": false
}
```

`run` command iterates phases in order; each phase calls `loadState()` and returns early if its flag is truthy.

---

## Security constraints

- Break-glass secret is held only in the Node process memory, displayed once, then passed directly to `age -r`. Never written to a file the CLI controls.
- The CLI never asks for secrets via prompts. It only collects git name/email and confirmation booleans.
- Vault operations (decrypt/re-encrypt) are delegated entirely to `age` + `age-plugin-se` — Touch ID fires natively.

---

## Distribution

1. `npm publish --access public` → `@oneie/mac-setup`
2. Users run: `npx mac-setup` (no install needed)
3. Future: `brew install one-ie/tap/mac-setup` via Homebrew tap

---

## Verify

```bash
cd one-ie/one/setup
bun run build                  # zero TS errors
node dist/index.js scan        # prints system state
node dist/index.js verify      # 18-check table
node dist/index.js status      # reads state.json
# then on a test or reset run:
node dist/index.js reset && node dist/index.js run   # reaches Pause 1, waits, resumes correctly
```

---

## Implementation tasks

- [ ] `setup/package.json` — bin, deps, scripts
- [ ] `setup/tsconfig.json` — copied from `mcp/tsconfig.json`
- [ ] `src/utils/run.ts` — `execShell()`, `sudoRun()`, `spawnAsync()`
- [ ] `src/utils/prompt.ts` — `humanPause()`, `browserPause()`, `ask()`
- [ ] `src/utils/report.ts` — `printTable()`, `printStatus()`
- [ ] `src/state.ts` — `loadState()`, `saveState()`
- [ ] `src/phases/phase1-scan.ts` through `phase8-papers.ts` — one file per phase
- [ ] `src/index.ts` — commander wiring + `run` command
- [ ] Publish to npm
