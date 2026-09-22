# /notify — send yourself a Telegram message via onedotbot

Send a message to your personal Telegram from Claude Code.

**Prefer `/chat` or `cc-connect send` for peer messaging** — those route through
`space:post` and mirror into the workspace inbox. `notify.sh` marks itself
DEPRECATED for plain text; keep it for **file sends** and for direct Telegram
delivery when `space:post` is unavailable.

## Usage

```
/notify <message>
```

## How to invoke

```bash
.claude/scripts/notify.sh "<message>"
.claude/scripts/notify.sh --to <me|tony|donal|chat_id> "<message>"
.claude/scripts/notify.sh --file <path> ["caption"]
```

## Examples

```bash
.claude/scripts/notify.sh "deploy done — channels worker is live"
.claude/scripts/notify.sh --to donal "tests passing, ready to review"
.claude/scripts/notify.sh --file /tmp/report.pdf "this cycle's numbers"
```

Posts **directly to `api.telegram.org`** (`sendMessage` / `sendDocument`) — it does
**not** go through the channels worker and reads no `CHANNELS_URL`. The bot token
comes from `TELEGRAM_TOKEN` in the environment, falling back to the
`TELEGRAM_TOKEN=` line in `channels/.dev.vars`; the script exits 1 if neither
resolves. Default recipient is chat_id `631201930` (me/tony); `donal` is
`714125982`. Prints `sent ✓` on success.
