---
name: cli
description: Add or change a command in @oneie/cli — the operator CLI shipped as the `oneie` and `one` bins. Use when adding a CLI verb or command group, editing packages/cli/src/*.ts, wiring a command to a receiver through ask(), closing the loop with out(cmd, data), handling --json output, or resolving the API base URL and key. Triggers — "add a CLI command", "new `one` verb", "oneie <group> <verb>", "make the command output JSON", "which host does --api point at", "one fn / one agent / one push is doing X".
---

# CLI verbs — operator commands via @oneie/cli

CLI verbs let operators interact with ONE from the terminal. Every substrate
command is a thin wrapper over a receiver — no new HTTP routes.

## Structure

```
packages/cli/
├── src/
│   ├── index.ts     # builds `program`, addCommand/group
│   ├── <group>.ts   # one file per group → <group>Cmd()
│   │                #   agent · skill · auth · dev · group
│   │                #   social · connect · broadcast · chat
│   │                #   links · staff · wallet · push · fn
│   │                #   deploy · ship · workflow · plugin …
│   ├── substrate.ts # 6 verbs + dim reads
│   ├── lib/
│   │   ├── client.ts   # resolveBase/Key, out, jsonMode
│   │   └── api-path.ts # askPath() — gateway vs web
│   └── templates/
└── tests/           # vitest — registration + behaviour
```

There is no `src/cli.ts` and no `src/commands/` directory — a command group is
one flat file at `src/<group>.ts`. Bins: `oneie` and `one`, both
`dist/src/index.js`. Runtime deps are exactly two: `commander` + `@oneie/sdk`.

## Pattern: Adding a CLI verb

### 1. Define the command shape

```typescript
// packages/cli/src/links.ts
import { Command } from 'commander'
import { authHeaders, resolveBase } from './lib/client.js'
import { askPath } from './lib/api-path.js'

const DEFAULT_API = resolveBase({}, 'https://api.one.ie')

async function ask(api: string, receiver: string, data: unknown): Promise<unknown> {
  const res = await fetch(askPath(api.replace(/\/$/, ''), receiver), {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ data }),
  })
  if (!res.ok) {
    process.stderr.write(`POST /api/ask/${receiver} → ${res.status}\n`)
    process.exit(1)
  }
  return res.json()
}

export function linksCmd(): Command {
  const cmd = new Command('links').description('Create actor-bound tracked links')

  cmd
    .command('create <actorId>')
    .description('Create a tracked link bound to a contact')
    .option('--to <path>', "Destination path, e.g. '/pricing'", '/')
    .option('--expires <days>', 'Link TTL in days (omit = never)')
    .option('--api <url>', 'API base URL', DEFAULT_API)
    .action(async (actorId: string, opts: { to: string; expires?: string; api: string }) => {
      out(await ask(opts.api, 'links:create', {
        actorId,
        destination: opts.to,
        expiresInDays: opts.expires ? Number(opts.expires) : undefined,
      }))
    })

  return cmd
}
```

**Rules:**
- Build the path with `askPath(base, receiver)`. The gateway (`api.one.ie`)
  serves `/ask/<receiver>`; `one.ie/web` serves `/api/ask/<receiver>`. Hardcoding
  either shape 404s against the other host
- `--api` default is per-module, not global. Verified by
  `grep -n "api.one.ie\|https://one.ie" packages/cli/src/*.ts`: gateway-facing
  (`https://api.one.ie`) are `broadcast`, `links`, `substrate`, `wallet`,
  `catalog`, `trade`, `fn`, `coordinate`, `client`, `push`, `setup`; web-facing
  (`https://one.ie`) are `chat`, `connect`, `group`, `social`, `trail`, `staff`,
  `auth`, `init`, `onboard`, `status`, `skill`, `plugin`. Read the module's own
  `DEFAULT_API` before assuming — some call `resolveBase({}, fallback)` and some
  read `ONEIE_BASE_URL`/`ONE_API_URL` inline
- The option name determines the property: `--to` reads as `opts.to`,
  `--batch-size` as `opts.batchSize`. Map to the receiver's field names explicitly
- Target an existing receiver or `/api/*` route — never add a new endpoint

### 2. Close the loop with `out()`

`out(cmd, data)` from `lib/client.ts` is the canonical closer: human-readable
`ok  k=v  k=v` by default, one line of JSON under `--json`, `ok: false` routed to
stderr with exit code 1.

```typescript
import { out, resolveBase, resolveKey } from './lib/client.js'

.action(async (opts: { csv: string; api: string }) => {
  const key = resolveKey()
  if (!key) {
    out(cmd, { ok: false, error: 'no API key — set ONE_API_KEY or run: oneie auth login' })
    return
  }
  out(cmd, { ok: true, created: 12, skipped: 3 })
})
```

`jsonMode(cmd)` walks `cmd.parent` to the root, so `--json` works wherever the
operator puts it. Some older groups (`links`, `broadcast`) still use a local
`out(data)` that always pretty-prints JSON — new commands use `out(cmd, data)`.

### 3. Register the command

```typescript
// packages/cli/src/index.ts
import { linksCmd } from './links.js'

const program = new Command()
  .name('oneie')
  .description('ONE — agent CLI')
  .version(pkg.version)
  .option('--json', 'Output structured JSON')

program.addCommand(linksCmd())
```

Groups that register several top-level commands export a `<group>Commands(program)`
function instead (`substrateCommands`, `catalogCommands`, `tradeCommands`,
`coordinateCommands`). Relative imports carry the `.js` extension — ESM.

### 4. Test the command

Registration tests are cheap and catch the common regression (a subcommand
silently dropped):

```typescript
// packages/cli/tests/workflow.test.ts
import { describe, it, expect } from 'vitest'
import { workflowCmd } from '../src/workflow.js'

describe('workflow CLI registration', () => {
  it('registers list/pull/push/run/validate/resolve/logs subcommands', () => {
    const names = workflowCmd().commands.map((c) => c.name()).sort()
    expect(names).toEqual(['list', 'logs', 'pull', 'push', 'resolve', 'run', 'validate'])
  })
})
```

**Rules:**
- `bun run test` in `packages/cli` (vitest)
- Import the `<group>Cmd()` factory and assert on the commander tree — don't
  `execSync` the bin; the built `dist/` may be stale and the call hits the network
- For behaviour, call the action's collaborators directly (see
  `tests/doctor.test.ts`, `tests/setup-keyless.test.ts`)

## Naming conventions

**Command structure:** `one {group} {verb} [args]`
- Correct: `one links create <actorId>`
- Correct: `one broadcast send <id>`
- Correct: `one workflow pull <id> --slug acme`
- Wrong: `one -l create-link` (unclear)
- Wrong: `one links --create <actorId>` (verb is an option, not a subcommand)

Single-purpose groups stay flat as top-level commands — `one whoami`, `one doctor`,
`one status`, `one trail <tags>`, `one signal <receiver>`.

**Verb names:** imperative, no "get"
- Correct: `create`, `list`, `send`, `pull`, `push`, `run`, `validate`, `approve`
- Wrong: `get-broadcast`, `CREATE_LINK`, `bc_list`

**Arguments and options:**
- Arguments: positional, required, no dashes — `one broadcast send <id>`
- Options: named, optional, with dashes — `--to /pricing`, `--limit 20`
- `--api <url>` and `--key <k>` are the two conventional overrides; both fall
  through to `resolveBase()` / `resolveKey()` when omitted

## Command categories

| Category | Verbs | Purpose |
|----------|-------|---------|
| **Read** | `list`, `get`, `status`, `whoami`, `doctor` | Display data without side effects |
| **Create** | `create`, `new`, `init`, `add`, `scaffold` | Create new entity |
| **Update** | `push`, `set`, `rename`, `refresh` | Modify existing entity |
| **Delete** | `unpublish`, `unimport`, `logout` | Remove entity |
| **Execute** | `send`, `run`, `publish`, `deploy`, `eval` | Action with side effects |

## Output format

**Default (human):** one `ok` line of key=value pairs, from `out(cmd, data)`

```
$ one group bulk-create --csv clients.csv
batch 1/1  created=12  skipped=3
ok  total_rows=15  created=12  duplicates=3  batches=1  plan="studio"  segment="ICP-1"  dry_run=false
```

Values are `JSON.stringify`d, so strings keep their quotes and `ok` itself is
dropped from the human line.

**`--json`:** one line of structured JSON, suitable for piping

```
$ one group bulk-create --csv clients.csv --json
{"ok":true,"total_rows":15,"created":12,"duplicates":3,"batches":1,"plan":"studio","segment":"ICP-1","dry_run":false}
```

`--json` is a global option declared on `program`, and `jsonMode()` finds it at
any depth. There is no `--format` flag and no YAML or CSV output — `--json` plus
`jq` is the whole contract. An uncaught error also honours it: `index.ts` prints
`{"ok":false,"error":"…"}` to stdout under `--json`, the message to stderr
otherwise, and exits 1.

## Anti-patterns

**Verb as an option**
```bash
# WRONG
one links --create u-123
```
**Fix:** Verbs are subcommands, not options.
```bash
one links create u-123 --to /pricing
```

**Hardcoding the ask path**
```typescript
// WRONG — 404s whenever --api points at the gateway
await fetch(`${api}/api/ask/links:create`, { … })
```
**Fix:** `askPath(base, 'links:create')` picks the form by hostname.

**Hardcoding the base URL or reading the key inline**
```typescript
// WRONG
const api = 'https://one.ie'
const key = process.env.ONE_API_KEY
```
**Fix:** `resolveBase(opts, fallback)` and `resolveKey(opts)` — they encode the
`--flag > canonical env > legacy env > ~/.config/oneie/key` ladder.

**Silent return**
```typescript
// WRONG
program.action(async (id) => {
  const r = await ask(api, 'broadcast:send', { broadcastId: id })
  console.log(r)  // no ok/error shape, no exit code, breaks --json
})
```
**Fix:** Close the loop with `out(cmd, { ok, ...data })` — the locked closed-loop rule.

**No help text**
```typescript
// WRONG
new Command('create')
  .argument('<actorId>')
  .action(async (actorId) => { /* … */ })
```
**Fix:** Add a description to the command and to every argument and option.
```typescript
new Command('create')
  .description('Create a tracked link bound to a contact')
  .argument('<actorId>', 'Contact the link is bound to')
  .option('--to <path>', "Destination path, e.g. '/pricing'", '/')
```

**Adding a dependency**
```typescript
// WRONG — breaks `npm i -g @oneie/cli` / `npx oneie`
import YAML from 'yaml'
import { z } from 'zod'
```
**Fix:** Runtime deps are `commander` + `@oneie/sdk`, full stop. Hand-rolled
YAML/Markdown parsers live in the SDK; `@oneie/evals` is a devDependency on purpose.

## Composability rules

**New verb wraps a receiver:**
```typescript
// GOOD — the receiver owns authority, validation, and persistence
cmd
  .command('list')
  .description('List broadcasts for the workspace')
  .option('--limit <n>', 'Max results', '20')
  .action(async (opts: { limit: string; api: string }) => {
    out(await ask(opts.api, 'broadcast:list', { limit: Number(opts.limit) }))
  })
```

**New verb composes two receivers:**
```typescript
// GOOD — segment preview needs the definition, not the id, so the CLI
// fetches it first and fails loudly if it is missing
const got = await ask(opts.api, 'segment:get', { id }) as { segment?: { definition?: unknown } }
if (!got.segment) {
  process.stderr.write(`segment:get returned no segment for id=${id}\n`)
  process.exit(1)
}
out(await ask(opts.api, 'segment:preview', { definition: got.segment.definition }))
```

**New verb is generated from a catalog:**
```typescript
// GOOD — `one fn list` / `one fn run <name>` enumerate FN_ALLOWLIST from
// @oneie/sdk/fn-allowlist (20 entries today) and route through ask('fn:run').
// Allowlisting a fun there reaches web, MCP, CLI, and channels in one edit.
```

## Piping and composability

Commands that emit JSON chain through `jq`. Receiver wrappers print the `/api/ask`
envelope verbatim — `{ outcome, result, signalId, receiver }` — so the receiver's
own response sits one level down, under `.result`:

```bash
# List broadcasts, keep the drafts, send each one
one ask broadcast:list --data '{"workspace":"acme","limit":50}' \
  | jq -r '.result.broadcasts[] | select(.status=="draft") | .id' \
  | xargs -I {} one broadcast send {}
```

`validateReceiver` strict-parses the payload against the receiver's zod `request`
before dispatch, so every required field must be in `--data` — omitting
`workspace` here is a 400, not a default.

Check the group's own `out()` before writing a pipeline: `out(cmd, data)` gives
one line under `--json` and `ok  k=v` otherwise, the local `out(data)` in `links`
and `broadcast` pretty-prints JSON either way, and a few commands (`whoami`,
`doctor`) print fixed human lines with no JSON mode at all.

**Rules:**
- Default output is human-readable (`ok  k=v`); `--json` is opt-in
- `--json` output is valid JSON — parseable by `jq`
- Errors go to stderr with exit code 1; under `--json` the error object goes to
  stdout so a pipeline can read it
- Never print a secret. `one wallet keygen` prints once and never writes a file
  without `--yes-i-accept-plaintext-file`; `one connect` never echoes the token

## See also

- `packages/cli/CLAUDE.md` — the full command map, conventions, and distribution
- `packages/cli/src/lib/client.ts` — `resolveBase` / `resolveKey` / `out` / `jsonMode`
- `packages/sdk/src/receivers.ts` — receiver registry (every substrate verb wraps one)
- `text/cli.md` — the promise: who this CLI is for
- `text/cli-reference.md` — the command reference written for external readers
