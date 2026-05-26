---
name: dev
description: Start the ONE Astro dev server in `one.ie/web/` — `bun run dev` on port 4321 with HMR + islands hydration. Use when the user asks to "run the app", "start the dev server", "see it live", or to verify a UI change before commit. Scope is `one.ie/web/` only — for `agents/`, `api/`, `sync/`, `backup/` Workers use /cloudflare.
user-invocable: true
allowed-tools: Bash
---

# Start Development Server

**Skills:** `/signal` (dev server hosts `/api/*` — every signal lands here first) · `/astro` (HMR + islands hydration in local mode)

Start the Astro dev server with hot module replacement.

## Command

```bash
cd /Users/toc/Server/one-ie/one.ie/web && bun run dev
```

## Expected Output

```
┃ Local    http://localhost:4321/
┃ Network  use --host to expose
```

## Features

- Hot Module Replacement (HMR)
- Fast refresh for React components
- TypeScript error overlay
- Tailwind CSS JIT compilation

## Common Tasks

### Check if server is running

```bash
lsof -i :4321
```

### Kill existing server

```bash
pkill -f "astro dev"
```

### Run on different port

```bash
bun dev -- --port 3000
```

### Expose to network

```bash
bun dev -- --host
```
