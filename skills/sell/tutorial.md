---
title: Sell a workflow — your first listing
slug: sell-a-workflow
type: tutorial
audience: creators with an HTTPS API and Claude Code
walk: text/david-agents.md · text/david-humans.md
---

# Sell a workflow — your first listing

You have an HTTPS API that makes YouTube thumbnails. By the end of this page it
is a priced listing in the ONE marketplace: a buyer sends a title and your API
answers. You drive every step from Claude Code, through the ONE plugin's tools.

The example is David's. Every door below was walked end to end on production
(https://one.ie, release `0a38cb89d`) on 2026-09-23 with a non-staff key: the
endpoint returned a PNG, the `sell-a-tool` run finished `done` in about 6s, and
`market:search "thumbnail"` found the listing at 5 credits.

## Step 1 — install the plugin and connect

```bash
claude plugin marketplace add one-ie/claude
claude plugin install oneie-claude@oneie
```

Then, inside Claude Code:

```
/oneie-claude:setup
```

`/oneie-claude:setup` saves one key at `~/.config/one/key` (mode 0600). The plugin's tools
and the `one` CLI both read that file, so nothing gets pasted into a shell
(`packages/claude/commands/setup.md:9-12`).

## Step 2 — register your API as an endpoint

Give the API a handle. Use `thumbs`, because the starter in step 3 already
names it, so the clone runs without an edit.

```bash
export THUMBS_KEY='Bearer sk_live_…'
one endpoint add thumbs https://api.david.example/thumbnail \
  --returns bytes --auth-header Authorization --secret-env THUMBS_KEY
```

In Claude Code, the same door is the `endpoint_register` tool:
`{name:"thumbs", url, returnMode:"bytes", authHeader:"Authorization", secret}`.

- **`returnMode`** tells ONE what your API answers. `json` means the answer
  itself. `url` means a small JSON body that names a link, which ONE fetches and
  files. `bytes` means the image itself, which ONE files in your media library
  (`packages/sdk/src/receivers.ts:1049`).
- **The secret is sealed and has no read door.** The stored row comes back with
  `hasSecret: true`, never the value (`receivers.ts:1048`, `:1056`).
  `--secret-env` exists so the key never lands in your shell history.

To check the URL without spending a request, run `one endpoint test thumbs`.
Your first failure is almost always the URL, and this names why:
`https_required`, `ip_literal`, `private_hostname`, `dns_unresolved` or
`blocked_address` (`receivers.ts:1045`).

## Step 3 — clone the `sell-a-tool` starter

```
workflow_list   {templates:true}
workflow_create {name:"YouTube thumbnail generator", fromTemplate:"sell-a-tool"}
```

The answer is `{ id, workflowId }`. Keep `workflowId`, because every later step
uses it. The clone has two steps
(`one.ie/web/src/lib/workflow-templates.ts`, `id: 'sell-a-tool'`):

1. **trigger**: `source: "api"`, payload schema `{ title: string (required), style: string }`
2. **tool**: `{"receiver":"endpoint:call","args":{"endpoint":"thumbs","input":{"title":"$trigger.title","style":"$trigger.style"}}}`

Only `input` crosses to your API, beside its own sealed credential. Your API
never sees the buyer's session, your group's key, or any ONE secret
(`receivers.ts:1100`).

## Step 4 — test it once

Validate the stored graph. An empty diff checks what is already there
(`workflow-crud-receivers.ts:272-284` loads the steps and edges, then applies
the diff):

```
workflow_validate {workflowId, diff:{}}
workflow_run      {workflowId, triggerPayload:{title:"How we shipped in a week"}}
workflow_runs     {workflowId, runId}
```

`workflow_validate` answers `{ ok, stepCount, warnings }`, and warnings are
advisory. `workflow_run` answers `{ runId, status }`. A run the executor refused
to start answers `failed`, never `open` (`receivers.ts:6578`). `workflow_runs`
with a `runId` returns that run's step-by-step timeline, payloads included
(`workflow-crud-receivers.ts:1227`).

**When a step fails, the timeline says why.** A failed step records
`{ error, outcome, receiver }` (`workflow-executor.ts:192`). For `endpoint:call`
the error is one of a named set: `not_found` (the handle is not registered in
this group), `blocked_url:<reason>`, `redirect_refused`, `too_large`,
`endpoint_error` and others (`receivers.ts:1118`).

**The trap: a missing `style` is dropped, not sent.** This run sends no `style`,
so ONE drops the key and your API receives `{ title }` only
(`workflow-executor.ts:541-548`). Before `32cf4c441`, your API received the
literal string `"$trigger.style"`. If your logs show that string, the run
predates the fix.

## Step 5 — set a price and publish

```
workflow_publish {workflowId, price:5, tags:["thumbnail","youtube","image"]}
```

The price is in **credits**, and `0` means free. The tag `workflow` is always
added. The seller is taken from the workflow's own group, and the request has
no seller field to fill in or fake (`receivers.ts:6480-6502`). The answer
carries `sid`, `sellerUid`, `price` and `kind: "listing"`.

## Did it work? Search for it

`market:search` searches the whole marketplace catalog, listings included:

```bash
one ask market:search --data '{"q":"thumbnail","limit":5}'
```

Measured on https://one.ie on 2026-09-23, David's probe listing came back as:

`{"kind":"listing","ref":"workflow:01a0cceb925533dac36222f1","price":5,"unit":"credits","priceLabel":"5 credits"}`

If your `ref` starts with `workflow:` and your price reads back, you have
shipped.

**No API?** Clone `sell-an-image` instead. Its tool step is `media:generate`,
so you skip step 2.

## Not yet built

> **○ Buying per call with x402 (step 6).** No one can yet pay for a single run
> of your listing over x402. The listing exists and is searchable, but the
> buy-and-run door is not built.
>
> **○ Payouts (step 8).** Credits earned from a listing do not yet move to your
> wallet. Do not promise a buyer or yourself a payout date.

## See also

- `text/david-agents.md`: these steps as machine asserts (`do-walk.sh david --agents`)
- `text/david-humans.md`: the same walk for a person to open and judge
- `packages/sdk/src/receivers.ts`: the contract. The zod `describe()` text is the spec.
