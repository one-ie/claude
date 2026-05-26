# walrus-sites.md — Walrus Sites Integration

**Owner:** CLI + SDK surface  
**Classifier:** spec=locked, variance=known, exit=`oneie site publish` deploys agent profile to Walrus, lifecycle=construction, mode=lean

Walrus Sites is a decentralized static hosting layer built on [Walrus](https://wal.app) (MystenLabs decentralized storage) + Sui (ownership and naming). Sites live as blobs on Walrus, indexed by a Sui object, resolved via portals (public: `wal.app`) or SuiNS domains (`agent-name.wal.app`).

**Fit verdict: high.** ONE already uses Sui for wallet identity. Walrus Sites extends that naturally — every agent gets a permanent, censorship-resistant URL it actually owns. The one-ie/one demo web app is Astro 6 static output and can be deployed on Walrus Sites today.

---

## What Walrus Sites is

```
Files (HTML/CSS/JS)  →  Walrus blobs (erasure-coded, 4.5x replication)
Site object (Sui)    →  onchain index: path → blob ID
Portal (wal.app)     →  resolves subdomain, fetches blobs, serves to browser
SuiNS               →  human-readable: stake.wal.app, agent-name.wal.app
```

- **Static only** — no server-side rendering, no secrets, all content public
- **Ownership** — Sui address owns the site object; transferable, composable
- **Storage cost** — ~$50/TB/yr (WAL tokens), deployed per-epoch (14d mainnet)
- **Max blob** — 13.3 GB; max duration ~742 days (53 epochs)
- **CLI** — `site-builder deploy --epochs <n> <dist/>` 

---

## Where it fits in ONE

### 1. Agent identity pages (primary use case)

Every agent defined in `agents/*.md` has a Sui address (from ONE's wallet, per `wallet.md`). Compiling that agent's markdown to a static profile page and deploying it to Walrus gives the agent a permanent, portable URL it owns — not hosted by one.ie, not dependent on Cloudflare, not revocable by anyone but the agent's key.

```
agents/alice.md  →  build  →  dist/
                          →  site-builder deploy  →  Walrus blob
                                                →  Sui site object (owned by alice's address)
                                                →  alice.wal.app
```

The agent's Walrus Site URL becomes their canonical identity anchor — linkable from `/u/alice`, embeddable in A2A artifacts, resolvable without one.ie being online.

**Profile page content (static):**
- Agent name, bio, avatar
- Skills list (from frontmatter)
- Sui address + payment link (x402 / SUI)
- Signal endpoint: `https://api.one.ie/signal/<receiver>`
- QR code for mobile wallet pairing

### 2. `oneie site` verb family (CLI extension)

`cli/src/index.ts` gains a `site` command group:

| Verb | Action |
|------|--------|
| `oneie site build <agent.md>` | Compile agent markdown → static HTML in `dist/` |
| `oneie site publish <agent.md> [--epochs N]` | Build + `site-builder deploy` → returns Walrus URL |
| `oneie site update <agent.md> --id <object-id>` | Rebuild + `site-builder update` |
| `oneie site open <agent.md>` | Open agent's Walrus URL in browser |

Prerequisites checked at runtime:
```bash
which site-builder || echo "Run: suiup install site-builder@mainnet"
```

### 3. `web/` demo deployment

The `web/` Astro 6 app in this repo is the ONE demo. Its `bun run build` output is a static `dist/` directory — deployable on Walrus Sites as-is.

```
web/  →  bun run build  →  dist/
                       →  site-builder deploy --epochs 4 dist/
                       →  one.wal.app  (via SuiNS)
```

This gives the open-source demo a permanent, censorship-resistant home that lives alongside the GitHub repo. Anyone can verify the demo matches the source.

### 4. Skill manifests

Published skills (`oneie skill publish`) can include a Walrus-hosted capability page:
- Skill name, description, input/output schema
- Usage examples
- Pricing (WAL/SUI per call)
- Signal endpoint

The Walrus URL becomes the skill's canonical `@id` in JSON-LD, making skills discoverable without a central registry.

### 5. Group landing pages

Groups (dimension 1) can have Walrus Sites as their public face — team pages, project sites, DAO portals. The group's Sui multisig address owns the site object, so governance of the page follows the group's on-chain governance.

---

## What it does NOT replace

| ONE surface | Why Walrus Sites can't replace it |
|-------------|-----------------------------------|
| one.ie | SSR on CF Workers — dynamic routes, auth, TypeDB queries |
| api.one.ie | Real-time signals, streaming SSE, D1/KV writes |
| /chat | WebSocket + AI SDK streaming |
| Authenticated /u pages | Session-gated, per-user data |

Walrus Sites is additive — it extends ONE's identity surface without replacing the dynamic substrate.

---

## Economics

| Item | Cost |
|------|------|
| 1 agent profile page (~50 KB) × 4 epochs (56 days) | < 0.01 WAL |
| demo site (~2 MB) × 4 epochs | < 0.05 WAL |
| WAL token | ~$0.30–$0.50 (May 2026) |
| SuiNS domain (optional) | One-time SUI fee |

Cost is negligible. Storage is the cheapest part of the agent identity stack.

---

## Implementation plan (lean)

**Goal:** `oneie site publish agents/alice.md` deploys alice's profile to Walrus and prints her URL.

**Tasks:**

1. `cli/src/site.ts` — `site` command group (build / publish / update / open)  
   - `build`: read agent markdown frontmatter → render static HTML template → write to `dist/`
   - `publish`: call `site-builder deploy` via `execa`, parse stdout for object ID + URL, write back to agent frontmatter as `walrus_site:` field
   - `update`: check frontmatter for existing `walrus_site.object_id`, call `site-builder update`
   - `open`: open `walrus_site.url` in browser

2. `cli/src/templates/site.html` — minimal static profile template  
   - Name, bio, avatar, skills list, Sui address, signal endpoint
   - Inline CSS — no external deps (Walrus Sites load from blobs, no CDN)
   - Dark mode, mobile-first, <50 KB total

3. `cli/src/index.ts` — register `site` command group

4. `web/` — add `bun run deploy:walrus` script to `web/package.json`:
   ```
   bun run build && site-builder deploy --epochs 4 dist/
   ```

5. `agents/templates/agent.md` — add optional `walrus_site:` block to frontmatter schema

**Verify:** `oneie site publish agents/templates/agent.md --dry-run` → prints HTML to stdout, no deploy.

**Close:** `oneie site publish` integration test against Walrus testnet passes; URL resolves at portal.

---

## Constraints

- `site-builder` must be installed separately (`suiup install site-builder@mainnet`)
- Wallet with WAL balance required for mainnet deploy; testnet faucet for dev
- All content public — never include private keys, session tokens, or user PII in site build output
- No service workers, no SSR — all interactivity must be vanilla JS or a small preact bundle
- SuiNS domain is optional; base36 subdomain works without it

---

## See also

- `wallet.md` — Sui address lifecycle; agent address is the Walrus site owner
- `agents/` — agent markdown definitions compiled by `oneie site build`
- `cli/src/index.ts` — existing verb surface; `site` extends it
- `web/` — demo app, first Walrus Sites deploy candidate
- [Walrus Sites docs](https://docs.wal.app) · [site-builder CLI](https://github.com/MystenLabs/walrus-sites) · [wal.app portal](https://wal.app)
