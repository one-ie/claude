---
name: sell
description: Turn an operator's own API or tool into a priced ONE marketplace listing from Claude Code. Registers the HTTPS endpoint, clones the sell-a-tool starter workflow (or sell-an-image when there is no API), runs it once with a test payload, reads the step timeline, then publishes at a price in credits. Use when someone says "I have an API, sell it", "list my tool on the marketplace", "charge for my endpoint", "publish this workflow at a price", or "why did my endpoint step fail".
---

# Sell — an API or tool, listed at a price

**Five doors, in order: register → clone → run → publish → search.** Each one
is a real receiver. This skill names no other door. If one is missing, the
answer is to say so, not to invent a workaround.

## 0. Connected?

The plugin's tools read `~/.config/one/key`. If it is missing, run `/setup`
first. Every door below acts as the owner of that key's group.

## 1. Register the endpoint

Ask for four things: a handle, the HTTPS URL, what it returns, and whether it
needs a credential.

```
endpoint_register {name:"thumbs", url:"https://…", returnMode:"bytes",
                   authHeader:"Authorization", secret:"Bearer …"}
```

The same door from a shell keeps the secret out of shell history:
`one endpoint add thumbs <url> --returns bytes --auth-header Authorization --secret-env VAR`.

- `returnMode`: `json` is the answer itself. `url` is a JSON body naming a
  link, which ONE fetches and files. `bytes` is the asset itself, which ONE
  files in the media library.
- The secret is sealed. It is never returned, and the row shows only
  `hasSecret`. **Never echo it back to the operator.**
- A refused URL is refused by name: `https_required`, `ip_literal`,
  `private_hostname`, `dns_unresolved` or `blocked_address`. Fix the URL. Do
  not retry the same one. `one endpoint test <name>` checks the guard without
  spending a request.

**Suggest the handle `thumbs`.** The starter already names it, so the clone
runs unedited. Any other handle means editing the tool step's
`args.endpoint`, or the run fails with `not_found`.

## 2. Clone the starter

```
workflow_list   {templates:true}          → look for sell-a-tool / sell-an-image
workflow_create {name:"<what it sells>", fromTemplate:"sell-a-tool"}
```

Keep the returned `workflowId`. `sell-a-tool` is two steps:

- **trigger**: source `api`, payload `{ title (required), style }`
- **tool**: `{"receiver":"endpoint:call","args":{"endpoint":"thumbs","input":{"title":"$trigger.title","style":"$trigger.style"}}}`

Only `input` crosses to the endpoint, beside its own sealed credential.

**No API?** Clone `sell-an-image` instead. Its tool step is `media:generate`,
so skip step 1. Edit its fixed style guidance after cloning.

**Starter absent from the list?** The server predates the release that
carries it, and the `endpoint:call` fixes ship in that same release, so a hand-built copy
would fail as well. Say so, and do not work around it.

## 3. Run it once

```
workflow_validate {workflowId, diff:{}}     → ok, stepCount, warnings (advisory)
workflow_run      {workflowId, triggerPayload:{title:"How we shipped in a week"}}
workflow_runs     {workflowId, runId}       → the step timeline, payloads included
```

- `status` is `open`, `done`, `paused` or `failed`. A run the executor refused
  to start answers `failed`, never `open`.
- A failed step carries `{ error, outcome, receiver }`. Read `error` before
  guessing. For `endpoint:call` it is named: `not_found` (wrong handle, or the
  endpoint was registered in another group), `blocked_url:<reason>`,
  `redirect_refused` (the endpoint answered a 3xx, which is refused and never
  followed), `too_large`, `endpoint_error`, `fetch_failed`.
- An optional field the buyer leaves out (here `style`) is **dropped**, so the
  endpoint receives `{ title }` only.

Do not publish a workflow whose test run did not reach `done`.

## 4. Publish at a price

```
workflow_publish {workflowId, price:5, tags:["thumbnail","youtube","image"]}
```

The price is in **credits**, and `0` means free. `workflow` is always added to
the tags, which are bare words. The seller comes from the workflow's own group,
and there is no seller field to set. The answer carries `sid`, `sellerUid`,
`price` and `kind:"listing"`. `not_found` means the workflow is absent or not
yours, and the two cases answer the same on purpose.

## 5. Confirm a buyer can find it

```
one ask market:search --data '{"q":"thumbnail","limit":5}'
```

The listing is found when a result has `kind:"listing"`, a `ref` of
`workflow:<workflowId>`, and your price.

## Not built. Say so plainly.

- **Per-call buying over x402.** A buyer cannot yet pay for a single run.
- **Payouts.** Earned credits do not yet move to the seller's wallet.

Never tell an operator either one works. Never quote a payout date.

Full walkthrough with the thumbnail example: [tutorial.md](tutorial.md) (in this folder).
