---
description: Pair this machine's Claude Code with your ONE chat panel — tells you the one command to run yourself
---

# /pair — connect this machine to your ONE panel

Do NOT run the pairing script yourself. It ends with a `[y/N]` question that only the human at
this terminal may answer: whoever it pins becomes the one sender this session obeys. Run from
here, stdin is not a terminal, so the script refuses before it provisions anything.

Tell the user, verbatim, to run this in their own terminal (outside Claude Code, or with `!`):

```
bun ${CLAUDE_PLUGIN_ROOT}/channel/pair.ts
```

What it does (text/claude-code-integration.md § Pairing):

1. Enrols this machine as its own small ONE group (`/api/provision/agent`, named after the hostname).
2. Prints a code. The user opens `https://one.ie/device`, signs in, checks the IP and location
   shown match this machine, and approves with their passkey.
3. Prints `Paired to <you>? [y/N]`. Only `y` writes `~/.one/channel/pairing.json` (mode 0600).
   Anything else writes nothing.

Options: `--base <url>` (default `https://one.ie`), `--channels <url>` (default
`https://channels.one.ie`), `--name <label>`, `--ttl-days <n>` (default 90). The pairing ends when
the machine key expires; run `/pair` again then.
