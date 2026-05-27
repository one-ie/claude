# Twitter / X Integration

Twitter is the only Composio toolkit that requires custom OAuth credentials — Composio has no managed app for it because X restricts their OAuth ecosystem.

## Setup

### 1. Create a Twitter Developer App

1. Go to [developer.twitter.com/en/portal/dashboard](https://developer.twitter.com/en/portal/dashboard)
2. Create a new project + app
3. Under **User authentication settings**, enable **OAuth 2.0**
4. Set **Type of App** to `Web App`
5. Add this redirect URI:
   ```
   https://backend.composio.dev/api/v3/auth/callback
   ```
6. Copy the **Client ID** and **Client Secret**

### 2. Create the Composio auth-config

```bash
~/.composio/composio dev auth-configs create --toolkit twitter \
  --auth-scheme OAUTH2 \
  --custom-credentials '{"client_id":"YOUR_CLIENT_ID","client_secret":"YOUR_CLIENT_SECRET"}'
```

Or via the API directly:

```bash
curl -X POST https://backend.composio.dev/api/v3/auth_configs \
  -H "x-api-key: ak_uIuPmtBtIcht1p0voEPY" \
  -H "Content-Type: application/json" \
  -d '{
    "toolkit": { "slug": "twitter" },
    "auth_scheme": "OAUTH2",
    "credentials": {
      "client_id": "YOUR_CLIENT_ID",
      "client_secret": "YOUR_CLIENT_SECRET"
    }
  }'
```

### 3. Verify

```bash
~/.composio/composio dev auth-configs list 2>&1 | grep twitter
```

## Required Twitter App Scopes

| Scope | Why |
|-------|-----|
| `tweet.read` | Read tweets, timelines |
| `tweet.write` | Post, delete tweets |
| `users.read` | Fetch user profile |
| `offline.access` | Refresh tokens (required for long-lived connections) |

## Env / secrets

No Twitter credentials go in `.dev.vars` — they live in the Composio auth-config only. The `COMPOSIO_API_KEY` in `.dev.vars` is the only secret needed at runtime.

---

## BYOK — Users bring their own Twitter Developer credentials

For power users who have their own Twitter Developer apps (e.g. they want higher rate limits or a custom app name shown on OAuth).

### How it works

Instead of connecting through ONE's shared Twitter app, the user provides their own `client_id` + `client_secret`. A per-user auth-config is created in Composio scoped to their account, and they complete OAuth through their own app.

### Flow

```
User submits credentials
        │
        ▼
POST /api/tools/twitter/auth-config   ← server action creates per-user auth-config
        │
        ▼
Composio returns { auth_config_id, redirect_url }
        │
        ▼
User completes Twitter OAuth
        │
        ▼
Composio stores connected account under user's slug
```

### Server action — `src/pages/api/tools/twitter/auth-config.ts`

```ts
import type { APIRoute } from 'astro'
import { Composio } from '@composio/core'

export const POST: APIRoute = async ({ request, locals }) => {
  const session = locals.session
  if (!session) return new Response('Unauthorized', { status: 401 })

  const { client_id, client_secret } = await request.json() as {
    client_id: string
    client_secret: string
  }

  if (!client_id?.trim() || !client_secret?.trim()) {
    return new Response('client_id and client_secret required', { status: 400 })
  }

  const env = (await import('cloudflare:workers' as string)).env as {
    COMPOSIO_API_KEY: string
    PUBLIC_URL: string
  }

  const composio = new Composio({ apiKey: env.COMPOSIO_API_KEY })

  // Create a per-user auth-config using their own Twitter app
  const authConfig = await (composio.authConfigs as unknown as {
    create: (o: object) => Promise<{ id: string }>
  }).create({
    toolkit: { slug: 'twitter' },
    auth_scheme: 'OAUTH2',
    credentials: { client_id, client_secret },
  })

  // Initiate the OAuth connection for this user
  const connection = await (composio.connectedAccounts as unknown as {
    initiate: (o: object) => Promise<{ redirect_url: string; connection_id: string }>
  }).initiate({
    auth_config_id: authConfig.id,
    user_id: session.userId,
    redirect_url: `${env.PUBLIC_URL}/u/${session.userId}/tools/twitter?connected=1`,
  })

  return Response.json({ redirectUrl: connection.redirect_url })
}
```

### Settings UI — `src/components/tools/TwitterByok.tsx`

```tsx
import { useState } from 'react'
import { emitClick } from '@/lib/ui-signal'

export function TwitterByok({ slug }: { slug: string }) {
  const [clientId, setClientId] = useState('')
  const [clientSecret, setClientSecret] = useState('')
  const [status, setStatus] = useState<'idle' | 'busy' | 'error'>('idle')
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    emitClick('ui:tools:twitter-byok-submit')
    setStatus('busy')
    setError('')
    try {
      const res = await fetch('/api/tools/twitter/auth-config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ client_id: clientId, client_secret: clientSecret }),
      })
      if (!res.ok) throw new Error(await res.text())
      const { redirectUrl } = await res.json() as { redirectUrl: string }
      window.location.href = redirectUrl
    } catch (err) {
      setStatus('error')
      setError(err instanceof Error ? err.message : 'Failed')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">Client ID</label>
        <input
          type="text"
          value={clientId}
          onChange={e => setClientId(e.target.value)}
          placeholder="From developer.twitter.com"
          required
          className="px-3.5 py-2.5 rounded-lg bg-background text-font border text-sm focus:outline-none focus:ring-2"
          style={{ borderColor: 'var(--color-border)' }}
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">Client Secret</label>
        <input
          type="password"
          value={clientSecret}
          onChange={e => setClientSecret(e.target.value)}
          placeholder="Keep this secret"
          required
          className="px-3.5 py-2.5 rounded-lg bg-background text-font border text-sm focus:outline-none focus:ring-2"
          style={{ borderColor: 'var(--color-border)' }}
        />
      </div>
      {error && <p className="text-sm text-destructive">{error}</p>}
      <button
        type="submit"
        disabled={status === 'busy'}
        className="px-4 py-2.5 rounded-lg bg-primary text-on-primary text-sm font-medium disabled:opacity-40 hover:brightness-110"
      >
        {status === 'busy' ? 'Connecting…' : 'Connect with your Twitter app'}
      </button>
      <p className="text-xs text-font/40">
        Your credentials are sent directly to Composio and never stored on ONE servers.
        Redirect URI to add in your Twitter app:{' '}
        <code className="font-mono">https://backend.composio.dev/api/v3/auth/callback</code>
      </p>
    </form>
  )
}
```

### Where to surface the UI

Add `<TwitterByok>` to `/u/[slug]/tools/twitter` — show it as a collapsible "Use your own Twitter app" section below the main Connect button, visible to the owner only.

### Scopes — same as platform app

| Scope | Why |
|-------|-----|
| `tweet.read` | Read tweets, timelines |
| `tweet.write` | Post, delete tweets |
| `users.read` | Fetch user profile |
| `offline.access` | Refresh tokens |

The user must enable these scopes in their Twitter Developer App settings before authorizing.

---

## See also

- All other 1,100 integrations use Composio-managed OAuth — no setup needed
- Auth-config created → users connect via `/u/[slug]/tools/twitter`
- Composio project: org `e6X0hY4ETE1D`, project `wjBYhWjRHpF4`
