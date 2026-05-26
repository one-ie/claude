# Signal Wiring Pattern — Adding a New Signal

**Reference:** [signal-integration.md](signal-integration.md) · [signals-catalog.md](signals-catalog.md)

---

## Overview

Adding a signal to ONE is a **3-step process**: name it, document it, wire it. The signal flow is already built (`/api/signal`, `/api/ask`, mark/warn, TypeDB learning). You just need to:

1. **Pick a receiver name** (follow namespace convention from `dictionary.md`)
2. **Add the signal to catalog** (update `signals-catalog.md`)
3. **Wire the sender** (UI button, agent subscription, webhook handler)

---

## Step 1: Name the Signal

### Check the namespace convention

Every signal follows the pattern:

```
<namespace>:<type>[:<subtype>]
```

| Namespace | Pattern | Example |
|-----------|---------|---------|
| `agent:` | `agent:<id>:<action>` | `agent:analyst:publish` |
| `skill:` | `skill:<action>` | `skill:import` |
| `campaign:` | `campaign:<id>:<event>` | `campaign:abc123:brief` |
| `groups:` | `groups:<type>:<action>` | `groups:persona:create` |
| `auth:` | `auth:<event>` | `auth:mfa-enabled` |
| `billing:` | `billing:<state>` | `billing:payment-received` |
| `import:` | `import:<source>` | `import:hubspot` |
| `export:` | `export:<target>` | `export:tiktok` |
| `signal:` | `signal:<type>` | `signal:purchase` |
| `intent:` | `intent:<type>` | `intent:website-visit` |
| `ui:` | `ui:<surface>:<action>` | `ui:composer:send` |
| `integration:` | `integration:<vendor>:<event>` | `integration:slack:connected` |
| `workspace:` | `workspace:<event>` | `workspace:settings-update` |

### Verify it doesn't exist

1. Check `plans/signals-catalog.md` — is it in "Implemented" or "Proposed"?
2. Check `one.ie/one.ie/agents/*.md` — does any agent emit it?
3. Grep codebase: `grep -r "my-signal-name" one.ie/`

If it exists, you're wiring it (Step 3). If not, continue.

---

## Step 2: Add to Catalog

Update `plans/signals-catalog.md` in the appropriate section:

### If sending from UI / webhook

Add to **"Implemented Signals"** section (or create a subsection if new category):

```markdown
### [Category Name]

```
my-signal:name              — description
```

Example: `campaign:<id>:brief` → Campaign brief submitted by user
```

### If subscribing from an agent

Add to agent markdown file's `emits:` section, then update catalog:

```markdown
agent:name:event            — agent publishes this signal when X happens
```

### If it's future work

Add to **"Proposed Signals"** section with category:

```markdown
### [New Category] Signals

```
new:signal:name             — what will happen
another:signal              — another thing
```
```

---

## Step 3: Wire the Sender

### Pattern 1: UI Button (fetch + signal)

Most common. Example: "Enrich this contact" button.

**File:** `one.ie/web/src/components/in/EntityDetail.tsx` (or similar)

```tsx
async function handleEnrich(contactId: string) {
  const receiver = encodeURIComponent(`${contactId}:enrich`)
  
  const res = await fetch(`/api/signal/${receiver}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ /* data payload */ }),
  })
  
  const outcome = await res.json()
  // outcome = { outcome: 'queued' | 'dissolved', signalId }
}
```

**Then:** The agent subscribed to `:enrich` receives it, processes, emits outcome, you mark/warn.

### Pattern 2: Server Action (astro:actions)

For form submissions. Example: campaign brief submission.

**File:** `one.ie/web/src/actions/campaigns.ts`

```ts
export const submitBrief = defineAction({
  accept: 'form',
  input: z.object({
    campaignId: z.string(),
    brief: z.string(),
  }),
  handler: async ({ campaignId, brief }) => {
    const receiver = encodeURIComponent(`campaign:${campaignId}:brief`)
    
    const res = await fetch('/api/signal/' + receiver, {
      method: 'POST',
      body: JSON.stringify({ brief }),
    })
    
    const { signalId, outcome } = await res.json()
    return { signalId, outcome }
  },
})
```

**Then:** Register in `one.ie/web/src/actions/index.ts`:

```ts
export const actions = {
  campaigns: submitBrief,
  // ...other actions
}
```

### Pattern 3: Agent Subscription

Agent emits on behalf of user. Example: "Mark this path when strategy is ready."

**File:** `one.ie/one.ie/agents/strategist.md`

```yaml
---
name: strategist
kind: agent
subscribes:
  - signal: campaign:<id>:strategy-needed
emits:
  - signal: campaign:<id>:strategy-ready
---

# strategist

Emits `campaign:<id>:strategy-ready` after analysis.

## Operating Instructions

- Analyze market, brand, competitive landscape
- Output: emits `campaign:<id>:strategy-ready` with analysis
- Mark path on success: `mark(entry→strategist, +1)`
- Warn path on failure: `warn(entry→strategist, +0.5)`
```

Then subscribe to `campaign:<id>:strategy-needed` in the campaign router agent.

### Pattern 4: Webhook Handler

For external systems. Example: Stripe payment webhook.

**File:** `one.ie/web/src/pages/api/webhook/stripe.ts`

```ts
export const POST: APIRoute = async ({ request }) => {
  const event = await request.json() // from Stripe
  
  if (event.type === 'payment_intent.succeeded') {
    const receiver = encodeURIComponent(`signal:payment`)
    const signalId = generateTraceId()
    
    await fetch(`/api/signal/${receiver}`, {
      method: 'POST',
      body: JSON.stringify({
        paymentId: event.data.object.id,
        amount: event.data.object.amount,
      }),
    })
    
    return Response.json({ ok: true })
  }
}
```

The agent subscribed to `signal:payment` will process it.

---

## Step 4: Mark/Warn Integration (Automatic)

Once wired, the **learning loop** is automatic:

1. UI sends signal
2. Agent processes (in nanoclaw Worker)
3. Agent emits outcome (`result` | `timeout` | `dissolved` | `failure`)
4. Caller polls outcome, gets result
5. **Caller marks or warns** on the path `entry→agent`

### If you need explicit mark/warn

Call after signal succeeds:

```ts
// User interaction succeeded
await fetch(`/api/mark/${encodeURIComponent('entry>myagent')}`, {
  method: 'POST',
  body: JSON.stringify({ strength: 1 }),
})

// User interaction failed
await fetch(`/api/warn/${encodeURIComponent('entry>myagent')}`, {
  method: 'POST',
  body: JSON.stringify({ strength: 0.5 }),
})
```

---

## Checklist

- [ ] Signal name follows namespace convention (`<namespace>:<type>`)
- [ ] Signal doesn't already exist (checked catalog + grep)
- [ ] Added to `plans/signals-catalog.md` in correct section
- [ ] Sender wired (UI button, action, agent, or webhook handler)
- [ ] Agent subscribes to signal (if new signal type)
- [ ] Agent or caller will mark/warn on outcome
- [ ] Signal receiver follows receiver grammar:
  - Direct: `alice`, `alice:skill`
  - World: `world:tag`, `world:tag+tag`
  - All: `all:tag`, `all:tag+tag`
  - Sub: `sub:tag`, `sub:tag+tag`

---

## Examples from Production

### Example 1: `integration:hubspot:connect`

```
Step 1: Name → integration:hubspot:connect (namespace: integration, type: vendor, subtype: event)
Step 2: Added to signals-catalog.md (Integration section)
Step 3: Wired in IntegrationsPanel.tsx:
        button → fetch('/api/signal/integration:hubspot:connect')
Step 4: Agent (import-hubspot) subscribes, imports data, marks path on success
```

### Example 2: `campaign:id:brief`

```
Step 1: Name → campaign:abc123:brief (namespace: campaign, type: id, subtype: event)
Step 2: Added to signals-catalog.md (Campaign section)
Step 3: Wired in SubmitBriefForm (server action)
Step 4: Agent (strategist or analyst) subscribes, marks path when strategy-ready
```

### Example 3: `ui:composer:send` (ad-hoc)

```
Step 1: Name → ui:composer:send (namespace: ui, surface: composer, action: send)
Step 2: Added to signals-catalog.md (UI events section)
Step 3: Wired in Composer.tsx button
Step 4: No agent subscription (pure UI event); caller marks for learning
```

---

## When to NOT Add a Signal

- ❌ **If it fits into an existing signal** — extend the subtype instead
  - Bad: `campaign:create`, `campaign:update`, `campaign:delete`
  - Good: `campaign:lifecycle` with subtype in data: `{ event: 'create' | 'update' | 'delete' }`
- ❌ **If it's a database read/write** — use `/api/export/<dim>` or RESTful endpoints instead
  - Bad: `campaign:read`, `campaign:save`
  - Good: `GET /api/export/campaigns?from=X&limit=200`
- ❌ **If it's a state query** — read via highways instead
  - Bad: `campaign:get-status`
  - Good: `GET /api/follow/campaign-status` (via path strength)

---

## Validation (W4 Checklist)

After wiring, verify:

1. **Signal can be sent** — call endpoint manually
   ```bash
   curl -X POST https://one.ie/api/signal/myname:test \
     -H 'Content-Type: application/json' \
     -d '{"test": true}'
   ```

2. **Agent receives it** — check nanoclaw Worker logs / TypeDB query
   ```
   SELECT $s FROM signal($s: $sig) WHERE $sig.receiver = "myname:test"
   ```

3. **Mark/warn works** — call endpoint with outcome
   ```bash
   curl -X POST https://one.ie/api/mark/entry%3Emyagent \
     -H 'Content-Type: application/json' \
     -d '{"strength": 1}'
   ```

4. **Path visible** — query highways
   ```bash
   curl https://one.ie/api/export/highways?from=entry&limit=200
   ```

---

*Signals are the syntax. The naming convention is the vocabulary. The closed loop (signal → outcome → mark/warn) is the grammar.*
