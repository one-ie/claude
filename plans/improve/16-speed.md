# 16-speed — gap analysis

Source: `text/16-speed.md` (the claim), `text/build/lighthouse/*` (the measurement, 2026-05-15), `web/src/pages/*.astro` (the implementation).

---

## Promise (numeric)

From `text/16-speed.md`:

| Surface | Promised | Note |
|---|---|---|
| /chat Lighthouse | **100 / 100 / 100 / 100** (perf / a11y / BP / SEO) | header table line 21 + page-section claim line 36 |
| /chat FCP | 0.4s | line 38 |
| /chat LCP | 0.4s | line 38 |
| /chat TBT | 0 ms | line 38 |
| /chat CLS | 0.003 | line 38 |
| /chat payload | 248 KiB | line 38 |
| /chat TTFB | 97ms p50 (warm 90–120ms) | line 134 |
| TTFT (first token) | 97ms p50 (< 300ms claim) | line 22 |
| Routing decision | < 0.005ms | line 142 |
| Highway cache (KV) | < 10ms | line 144 |
| Hot reload | < 100ms | line 23 |
| Cold build | 23s | line 181 |
| Deploy total | 107s | line 24, dated 2026-04-14 |
| Wallet p50 | 5s (p95 < 9s) | lines 25, 363 |
| Checkout (signup → live link) | 60s | line 26 |
| TTFAPIC | 60s | line 27 |
| Time to value | 3min | line 28 |

Speed page also claims 7 other surfaces score perfect or near-perfect Lighthouse via the "no other AI chat page scores three perfect hundreds" wording (line 42).

---

## Measured today

### /chat — production (`one.ie/chat`)

Source: `text/build/lighthouse/one-chat-spec.report.json` (spec config: rttMs=40, 10Mbps, 4× CPU, mobile).

| Metric | Promised | Measured | Delta |
|---|---|---|---|
| Performance | 100 | **99** | -1 |
| Accessibility | 100 (line 21) / 91 (line 36) | **95** | -5 vs the headline, +4 vs the lower in-body number |
| Best Practices | 100 | **100** | match |
| SEO | 100 | **100** | match |
| FCP | 0.4s | **0.99s** | **2.5× slower than claim** |
| LCP | 0.4s | **1.93s** | **4.8× slower than claim** |
| TBT | 0 ms | **78ms** | failing the "0 ms" headline (still within Lighthouse "good") |
| CLS | 0.003 | **0** | better than claim |
| TTFB | 90–120ms warm | **375ms** | **3–4× slower than claim** |
| Total payload | 248 KiB | **1,313 KiB** | **5.3× heavier than claim** |

### /chat — demo (`app.one.ie/chat`)

Source: `text/build/lighthouse/demo-chat-spec.report.json`.

| Metric | Measured |
|---|---|
| FCP | **0.40s** |
| LCP | **0.40s** |
| TBT | **0 ms** |

Demo matches the claim. Production does not. The 16-speed page cites `app.one.ie/chat` (line 36) but the comparison table headers and the cross-references (line 461 "URL is one.ie/chat") point at production. Two surfaces; one number.

### Competitor baseline (spec config, same run)

From `text/build/lighthouse/comparison.md`:

- ChatGPT: 51 / 96 / 73 / 100 — LCP 5.2s, TBT 1,480ms, 4,438 KiB
- Claude (login surface only): 66 / 97 / 77 / 92 — LCP 3.2s, TBT 1,460ms, 4,234 KiB
- OpenAI Playground: 70 / 98 / 77 / 91 — LCP 3.1s, TBT 1,010ms, 953 KiB

ONE still wins on perf, BP, SEO, TBT, and bytes-on-the-wire vs every measured competitor — even on the production numbers.

### Surfaces with no published Lighthouse number

| Surface | Has hydration islands | Lighthouse run | Risk |
|---|---|---|---|
| /chat | client:idle (Chat) | yes (above) | gap above |
| / (index.astro) | client:idle (PersonalizedHero) | no | unknown |
| /dashboard | **client:load** (heavy) | per commit 55dfae7d "100/100 desktop+mobile" — no JSON in repo | unverifiable; claim only |
| /agents | **client:load** (AgentPageClient) + client:idle (ChatDock) | no | client:load is the most blocking option; likely degraded TBT/LCP |
| /create | client:load | no | same risk |
| /payments | client:idle | no | unknown |
| /settings | client:idle | no | unknown |
| /studio/[agent] | mixed (markdown-driven) | no | unknown |
| /in, /crm, /u/[slug] | not inspected | no | unknown |

### Other speed claims — no audit trail

| Claim | Evidence in repo |
|---|---|
| TTFT 97ms p50 | not reproducible from `text/build/`; no inference timing log |
| Routing < 0.005ms over "320 tests" | `text/speed.md` line 64 references "320 tests"; no test report path in `text/build/` |
| Highway cache < 10ms | no measurement file |
| Hot reload < 100ms | no measurement file |
| Deploy 107s on 2026-04-14 | claim dated; deploy log not committed to repo |
| Wallet 5s p50 across 12,400 sessions | no exported telemetry in the repo |
| Checkout 60s | "tested" — no report |
| TTFAPIC 60s | "tested" — no report |
| Time to value 3min | "tested" — no report |

Eight of the eight surfaces in the headline table are claimed measured. One (page load) has a JSON in the repo. The other seven have a date and a sentence.

---

## Gaps

### G1 — Production /chat misses the page-load headline by 5× on payload, 5× on FCP/LCP, ∞× on TBT.

The page-load table in `16-speed.md` (line 38) is the only number a reader can verify with `lighthouse one.ie/chat` in the next 60 seconds. It does not match. Performance score is 99 not 100; FCP is 0.99s not 0.4s; LCP is 1.93s not 0.4s; TBT is 78ms not 0 ms; payload is 1,313 KiB not 248 KiB. The accessibility number contradicts itself within the same doc (100 in table, 91 in section, 95 measured).

**Root cause (from `unused-javascript` audit):**

| Chunk | Size | Wasted |
|---|---|---|
| `vendor-diagrams.*.js` | 404 KiB | 324 KiB (80%) |
| `prompt-input.*.js` | 234 KiB | 157 KiB (67%) |
| `vendor-graph.*.js` | 182 KiB | 153 KiB (84%) |
| `vendor-charts.*.js` | 116 KiB | 92 KiB (79%) |
| `vendor-markdown.*.js` | 38 KiB | 29 KiB (77%) |

Almost 1 MB of JS the production /chat first-paint never executes. Demo passes because demo doesn't ship these. The fix is the lazy-import-in-islands rule from `.claude/rules/astro.md` — already documented, not yet applied to vendor-diagrams / vendor-graph / vendor-charts inside the production Chat island.

### G2 — Two button elements have no accessible name.

`button-name` audit returns 0; affects A11y score (95 → blocked at 100). Both buttons are inside the first chat-control fixed bar (`astro-island > div.relative > div.fixed > button.inline-flex`). Likely the copy/stop icon-only buttons. One `aria-label` per button restores parity. This is the only meaningful audit between today and a perfect a11y score.

### G3 — `/chat` page Lighthouse number used in marketing applies to the demo surface, not production.

The doc says `app.one.ie/chat` on line 36 and `one.ie/chat` on line 461. Different URLs, different numbers. Pick one and align the doc — preferably bring production up to demo and cite production.

### G4 — No Lighthouse JSON in the repo for any page except /chat and the four competitor controls.

`/dashboard`, `/agents`, `/index`, `/create`, `/payments`, `/settings`, `/studio/*`, `/in`, `/crm`, `/u/[slug]` — none have a committed report. Commit `55ca5164` claims `/dashboard` is 100/100 desktop+mobile. No JSON in `text/build/lighthouse/` to verify. If a reader pulls the repo and asks "where's the proof?", the answer is "in the commit message."

### G5 — `client:load` on `/agents` and `/create` AgentPageClient bypasses the lazy-island discipline.

Per `.claude/rules/astro.md`, `client:load` "hydrates on critical, above-fold, interactive." `AgentPageClient` is the whole page bundle in one island. With the same `vendor-charts / vendor-diagrams / prompt-input` import graph as `/chat`, these pages are likely 1+ MB JS each. Not measured. Risk: when `/agents` is Lighthouse-tested under the spec config it scores 70–80, not 99.

### G6 — TTFT, routing, hot-reload, deploy, wallet, checkout, TTFAPIC, TTV are all dated but unsourced.

Each row in the headline table (`16-speed.md` line 20-29) has a date and a claim. None have a committed measurement file. The page positions ONE as "the only platform with an audit trail" (line 305). Today the audit trail is a sentence. To be credible against the page's own challenge ("If a number on that table is wrong, it is verifiable") the source data needs to ship alongside the claim.

### G7 — Regression risk: nothing prevents the next deploy from breaking the demo /chat numbers.

There is no Lighthouse CI gate in the repo. The browser-check script (`.claude/scripts/browser-check.mjs`) is for debugging; the only Lighthouse run is manual. A vendor-chart import added to `Chat.tsx` next week breaks the headline number without anyone noticing until the next manual run.

### G8 — Render-blocking CSS and legacy-JS insights are at score 0.5 / 0.

`index.pMrUnBin.css` (49 KiB) blocks render for 80ms. `katex.qVo7mKyw.css` (8 KiB) is loaded on /chat — likely from a markdown component that doesn't need it on first paint. Small wins, but they hit FCP.

---

## Recommended improvements

In order — first three are required to make the doc match measured reality.

### R1 — Cut production /chat payload from 1,313 KiB to ≤ 300 KiB.

Apply `.claude/rules/astro.md` lazy-import rule to:

- `vendor-diagrams.*` (404 KiB) — diagram rendering is not first-paint; move to lazy() behind a Suspense boundary
- `vendor-graph.*` (182 KiB) — ReactFlow / graph viz; lazy
- `vendor-charts.*` (116 KiB) — Recharts / chart libs; lazy
- `vendor-markdown.*` (38 KiB) — markdown is render-on-message, not initial; can lazy-load the first message renderer
- `prompt-input.*` (234 KiB) — heavy attachments/voice modules; verify each is lazy per `web/src/components/chat/AttachmentsPreview.tsx` pattern

Target: FCP < 0.6s, LCP < 1.0s, TBT < 30ms, total bytes < 400 KiB. That restores the headline.

### R2 — Add `aria-label` to the two icon-only buttons in the chat fixed-control bar.

Single-line fix per button. Restores A11y from 95 to 100. Required to make the "100 / 100 / 100 / 100" headline true.

### R3 — Decide the canonical Lighthouse URL: production or demo.

Two options: (a) bring production to demo parity (R1 does this), then cite `one.ie/chat`. (b) Re-write `16-speed.md` to consistently cite `app.one.ie/chat` and explain why. (a) is the correct answer because the marketing page also says "Run Lighthouse on /chat right now" (line 307) — readers will run production.

### R4 — Commit a Lighthouse run for every routed page.

Add to `text/build/lighthouse/`:

- `index.report.json` — homepage
- `dashboard.report.json` — claimed 100/100, needs proof
- `agents.report.json` — high `client:load` risk
- `create.report.json` — high `client:load` risk
- `payments.report.json`, `settings.report.json`
- `studio-agent.report.json` — markdown-driven page

Wire a bun script `text/build/lighthouse/run-all.sh` that re-runs each on demand. Promote the headline `16-speed.md` table to show per-page numbers, not just /chat.

### R5 — Ship the audit trail for the other seven surfaces.

- **TTFT** — add `text/build/inference/ttft-log.json` with 100+ runs against the live `/api/ask` endpoint; cite p50/p95
- **Routing/highway** — `text/build/routing/bench.json` from a vitest bench against `web/src/engine/world.ts`
- **Hot reload** — `text/build/build/hmr-log.txt` from `bun dev` with vite-plugin-hmr-time
- **Deploy 107s** — commit the wrangler deploy log (or a redacted version) as `text/build/deploy/2026-04-14.log`
- **Wallet 5s** — export from the substrate the actual `wallet:create` event timings as `text/build/wallet/april-2026.csv`
- **Checkout / TTFAPIC / TTV** — Playwright recordings under `text/build/journeys/`

Without these, the "we measure back" line is rhetoric.

### R6 — Add Lighthouse CI gate.

`.github/workflows/lighthouse.yml` (or `.claude/scripts/lighthouse-gate.sh` if no CI yet). Spec config from `text/build/lighthouse/spec-config.json`. Gate at perf ≥ 99, a11y ≥ 95, TBT ≤ 100ms, total bytes ≤ 400 KiB on /chat. Fail the PR on regression. Without this gate, R1 will be re-broken within four cycles.

### R7 — Address `cache-insight` and `render-blocking-insight`.

- Cloudflare Insights beacon (12 KiB) — 24h cache is fine; ignored.
- `usal.min.js` — 7d cache; ignored.
- `index.pMrUnBin.css` 49 KiB blocking 80ms — split into critical (inline in `<head>`, already partially done) and async non-critical (preload + onload swap).
- `katex.qVo7mKyw.css` — move out of `/chat` first-paint; only load when a message contains math.

Worth ~80ms FCP, ~50ms LCP.

### R8 — Align the speed-doc internal contradictions.

Line 21 says A11y 100; line 36 says 91; measurement says 95. Pick one and propagate. Same for the "/chat URL" (R3). The page's credibility depends on its own internal consistency before its claims against competitors.

---

## Files to touch

| File | Change | Improvement |
|---|---|---|
| `web/src/components/Chat.tsx` (and `web/src/components/chat/*`) | `lazy()` + `<Suspense>` for diagrams / graphs / charts / markdown / attachments imports | R1 |
| `web/src/components/chat/<icon-button-component>.tsx` | add `aria-label` to copy + stop buttons | R2 |
| `text/16-speed.md` | lines 21, 36, 38, 461 — reconcile numbers and URL after R1+R2 land | R3, R8 |
| `text/build/lighthouse/` | add `index.report.json`, `dashboard.report.json`, `agents.report.json`, `create.report.json`, `payments.report.json`, `settings.report.json`, `studio-agent.report.json` | R4 |
| `text/build/lighthouse/run-all.sh` (new) | wraps `lighthouse <url> --config-path=spec-config.json` per page | R4 |
| `text/build/inference/` (new) | `ttft-log.json` and the script that produces it | R5 |
| `text/build/routing/bench.ts` (new) | vitest bench against `web/src/engine/world.ts` | R5 |
| `text/build/deploy/2026-04-14.log` (new) | redacted wrangler output | R5 |
| `text/build/wallet/april-2026.csv` (new) | substrate-exported wallet:create timings | R5 |
| `.github/workflows/lighthouse.yml` or `.claude/scripts/lighthouse-gate.sh` (new) | CI gate per R6 thresholds | R6 |
| `web/src/layouts/Layout.astro` | move `katex` out of critical CSS path; split `index.pMrUnBin.css` if oversized | R7 |
| `web/src/pages/agents.astro`, `create.astro` | reconsider `client:load` → `client:idle` where possible; lazy-split `AgentPageClient` | G5 mitigation |

---

## Verify (after R1-R3)

```bash
cd /Users/toc/Server/one-ie/one/text/build/lighthouse
lighthouse https://one.ie/chat \
  --config-path=spec-config.json \
  --chrome-flags="--headless=new --no-sandbox" \
  --output=json --output-path=one-chat-spec
jq '.categories | to_entries | map({k:.key, v:.value.score})' one-chat-spec.report.json
jq '{fcp:.audits["first-contentful-paint"].numericValue, lcp:.audits["largest-contentful-paint"].numericValue, tbt:.audits["total-blocking-time"].numericValue, bytes:.audits["network-requests"].details.items | map(.transferSize) | add}' one-chat-spec.report.json
```

Pass = perf 100, a11y 100, BP 100, SEO 100, FCP < 0.6s, LCP < 1.0s, TBT < 30ms, bytes < 400 KiB.
