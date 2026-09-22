# /browser — headless-shell browser driver

Drives **chrome-headless-shell** against a URL and reports page health, JS errors, network, and anything you tell it to click, fill, or evaluate.

This replaced the `claude-in-chrome` MCP tools. No extension, no Chrome profile, no desktop browser, no human in the loop — one process per invocation, one JSON report on stdout.

## Usage

```bash
node .claude/scripts/chrome.mjs <url> [flags]
```

Default url: `http://localhost:4321`.

## Flags

| Flag | Does |
|---|---|
| `--text` | page `innerText` (truncate at `--max`, default 4000) |
| `--html` | page HTML |
| `--sel <css>` | scope `--text`/`--html` to a selector |
| `--screenshot [path]` | PNG, default `/tmp/chrome-shot.png`; add `--full-page` for the whole document |
| `--console` | every console line (errors are always reported) |
| `--network` | responses to `/api/*`; `--network-all` widens it to everything |
| `--eval <js>` | evaluate an expression in the page, return its value |
| `--do <json>` | run a step list — see below |
| `--send <msg>` | chat drill: fill the first textarea, press Enter, capture the SSE stream |
| `--send-wait <ms>` | how long to hold open after `--send` (default 12000) |
| `--wait <ms>` | settle time after load (default 2500) |
| `--timeout <ms>` | navigation timeout (default 20000) |
| `--state <path>` | persist cookies + localStorage to `<path>` and reuse them next run |
| `--cookie <n=v>` | cookie for the target host (repeatable) |
| `--header <k: v>` | extra HTTP header (repeatable) |
| `--ua <string>` · `--viewport <WxH>` | user agent · viewport (default 1280x800) |
| `--headed` | full Chromium with a visible window instead of the shell |
| `--max <n>` | truncation ceiling for text/html/eval |

`PROVE_SESSION_COOKIE="name=value"` is honoured the same way as before, so an auth-gated `/u/[slug]/*` route can be proven signed-in.

## Steps (`--do`)

A JSON array executed in order. Each entry is one object; every step reports `{step, kind, ok, error?, result?}` and a failed step does **not** abort the run.

```json
[
  {"goto": "http://localhost:4321/login"},
  {"fill": "input[type=email]", "value": "tony@one.ie"},
  {"click": "button[type=submit]"},
  {"waitFor": ".dashboard"},
  {"eval": "document.querySelectorAll('[data-row]').length"},
  {"screenshot": "/tmp/after-login.png"}
]
```

Kinds: `goto` · `click` · `dblclick` · `hover` · `fill`+`value` · `press`(+`sel`) · `select`+`value` · `check`(+`value:false` to uncheck) · `upload`+`files` · `scroll` (px, or a selector to bring into view) · `wait` (ms) · `waitFor` (selector) · `eval` · `screenshot`.

## Sessions

Each invocation is a fresh browser — that is the trade for having no extension. `--state` is how a session survives it:

```bash
# sign in once, keep the session
node .claude/scripts/chrome.mjs http://localhost:4321/login --state /tmp/one.json \
  --do '[{"fill":"#email","value":"tony@one.ie"},{"click":"button[type=submit]"},{"waitFor":".dashboard"}]'

# every later run reuses it
node .claude/scripts/chrome.mjs http://localhost:4321/u/one/in --state /tmp/one.json --text
```

The report carries `stateLoaded` (was the file read) and `stateSaved` (where it was written). Without `--state`, cookies and localStorage die with the process — put the whole flow in one `--do` list instead.

`file://` URLs work, so a local fixture is a valid target.

## Examples

```bash
# health check one route
node .claude/scripts/chrome.mjs http://localhost:4321/pricing --console --network

# read a page
node .claude/scripts/chrome.mjs https://one.ie --text --sel main --max 8000

# drill a form and shoot the result
node .claude/scripts/chrome.mjs http://localhost:4321/contact \
  --do '[{"fill":"#email","value":"a@b.c"},{"click":"button[type=submit]"},{"wait":2000}]' \
  --screenshot /tmp/contact.png

# chat diagnostic (the old browser-check job)
node .claude/scripts/chrome.mjs "http://localhost:4321/studio/boq-empire?agent=boq-empire" --send "hello"
```

## Report fields

`url` · `finalUrl` · `engine` · `playwrightFrom` · `httpStatus` · `navError` · `title` · `jsErrors` · `consoleErrors` · `console?` · `network?` · `steps?` · `chatCapture?` · `chatRailBefore?` · `chatRailAfter?` · `text?` · `html?` · `eval?` · `screenshot?`

Exit **0** = the run completed (read `httpStatus` and `jsErrors` for the verdict). Exit **1** = the browser could not run at all, and stderr carries `{"error": …, "fix": …}`.

## Prerequisites

None to install by hand. chrome-headless-shell ships with the repo's Playwright and the script finds it:

1. `ONE_PLAYWRIGHT_DIR` if set
2. `one.ie/web/node_modules` then `node_modules`, in this tree **and** in the main worktree (via `git rev-parse --git-common-dir`) — a linked worktree has no `node_modules` of its own
3. `/tmp/node_modules` (legacy)

If none resolve it exits 1 with the fix: `cd one.ie/web && bun install && bunx playwright install chromium-headless-shell`. If the shell channel is missing it falls back to plain headless Chromium.

## Who calls it

| Caller | How |
|---|---|
| `do-prove.sh` | every `--route` check — reads `httpStatus`, `jsErrors`, `consoleErrors`; curl is the fallback when the browser can't run. A route fails on 404, ≥500, an uncaught JS error, or a console error; subresource **401/403 are tolerated** (PROVE runs signed-out, so gated is not broken) — the same policy the curl leg already applied |
| `browser-check.mjs` | deprecated shim, maps old flags onto `chrome.mjs` and renames fields back |
| you | directly, via Bash |

## What it is not

Not a hand on the operator's own logged-in Chrome. It has no profile, no session, and no visible surface for a human to approve an action on. Jobs that need those — `.claude/skills/directory-autofill` is the one in this repo — are **not** served by this script.
