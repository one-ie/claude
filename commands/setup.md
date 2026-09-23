---
description: Connect Claude Code to ONE — a new account handed to you, or your existing one. One login, shared by the plugin's tools and the one CLI.
argument-hint: "[your-email-for-a-new-account | 'login' for an existing account]"
allowed-tools: Bash(npx -y @oneie/cli@5:*), Bash(test -s:*)
---

# /setup — connect Claude Code to ONE

The ONE CLI does the ceremony; this command drives it. The CLI saves the key once, at
`~/.config/one/key` (0600), and the plugin's `oneie` tools read that same file on every
call — so the moment this finishes, every ONE tool in this session is signed in. No
restart, no environment variable, nothing pasted into a shell.

**Never write the key anywhere else.** No `.env.local`, no project file, no echo of its
value. The user's current directory is their own project.

## 1. Already connected?

```bash
test -s ~/.config/one/key || test -s ~/.config/oneie/key
```

Exit 0 → a key already exists on this machine. Say so and stop, unless the user asked to
switch account (then go to step 3). Do **not** mint another account: the new-account door
is unauthenticated, and every run makes a real one.

## 2. New to ONE — mint an account and hand it over

Ask for their email if `$ARGUMENTS` does not hold one. Then:

```bash
npx -y @oneie/cli@5 init --name "<their name or handle>" --email "<email>" --json
```

It makes an account, a workspace and a wallet in one call, saves the key, and returns an
`invite` link (owner role). Tell the user to open it signed in to one.ie: redeeming it
adds them to the new workspace as owner. Say plainly what it does **not** do yet: there
is no passkey claim ceremony and no wallet handover on that page
(`text/agent-handover.md` § 5, row 1), so until one exists this machine's key is the
only credential that fully controls the workspace. The key expires in 90 days
(`expiresAt` in the output).

## 3. Already on ONE — sign in

This one waits for a human, so run it in the background (it polls until the user
approves or the code expires, which can outlast a foreground command):

```bash
npx -y @oneie/cli@5 login --json
```

It prints a URL and a one-time code. Tell the user to open the URL, sign in as
themselves, check the code matches, and approve (a passkey holder approves with the
passkey). When the command exits 0, the key is saved. Not yet proven end to end: step 4
is where a device-flow key that a route refuses would show up — report it, never
"connected".

## 4. Prove it

Call the `oneie` tool `tasks_mine` (or `stats`). A signed-in answer proves the tools read
the new key; `403 forbidden` means they did not — report that, never "connected".

## 5. Report

```
✓ Connected to ONE as <workspace>
  key: ~/.config/one/key (0600) — shared with the one CLI
  claim your account: <invite link>        ← new accounts only
  next: /pair to reach this terminal from your ONE chat
```
