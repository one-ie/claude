# Create Astro Page

**Category:** astro
**Version:** 2.0.0
**Used By:** `astro` skill · `/do` W3 edit wave

## Purpose

Add a route under `one.ie/web/src/pages/`. Decide first: prerendered shell (cheap, no
worker) or SSR page (reads bindings). `output: 'server'` means SSR is the default —
opt out explicitly.

## Example

Prerendered shell — the common case. Modelled on the real `src/pages/activity.astro`:

```astro
---
export const prerender = true
import Layout from "@/layouts/Layout.astro"
import { ActivityFeed } from "@/components/activity/ActivityFeed"
---

<Layout title="Activity — ONE" sidebar="none">
  <ActivityFeed client:only="react" />
</Layout>
```

SSR page reading a Cloudflare binding — note the **dynamic** import; a top-level
`import { env } from "cloudflare:workers"` breaks prerender and is used nowhere in
this tree:

```astro
---
export const prerender = false
import Layout from "@/layouts/Layout.astro"
import { Dashboard } from "@/components/Dashboard"

const { env } = await import('cloudflare:workers' as string)
const rows = await env.DB.prepare("SELECT id, name FROM things LIMIT 20").all()
---

<Layout title="Dashboard — ONE" sidebar="full">
  <Dashboard client:load rows={rows.results} />
</Layout>
```

`Layout` requires `title`; useful optional props include `description`, `sidebar`
(`none | mini | full | rail`) and the `chat*` family. Read `src/layouts/Layout.astro`
for the full `Props` interface before inventing one.

Hydration: above-fold → `client:load`, below-fold → `client:visible`, heavy deps →
`client:only="react"`.

## Version History

- **2.0.0** (2026-08-02): Replaced the Convex example (Convex is not a dependency of
  this repo) with the two real page shapes and the dynamic `cloudflare:workers` import.
- **1.0.0** (2025-10-18): Initial implementation
