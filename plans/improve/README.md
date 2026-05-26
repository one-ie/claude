# plans/improve/ — gap analysis index

Generated 2026-05-17. 20 parallel agents, one per text/* doc. Each file maps
marketing promise → code reality → gaps → ordered recommendations.

---

## Biggest gaps by severity

### Critical (claim vs code contradicted)

| File | Gap |
|------|-----|
| `15-security.md` | Wallet is a stub returning nulls — no PRF/largeBlob, no `wrappings[]`, BIP39 generated server-side and sent over the wire. Per-tenant KEK is one platform-wide `PII_ENVELOPE_KEY`. |
| `01-auth.md` | Better Auth not in `package.json`. Single-method passkey only (`@simplewebauthn`). No Google/magic-link/wallet/MCP-OAuth. No `/signin` or `/join`. `PasskeyKeepThis` posts empty body. |
| `13-learning.md` | L5 (prompt evolution) and L6 (knowledge hardening) have no runtime. `generation` never increments. Asymmetric fade is inverted vs spec. L3 fade not scheduled. |
| `06-skills.md` | Every skill's `execute()` returns `[${skillName}] processed: ${input}` — placeholder string. No model invocation, no mark/warn. |
| `07-tools.md` | Three parallel connect flows; `/api/tools/*` returns `#stub`; UI wired to stubs; Composio endpoint orphaned. |
| `08-memory.md` | L6 `know()` loop and L3 `fade()` scheduler missing from `claw/src/cron.ts`. Hypotheses only written by tool call, never auto-promoted. |
| `02-agency.md` | Billing cascade not wired — `monthly_cap`, `markup_pct`, `agency_margin` never enforced. No Stripe Connect. Revenue path is platform-direct €49/mo only. |

### High (significant surface missing)

| File | Gap |
|------|-----|
| `00-cover.md` | Home page shows generic pitch; none of the proof numbers (60s/48h/90s/$5.4M ARR) appear. 7 of 16 TOC chapters have no destination page. |
| `03-chatbots.md` | iMessage/WhatsApp adapters missing. Discord lacks ed25519 Interactions endpoint. Cross-channel actor-merge not built. Three separate streaming contracts instead of one `RichMessage`. |
| `04-models.md` | `/api/chat` hard-codes `groq/llama-3.3-70b-versatile`, ignores `model:` frontmatter. Flat billing `tokens × $0.000002` regardless of model — per-model credit table is fiction. |
| `05-agents.md` | Rubric eval gate (blocks `draft→live` at 0.65) doesn't exist. `agent sign` returns `{ bundle: 'pending' }`. `compile --target` is a placeholder. |
| `09-teams.md` | `reports_to`/`manages`/`approval_threshold`/`voice` frontmatter fields not declared or parsed. 6 templates across 3 departments instead of 27. Approval runtime and weekly digest unimplemented. |
| `10-tracking.md` | Web pixel (`/p/one.js`) doesn't exist. Channel adapters don't write `AgentEvent` rows. No email pixel, no HMAC-signed `/go/:id`. |
| `11-analytics.md` | Monthly client PDF not built. Dashboard hero numbers are hard-coded literals. `revenue.ts` is a stub returning `0`. |
| `12-crm.md` | Only `/crm/c/[actor].astro` exists; `/crm/g/`, `/crm/j/`, `/crm/b/`, `/crm/pulse` missing. `appended:[]` hardcoded; `sameAs:[]` stubbed. |
| `14-development.md` | CLI ships 0 of 12 substrate verbs, 0 of 8 commerce verbs. `npx oneie signal/ask/mark` fails with "unknown command". |
| `16-speed.md` | Production `one.ie/chat` ships 1,313 KiB vs claimed 248 KiB. FCP 0.99s / LCP 1.93s vs claimed 0.4s / 0.4s. |

### Medium (copy/surface mismatch)

| File | Gap |
|------|-----|
| `01-brand.md` | White-label `merge()`/`resolveConfig()` implemented but never invoked. No `embed.js`. No DNS verification. |
| `landing-page-anatomy.md` | `/` missing demo, testimonials, FAQ, pricing. `Pricing.tsx` exists but orphaned. `/payments` is 9-line stub. |
| `persona-agency-owner.md` | No `/agency` route. No agency tile on home. Agency dashboard (portfolio, client CRUD, markup) doesn't exist in-repo. |
| `contents-and-quotes.md` | TOC has 16 chapters; site has routes for ~5. Pull-quotes from `quotes.md` not used anywhere in the UI. |

---

## Files in this directory

| File | Covers |
|------|--------|
| `00-cover.md` | Cover page + home framing |
| `01-auth.md` | Authentication (passkeys, Better Auth, flows) |
| `01-brand.md` | Brand editor, white-label cascade, embed |
| `02-agency.md` | Agency tier, billing, multi-client, Stripe Connect |
| `03-chatbots.md` | Chat surfaces (Web / Telegram / Discord / Groups) |
| `04-models.md` | Model picker, OpenRouter, per-model billing |
| `05-agents.md` | Agent authoring, runtime, eval gate, signing |
| `06-skills.md` | Skill execution, marketplace, CLI verbs |
| `07-tools.md` | Tool connections, Composio, approval gate |
| `08-memory.md` | Memory types, L3/L6 loops, web crawler |
| `09-teams.md` | Marketing/Sales/Service department agents |
| `10-tracking.md` | Tracked links, pixel, attribution, events |
| `11-analytics.md` | Dashboards, reporting, PDF, revenue data |
| `12-crm.md` | People CRM routes, enrichment, identity ladder |
| `13-learning.md` | L5 evolution, L6 knowledge, pheromone loops |
| `14-development.md` | SDK, CLI, MCP, Python, deploy verbs |
| `15-security.md` | Wallet, KEK, passkey PRF, threat model |
| `16-speed.md` | Lighthouse, bundle sizes, performance claims |
| `landing-page-anatomy.md` | Anatomy compliance per page |
| `persona-agency-owner.md` | Agency Owner persona coverage |
| `contents-and-quotes.md` | TOC ↔ routes parity, quote deployment |
