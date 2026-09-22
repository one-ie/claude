---
name: w4-tools
description: Per-dimension verification tool recipes for a W4 verify agent, loaded on demand. Not a spawnable agent — a companion reference to w4-verify.md, split out so a W4 spawn does not pay ~9KB it usually does not use.
---

# W4 — verification tooling (loaded on demand)

Companion to `.claude/agents/w4-verify.md`. Split out 2026-09-01: this block is
~9KB of per-dimension tool recipes that a W4 agent pays for on every spawn but
uses only when the cycle's dimensions call for them.

**The security grep at the end is NOT optional.** It is the zero-LLM backstop a
scored security dimension cannot replace; W4 runs it on every cycle. Everything
above it is conditional on the dimension being scored.

---

## Verification Tools

Use these to produce the numbers — not estimates.

### Lighthouse (Speed dim)

**File → route map** (derive pages to audit from files touched in W3):

| Touched path pattern | Audit URL |
|---------------------|-----------|
| `src/pages/index.astro` | `http://localhost:4321/` |
| `src/pages/get-yours.astro` | `http://localhost:4321/get-yours` |
| `src/pages/u/**` | `http://localhost:4321/u/demo` |
| `src/components/chat/**` | `http://localhost:4321/chat` |
| `src/components/**` | `http://localhost:4321/` + `/chat` |
| `src/layouts/**` | all pages |
| `src/pages/api/**` | skip (server routes — no Lighthouse) |

**Pre-flight check before running:**

```bash
# 1. Check lighthouse is installed
which lighthouse || npx lighthouse --version 2>/dev/null
LIGHTHOUSE_OK=$?

# 2. Check dev server is up (start it if needed)
curl -sf http://localhost:4321/ > /dev/null 2>&1
SERVER_OK=$?

if [ $SERVER_OK -ne 0 ]; then
  bun run dev > /tmp/dev-server.log 2>&1 &
  DEV_PID=$!
  # Poll until ready (max 15s)
  for i in $(seq 1 15); do
    sleep 1
    curl -sf http://localhost:4321/ > /dev/null 2>&1 && break
  done
  curl -sf http://localhost:4321/ > /dev/null 2>&1
  SERVER_OK=$?
fi
```

**If both available — run Lighthouse:**

```bash
# Run against each derived page URL
npx lighthouse http://localhost:4321/chat --output=json --quiet \
  --chrome-flags="--headless --no-sandbox" \
  | jq '{
      perf: (.categories.performance.score * 100 | round),
      a11y: (.categories.accessibility.score * 100 | round),
      bp:   (.categories["best-practices"].score * 100 | round),
      seo:  (.categories.seo.score * 100 | round),
      failing_audits: [.audits | to_entries[]
        | select(.value.score != null and .value.score < 1)
        | {audit: .key, score: .value.score, desc: .value.description}]
  }'
```

Scores are 0–1 from Lighthouse; multiply by 100. Target is 100 on all four.
The `failing_audits` array tells you exactly which audit to fix — include these in the
`→ improve:` instruction so the next cycle knows precisely what to address.

**If Lighthouse unavailable — fallback scoring:**

```
Score speed on what IS measurable, as ABSOLUTES — there is no W0 baseline to
subtract (rung A5 deleted its writer, so a "delta vs W0" has no second operand):
  - Bundle size: the KB the build prints
  - Build time: buildMs from `bun run build`
  - Hydration grep: no new client:load where client:idle suffices

Cap speed score at 0.80 when Lighthouse skipped.
Flag in receipt: "lighthouse: skipped — run manually to confirm 100%"
Do NOT score 1.0 for speed without a real Lighthouse number.
```

### Playwright (functional + a11y verification)

Playwright runs only when the cycle declares `requires_playwright: true` (testing policy,
`.claude/commands/do.md`). Vitest is the default; do not add a Playwright gate to a cycle
that did not ask for one.

```bash
# Only if the cycle declares requires_playwright AND a config exists
if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
  npx playwright test --reporter=line 2>&1 | tail -20
  # a11y scan (axe-playwright) on touched pages — if that suite exists
  [ -d tests/a11y ] && npx playwright test tests/a11y --reporter=line
else
  echo "playwright: n/a — no config in this folder"
fi
```

Playwright failures are stability failures — they join the vitest gate.
A11y failures from playwright count against the Accessibility Lighthouse category.
Absent config → `playwright: n/a`, never a silent pass.

### Bundle size (Speed dim)

```bash
# Check CF Worker bundle size
npx wrangler deploy --dry-run --outdir=.wrangler/output 2>&1 | grep -E 'Total|gzip'

# Or check Astro build output (in the package folder — no root package.json)
FOLDER="${FOLDER:-one.ie/web}"
( cd "$FOLDER" && bun run build ) 2>&1 | grep -E 'dist/|\.js|\.css|kB'

# Absolute numbers only. No W0 delta — the baseline file has no writer (rung A5).
```

### TypeScript strict check (Stability dim)

```bash
npx tsc --noEmit --strict 2>&1 | grep -c 'error TS'   # 0 = pass
```

### Security grep (Security dim)

```bash
# Run against the diff only (staged + unstaged changes from W3)
# secrets
git diff HEAD | grep -E '^\+' | grep -iE 'api[_-]?key|secret|password|token' \
  | grep -vE '^\+\+\+|zod|schema|type |interface |//|process\.env\.PUBLIC'

# injection vectors
git diff HEAD | grep -E '^\+.*eval\(' | grep -v '// allow'
git diff HEAD | grep -E '^\+.*dangerouslySetInnerHTML' | grep -v 'sanitize\|DOMPurify'

# Worker env access
git diff HEAD | grep -E '^\+.*process\.env' | grep -v '// allow\|PUBLIC_'

# CORS wildcard
git diff HEAD | grep -E '^\+.*Access-Control-Allow-Origin.*\*'

# TypeDB string concatenation in queries (parameterized form required)
git diff HEAD | grep -E '^\+' | grep -E 'define|match|insert' \
  | grep -E '\+\s*[`"\x27]|\.concat\(|\$\{' | grep -iE 'typedb|tql|query'
```

Zero hits across all greps = security score eligible for 1.0.
Each hit = `→ improve: file:line — what the pattern is`.
