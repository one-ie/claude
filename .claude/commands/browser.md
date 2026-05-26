# /browser — Playwright browser diagnostic

Runs a headless Chrome check against a URL and reports page health, JS errors, and chat behaviour.

## Usage

```
/browser [url] [--send "message"] [--screenshot] [--network]
```

**Arguments (all optional):**
- `url` — page to check (default: `http://localhost:4321`)
- `--send "text"` — type and submit a chat message, then compare rail before/after
- `--screenshot` — save `/tmp/browser-check.png`
- `--network` — capture API request list

## How to invoke

```bash
node .claude/scripts/browser-check.mjs http://localhost:4321/studio/boq-empire?agent=boq-empire --send "hello" --screenshot
```

Or directly in conversation — Claude runs the script via Bash.

## What it checks

| Check | How |
|---|---|
| HTTP status | `page.goto` response code |
| Title | `page.title()` |
| JS errors | `pageerror` events |
| Console errors | `console.error` events |
| Chat rail (before send) | `.chat-rail` innerText |
| Chat POST body | fetch monkey-patch captures `agentId`, `slug`, messages |
| Stream content | Reads cloned SSE stream; shows first 800 chars |
| Chat rail (after send) | After 12s wait post-submit |

## Prerequisites

Playwright installed once:
```bash
cd /tmp && npm install playwright && npx playwright install chromium
```

Check with: `node -e "require('/tmp/node_modules/playwright'); console.log('ok')"`

## Output

JSON report to stdout. Key fields:
- `httpStatus` — 200/404/500
- `jsErrors` — uncaught JS exceptions
- `consoleErrors` — console.error calls
- `chatRailBefore` / `chatRailAfter` — visible text
- `chatCapture[].body` — POST body (check `agentId` present)
- `chatCapture[].stream` — SSE response (check for error vs real tokens)
