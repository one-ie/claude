# Complete Signal Catalog — ONE Substrate

**Version:** 0.1.0  
**Status:** Living document (gaps tracked from SDK, API, and GTM analysis)  
**Last updated:** 2026-05-21

---

## Quick Start

A signal is `{ receiver, data }` routed via 5 modes:

| Mode | Example | Meaning |
|------|---------|---------|
| **Direct** | `alice` | Send to specific actor |
| **Direct + skill** | `alice:review` | Ask actor to do a task |
| **World** | `world:review` | Find the best reviewer |
| **World + tags** | `world:review+P0` | Find reviewer with tags |
| **All** | `all:review` | Every capable reviewer |
| **Subscribe** | `sub:news:crypto` | All subscribers |

---

## Implemented Signals (Production)

### Campaign Signals

```
campaign:<id>:brief
campaign:<id>:strategy-needed / strategy-ready
campaign:<id>:audience-needed
campaign:<id>:copy-needed / copy-ready
campaign:<id>:design-needed / design-ready
campaign:<id>:analyse / report-ready
campaign:<id>:touchpoint-plan-needed
campaign:<id>:measurement-plan-needed
campaign:<id>:card-ready
```

### Core Business Signals

```
signal:payment              — payment received/failed
signal:purchase             — order placed
signal:engagement           — user interaction (open, click, view)
signal:refund               — refund processed
```

### Workspace Lifecycle

```
billing:<state>
agents:publish / unpublish / update / rollback
skill:import / delete
workspace:create / settings-update
auth:signin / logout / link-account / mfa-enabled
capability:grant
role:promote
```

### Group/Dimension Signals

```
groups:campaign:create / update
groups:persona:create / update
groups:offer:create / update
groups:actor:merge / split
```

### Funnel & Events

```
agent:<id>:event
funnel:aggregate:hourly
ui:<surface>:<action>
```

### Data & Integrations

```
import:hubspot / salesforce / klaviyo / stripe / shopify / clearbit / apollo / ga4 / tiktok
export:hubspot / salesforce / google / tiktok
```

### Learning & Paths

```
highway:<source>:<target>
fade:<source>:<target>
learning:hypothesis
learning:know
```

---

## Partially Implemented (Beta)

### Webhooks & Notifications

```
webhook:delivered / failed / retry
notification:email / sms / push / slack / telegram
```

### Chat & Agent Communication

```
chat:message
chat:thread:created / resolved
agent:response / timeout / error
```

### Audit & Compliance

```
audit:api-call
audit:permission-change
audit:data-access
audit:export
```

### Analytics & Monitoring

```
analytics:event / cohort / segment
performance:slow / error
health:check
```

---

## Proposed Signals (From Gap Analysis)

### Intent Signals (UnifyGTM gap)

```
intent:newhire              — new hire detected
intent:jobtitle-change      — decision maker changed roles
intent:website-visit        — website visitor identified
intent:product-usage        — product usage detected
intent:buying-signal        — buying intent score
intent:competitor-mention   — company mentioned competitor
intent:hiring-spree         — company posting jobs
intent:funding              — funding announced
```

### E-Commerce Signals

```
ecommerce:cart-abandoned
ecommerce:product-viewed
ecommerce:wishlist-added
ecommerce:review-posted
ecommerce:return-initiated
ecommerce:review-request
ecommerce:loyalty-tier
```

### Support & NPS

```
support:ticket-created / resolved
support:sentiment-negative
nps:response / detractor / promoter
churn:risk / churned
```

### Sales & Deals

```
sales:opportunity-created
sales:stage-change
sales:won / lost
sales:contract-sent / signed
sales:onboarding-started / complete
```

### Social & Content

```
social:mention / share / influencer-interest
content:published / viral
video:watched
```

### Marketing Campaigns

```
campaign:launched / paused / budget-reached
campaign:performance-alert / winner-declared
email:opened / clicked / bounced
sms:delivered / failed
```

### Marketplace (Blockchain)

```
token:minted / burned
nft:listed / sold
swap:executed
bridge:completed
staking:active / unstaking:initiated
```

### ML & Learning

```
model:trained / evaluated / deployed
feature:extracted / importance-updated
anomaly:detected
forecast:generated
```

### API Errors & Limits

```
api:rate-limit
api:timeout
api:error-<code>
api:retry-exhausted
api:circuit-open
api:quota-reset
```

### Data Quality

```
data:validation-failed
data:deduplication
data:missing-field / type-mismatch
data:freshness-warning
data:integrity-check
```

### Infrastructure & Cost

```
cost:exceeded-budget / forecast-warning
compute:quota-warning
storage:quota-warning
api-call:expensive
database:slow-query
worker:cold-start / memory-high
```

### Agent Coordination

```
agent:needs-review
agent:blocked
agent:ready
agent:cost-override
agent:rate-limited
agent:retry
```

---

## Signal Grammar

```
receiver := actor | world-addr | all-addr | sub-addr
actor    := <aid> [":" <skill>]
world    := "world" [":" <tag-expr>]
all      := "all" ":" <tag-expr>
sub      := "sub" ":" <tag-expr>
tag-expr := <tag> ("+" <tag>)*
```

---

## Receiver Namespace Convention

```
agent:<id>:<action>        — agent operations
skill:<action>             — skill operations
campaign:<id>:<event>      — campaign workflow
groups:<type>:<action>     — group CRUD
auth:<event>               — authentication
billing:<state>            — payment lifecycle
import:<source>            — inbound data
export:<target>            — outbound data
signal:<type>              — core business signals
intent:<source>            — buying intent
social:<event>             — social media
support:<event>            — customer support
sales:<event>              — sales cycle
ecommerce:<event>          — shopping
api:<class>:<code>         — API errors
data:<check>               — data quality
cost:<alert>               — billing/compute
```

---

## API Endpoints (Status)

| Endpoint | Status | Notes |
|----------|--------|-------|
| `POST /api/signal/<receiver>` | ✅ | Fire-and-forget |
| `POST /api/ask/<receiver>` | ✅ | Synchronous (30s) |
| `GET /api/receivers` | ❌ | **CRITICAL: needed for discovery** |
| `GET /api/signals` | ⚠️ | Event query exists |
| `POST /api/mark/<edge>` | ✅ | Strengthen path |
| `POST /api/warn/<edge>` | ✅ | Weaken path |
| `GET /api/fade` | ✅ | Asymmetric decay |
| `GET /api/follow/<tag>` | ✅ | Best path |
| `GET /api/select/<tag>` | ⚠️ | Not exposed in SDK |
| `POST /api/sub/<topic>` | ✅ | Subscribe |
| `DELETE /api/sub/<topic>` | ⚠️ | Unsubscribe |
| `GET /api/highways` | ✅ | Query learned paths |
| `GET /api/audit-logs` | ❌ | **CRITICAL: missing** |

---

## Gaps Summary

### API & Discovery (HIGH PRIORITY)

1. **Receiver introspection** — `GET /api/receivers` missing
2. **OpenAPI spec** — not published
3. **Rate limiting headers** — X-RateLimit-* not returned
4. **Receiver versioning** — no breaking change protocol
5. **Audit API** — no programmatic access

### Signal Coverage (MEDIUM PRIORITY)

1. **Intent signals** — no new hire, job change detection
2. **E-commerce signals** — limited product, cart signals
3. **Support signals** — no ticket, NPS signals
4. **Social signals** — no mention, share signals
5. **ML/AI signals** — no model training signals
6. **Marketplace signals** — no token, NFT signals
7. **Cost signals** — no budget, quota signals
8. **API error signals** — no rate-limit, timeout signals

### Implementation (LOW PRIORITY)

1. Signal templates — premade payloads
2. Signal replay — re-emit historical signals
3. Signal filtering — advanced query
4. Signal versioning — version receiver contracts
5. Receiver ACLs — restrict who can signal
6. Signal scheduling — emit at future time
7. Signal batching — batch multiple signals
8. Signal priority — urgent signals skip queue

---

## How to Add a New Signal

1. Check `dictionary.md` — does the name exist?
2. Update this file — add to "Proposed" section
3. Pick receiver name — follow namespace convention
4. Implement receiver — add handler or via agent
5. Document in agent — add to `subscribes:` or `emits:`
6. Test end-to-end — fire, verify, mark/warn
7. Move to "Implemented" — update this list

---

## Signal Flow (Production)

```
UI / Agent / Webhook
        │
        ▼
POST /api/signal/:receiver
POST /api/ask/:receiver
        │
        ├─→ parseReceiver() → gateSignalByRole() → isToxicFast()
        │
        ├─→ Toxic? → 200 { dissolved } (path poisoned)
        │
        ├─→ writeSignal(KV, signalId) → forward to nanoclaw Worker
        │                            ↓
        │                    Agent processes signal
        │                            ↓
        │                 writeOutcome(KV, signalId)
        │
        ├─→ pollOutcome() → { result | timeout | dissolved | failure }
        │
        └─→ On success: mark(source, target, +1) [path strengthens]
            On failure: warn(source, target, +0.5) [path weakens]
            On toxic: path marked with resistance [next time: dissolved immediately]
```

**Learning via mark/warn:**
- ✅ Successful signal delivery → mark strengthens path entry→agent
- ❌ Failed signal delivery → warn weakens path (resistance increases)
- 🚫 Toxic path (resistance ≥ 10 && resistance > strength×2) → dissolved before delivery
- 🔄 Fade runs hourly: strength ×(1-0.05), resistance ×(1-0.05)×0.5

---

## See Also

- [signal-integration.md](signal-integration.md) — **Implementation audit: 25 wired, 15 design-ready, 60+ proposed**
- [signals.md](signals.md) — Signal routing theory
- [dictionary.md](dictionary.md) — All named concepts
- [dsl.md](dsl.md) — Signal DSL & verbs
- [sdk-cli-gaps.md](sdk-cli-gaps.md) — SDK receiver discovery gaps
- [api-gaps.md](api-gaps.md) — API comparison
- [gtm-analysis.md](gtm-analysis.md) — Intent signal opportunities

---

*The world remembers. The trails decide. Subscribers raised their hand. You just send the signal.*
