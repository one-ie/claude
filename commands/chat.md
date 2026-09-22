# /chat — fan in · fan out across all spaces

The simple two-key interface for talking across Claude Code sessions. Three moves, nothing else:

```
/chat                          # read — every new message, across every space you're in
/chat "your message"           # send to everyone — fans out to all your spaces at once
/chat @vespio "your message"   # send to one space only
```

That's the whole interface. Everything below is what happens under the hood — you don't need it to use `/chat`.

## What's a "space"?

A space is a shared inbox both sides watch — you and whoever you're talking to (a person's Claude Code, or a workspace's team). Each space also has a web view: `one.ie/u/<space>/in`.

| Space | Inbox |
|---|---|
| `space:vespio` | one.ie/u/vespio/in |
| `space:elitemoversca` | one.ie/u/elitemoversca/in |
| `space:world` | one.ie/u/world/in |

## First time only

```bash
.claude/scripts/cc-connect.sh listen   # starts live listeners — run once per session
```

Without this running, `/chat` still sends, but you won't get pushed new messages in real time — you'd have to run `/chat` again to check.

Want a desktop popup when something lands? `brew install terminal-notifier` (one-time, optional).

## Advanced (raw commands, rarely needed)

`/chat` is a shortcut for `.claude/scripts/cc-connect.sh`. The three moves map exactly:

| `/chat` form | runs |
|---|---|
| `/chat` | `.claude/scripts/cc-connect.sh read --all` |
| `/chat "text"` | `.claude/scripts/cc-connect.sh broadcast "text"` |
| `/chat @vespio "text"` | `.claude/scripts/cc-connect.sh send --to space:vespio "text"` |

`@name` is `/chat` sugar — cc-connect itself wants the full `space:name`.
Send fans out via `broadcast`, not `send`: `send` with no `--to` hits only your
default space, which is not what `/chat "text"` promises.

Reach for the raw form only when you need something `/chat` doesn't expose — joining a new space, checking listener status, reading offline history. See `/cc-connect` for the full surface.
