# Signal Wiring Roadmap — Implementation Priorities

**Last updated:** 2026-05-21  
**Status:** Active (updated per [signal-integration.md](signal-integration.md))

---

## Summary

| Status | Count | Category |
|--------|-------|----------|
| ✅ Wired & shipped | 25 | Production (UI senders + agent subscriptions) |
| 🟡 Design ready | 15 | Agent definitions exist; UI senders needed |
| 📋 Proposed | 60+ | Spec'd in catalog; requires integration/feature work |

---

## Priority 1: Campaign Workflow (6 signals, 1-2 sprints)

**Impact:** Unlocks full campaign coordination loop for analyst, copywriter, designer  
**Effort:** 2-3 days  
**Files touched:** Mostly UI forms + a few agent tweaks

| Signal | Status | Work | Dependency |
|--------|--------|------|-----------|
| `campaign:<id>:brief` | 🟡 Planned | Add campaign creation form → fetch signal | — |
| `campaign:<id>:audience-needed` | 🟡 Planned | Auto-signal after brief created | brief done |
| `campaign:<id>:strategy-needed` | ✅ Wired | Signal exists in UI (Composer) | — |
| `campaign:<id>:strategy-ready` | ✅ Wired | Agent (strategist) emits | strategy-needed |
| `campaign:<id>:copy-needed` | ✅ Wired | Signal exists in UI | — |
| `campaign:<id>:copy-ready` | ✅ Wired | Agent (copywriter) emits | copy-needed |
| `campaign:<id>:design-needed` | ✅ Wired | Signal exists in UI | — |
| `campaign:<id>:design-ready` | ✅ Wired | Agent (designer) emits | design-needed |
| `campaign:<id>:analyse` | ✅ Wired | Signal exists in UI | — |
| `campaign:<id>:report-ready` | ✅ Wired | Agent (analyst) emits | analyse |
| `campaign:<id>:touchpoint-plan-needed` | 🟡 Planned | Auto-signal after strategy-ready | strategy-ready |
| `campaign:<id>:measurement-plan-needed` | 🟡 Planned | Auto-signal after strategy-ready | strategy-ready |
| `campaign:<id>:card-ready` | 🟡 Planned | Auto-signal after design-ready | design-ready |

**Tasks:**
1. Create campaign brief form + wiring (50 min)
2. Auto-signal audience-needed on brief creation (20 min)
3. Auto-signal touchpoint-plan-needed on strategy-ready (20 min)
4. Auto-signal measurement-plan-needed on strategy-ready (20 min)
5. Auto-signal card-ready on design-ready (20 min)

**Unblock:** Next: `groups:campaign:create` so agents can auto-populate campaign groups.

---

## Priority 2: Workspace Admin Signals (5 signals, 3-5 days)

**Impact:** Agents react to workspace state changes (deploy, rollback, config updates)  
**Effort:** 1 week  
**Files touched:** Agent deploy handlers, version endpoints, skill handlers

| Signal | Status | Work | Dependency |
|--------|--------|------|-----------|
| `agents:publish` | 🟡 Planned | Add signal to agent deploy endpoint | — |
| `agents:unpublish` | 🟡 Planned | Add signal to agent rollback endpoint | — |
| `agents:update` | 🟡 Planned | Add signal to agent version endpoint | — |
| `agents:rollback` | 🟡 Planned | Add signal to agent rollback endpoint | — |
| `skill:import` | 🟡 Planned | Add signal to skill upload handler | — |
| `skill:delete` | 🟡 Planned | Add signal to skill deletion handler | — |
| `workspace:settings-update` | 🟡 Planned | Add signal to settings PUT handler | — |
| `capability:grant` | 🟡 Planned | Add signal to role assignment handler | — |
| `role:promote` | 🟡 Planned | Add signal to team promotion handler | — |

**Tasks:**
1. Signal `agents:publish` in deploy endpoint (15 min)
2. Signal `agents:unpublish` in rollback endpoint (15 min)
3. Signal `skill:import` in skill upload (15 min)
4. Signal `skill:delete` in skill deletion (15 min)
5. Signal `workspace:settings-update` in settings PUT (20 min)
6. Signal `capability:grant` + `role:promote` in team endpoints (20 min)

**Unblock:** Agents can subscribe to `agents:publish` to react to new agents in workspace.

---

## Priority 3: Group Lifecycle (3 signals, 2-3 days)

**Impact:** Agents can auto-populate group metadata on creation  
**Effort:** Few days  
**Files touched:** Group mutation handlers in `/api/groups/`

| Signal | Status | Work | Dependency |
|--------|--------|------|-----------|
| `groups:campaign:create` | 🟡 Planned | Signal on campaign group creation | — |
| `groups:persona:create` | 🟡 Planned | Signal on persona group creation | — |
| `groups:offer:create` | 🟡 Planned | Signal on offer group creation | — |

**Tasks:**
1. Add signal to group creation handler (30 min × 3 = 1.5 hrs)
2. Create agent that subscribes to `groups:*:create` and enriches metadata (2 hrs)

**Unblock:** Analytics agent can auto-compute group cohorts on creation.

---

## Priority 4: Learning Signals (2 signals, 1-2 days)

**Impact:** Users see what system learned; agents validate hypotheses  
**Effort:** 1-2 days  
**Files touched:** Learning query endpoints, hypothesis UI

| Signal | Status | Work | Dependency |
|--------|--------|------|-----------|
| `learning:hypothesis` | 🟡 Exposed | Expose from agent→API (currently agent-only) | — |
| `learning:know` | 🟡 Planned | Expose explicit signal for path hardening | — |

**Tasks:**
1. Query TypeDB for learning hypotheses → expose via `/api/export/learning` (1 hr)
2. Add `learning:hypothesis` emission to agent output handler (30 min)
3. Add `learning:know` signal for explicit path hardening (30 min)

**Unblock:** UI can visualize what agents have learned.

---

## Priority 5: High-Value Integrations (3 families, 2-4 weeks)

**Impact:** Unlock intent detection, e-commerce, support use cases  
**Effort:** Major (2-4 weeks per family)  
**Files touched:** Integration handlers, new agents

### Intent Signals (`intent:*`)

- [ ] Wire 6sense API → signal `intent:newhire`, `intent:website-visit`, `intent:buying-signal`
- [ ] Wire Clearbit API → enrichment + buying intent signals
- [ ] Create agent to subscribe + route to sales team

**Effort:** 2 weeks  
**ROI:** Medium (high-value signal for GTM, but requires data source licensing)

### E-Commerce Signals (`ecommerce:*`)

- [ ] Wire Shopify webhook ingress → signal `ecommerce:cart-abandoned`, `ecommerce:product-viewed`, etc.
- [ ] Create agent to handle abandoned cart recovery
- [ ] Create agent to handle review requests

**Effort:** 1 week  
**ROI:** High (Shopify is self-service; cart abandonment is high-value)

### Support Signals (`support:*`, `nps:*`)

- [ ] Wire Intercom/Zendesk webhook ingress → signal `support:ticket-created`, `support:sentiment-negative`, `nps:detractor`
- [ ] Create agent to auto-respond to negative sentiment
- [ ] Create agent to escalate high-priority tickets

**Effort:** 1 week  
**ROI:** High (support signals unlock reactive workflows)

---

## Priority 6: Medium-Value Integrations (3 families, 3-5 weeks)

**Impact:** Extend coverage to sales, social, marketplace use cases

### Sales Signals (`sales:*`)

- [ ] Salesforce opportunity sync → signal `sales:opportunity-created`, `sales:stage-change`, `sales:won`, etc.
- [ ] Create agent to auto-notify reps on deal changes

**Effort:** 2 weeks (depends on Salesforce API stability)  
**ROI:** Medium (Salesforce is mature, but opportunity-change cadence is slow)

### Social Signals (`social:*`)

- [ ] Integrate Mention / Brandwatch → signal `social:mention`, `social:share`, `social:influencer-interest`
- [ ] Create agent to auto-flag for marketing team

**Effort:** 1 week (depends on social listening vendor API)  
**ROI:** Medium (useful for PR/marketing teams, but can be slow)

### Marketplace Signals (`token:*`, `nft:*`, `swap:*`)

- [ ] SUI mainnet listener → signal `token:minted`, `nft:listed`, `swap:executed`
- [ ] Create agent to auto-record transactions + calculate volumes

**Effort:** 1 week (blockchain RPC + contract listening)  
**ROI:** Low initially, High long-term (blockchain is core ONE bet)

---

## Priority 7: Low-Effort, High-Value Quick Wins (1-2 days)

| Signal | Work | Benefit |
|--------|------|---------|
| `receiver:introspection` | Add `GET /api/receivers` endpoint (30 min) | SDK autocomplete + API documentation |
| `signal:rate-limit` | Add rate-limit header to signal responses (15 min) | API transparency |
| `api:error-<code>` | Add error signal for API failures (1 hr) | Better error tracking |

---

## Timeline

| Wave | Signals | Duration | Notes |
|------|---------|----------|-------|
| **W1** | Campaign workflow (6) | 1-2 sprints | Highest ROI; unblocks analyst/designer coordination |
| **W2** | Workspace admin (5) + Quick wins (3) | 1 sprint | Medium effort, good UX |
| **W3** | Group lifecycle (3) | 1 sprint | Low effort, enables auto-enrichment |
| **W4** | Learning signals (2) | 1 sprint | Low effort, good UX for understanding system |
| **W5+** | Integrations (intent, e-commerce, support) | 4-6 weeks | Major impact; requires external vendor work |

---

## Acceptance Criteria (per signal)

When wiring a signal, verify:

- [ ] Signal name follows namespace convention (`<namespace>:<type>`)
- [ ] Signal added to `plans/signals-catalog.md` in correct section
- [ ] Agent subscribes to signal (if agent-driven workflow)
- [ ] UI / webhook / server action sends the signal
- [ ] Tests pass: `bun run verify`
- [ ] Manual test: send signal, verify agent receives it
- [ ] Manual test: verify mark/warn updates paths
- [ ] Signal appears in `/api/export/highways` after learning

---

## Blocked / Waiting

| Signal | Reason | Unblock |
|--------|--------|---------|
| `intent:*` family | 6sense / Clearbit licensing | Business decision on intent data |
| `social:*` family | Mention / Brandwatch API setup | Marketing team buy-in |
| `marketplace:*` family | SUI mainnet listener setup | Blockchain team readiness |

---

## See Also

- [signal-integration.md](signal-integration.md) — Full audit of what's wired vs. not
- [signal-wiring-pattern.md](signal-wiring-pattern.md) — How to add a signal (step-by-step)
- [signals-catalog.md](signals-catalog.md) — Complete signal reference
- [dictionary.md](dictionary.md) — Receiver namespace convention

---

*The signal system is ready. The roadmap guides implementation. The priorities balance ROI, effort, and unblocking dependencies.*
