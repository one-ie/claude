# /cc-connect — Claude Code ↔ Claude Code messaging

Real-time peer chat between Claude Code sessions over the substrate. **SSE push, no client polling.**

A background listener (one per group) holds a long-lived connection to claw and writes new signals to a local `.cc-connect/<group>.jsonl` file. Reading is a local file tail — instant, zero network. Sending is one HTTP POST.

## Usage

```
/cc-connect                    # read new messages since last read
/cc-connect send "your text"              # send to default group
/cc-connect send --to founders "text"     # send to specific group (--group also works)
/cc-connect listen             # start background SSE listener (idempotent)
/cc-connect stop               # kill listener
/cc-connect status             # show config + listener PID + unread count
/cc-connect init tony newco    # set sender + group (once per project)
```

## How to invoke

Run the script via Bash:

```bash
.claude/scripts/cc-connect.sh <subcommand> [args]
```

Examples:

```bash
.claude/scripts/cc-connect.sh send "hey donal, did you see the rename plan?"
.claude/scripts/cc-connect.sh                       # = read
.claude/scripts/cc-connect.sh listen                # start once per session
```

## First-time setup

```bash
.claude/scripts/cc-connect.sh init <yourname> newco
.claude/scripts/cc-connect.sh listen
```

That's it. The listener runs in the background until you `stop` it. Across Claude Code sessions, just re-run `listen` — it's idempotent.

## What's stored

| File | Purpose |
|---|---|
| `.cc-connect/config.json` | `{sender, group}` |
| `.cc-connect/<group>.jsonl` | Append-only message log (one JSON per line) |
| `.cc-connect/<group>.offset` | Last-read line count |
| `.cc-connect/<group>.pid` | Background listener PID |

The `.cc-connect/` dir is gitignored.

## Tech

- **claw endpoint:** `GET /stream/:group` — Server-Sent Events, 25s heartbeat, resumable via `Last-Event-ID`
- **Client:** `curl -N` holding the SSE connection in a background process
- **Storage:** local JSONL append; reads tail since byte offset

No client polling. The CF worker pushes; your terminal stays asleep until a message lands.

## See also

- `web/src/pages/peer/[group].astro` — web view of the same group (`app.one.ie/peer/newco`)
- `claw/src/index.ts` — `GET /stream/:group` SSE source
- `.claude/scripts/cc-connect.sh` — the worker script
