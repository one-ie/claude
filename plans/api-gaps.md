# API Comprehensive Comparison: ONE vs OneSignal

## Executive Summary

**OneSignal:** 45+ REST endpoints across 8 resource categories (users, subscriptions, messages, segments, events, templates, apps, analytics).

**ONE:** 4 universal endpoints + verb-surface + justified extras. Uses receiver namespace instead of resource URLs.

| Aspect | OneSignal | ONE |
|--------|-----------|-----|
| **Endpoint count** | 45+ | 4 core + verb-family (~50 handlers) |
| **API style** | RESTful (CRUD) | Event-driven (verbs + receiver namespace) |
| **Message model** | Fire-and-forget + polling | Fire-and-wait (ask) + 4 outcomes |
| **Discovery** | REST standard | Receiver namespace (not self-documenting) |
| **Auth model** | API Key + Secret | Passkey (viewer) + Gateway key + workspace |
| **Rate limiting** | Per app + endpoint | Not documented |

---

## OneSignal REST API (45+ Endpoints)

Users (5), Players (4), Subscriptions (6), Aliases (5), Messaging (5), Custom Events (1), Segments (5), Templates (6), Live Activities (2), Apps & Keys (9), Analytics (3), Audit (1)

---

## ONE API (4 Universal + Verbs)

```
POST   /api/signal/[...receiver]     Fire-and-forget
POST   /api/ask/[...receiver]        Synchronous (30s timeout)
POST   /api/mark/[edge]              Strengthen path
POST   /api/warn/[edge]              Weaken path
GET    /api/fade                     Asymmetric decay
GET    /api/follow/[tag]             Best path
GET    /api/forget/[uid]             GDPR erasure
GET    /api/select/[tag]             Probabilistic path
PUT    /api/settings                 Workspace settings
```

---

## Design Philosophy Divergence

### OneSignal (Platform-centric)

```
Platform → Users (broadcast model)
├─ Create user, subscribe to channel
├─ Create message, target segment
└─ Deliver + track metrics
```

**REST-ful:** Every resource is CRUD-able.  
**Persistent:** Messages are stored, auditable, cancellable.  
**Segmentation:** Built-in audience targeting.

### ONE (Signal-based coordination)

```
Actor → Actor (peer model)
├─ Send signal (fire-and-forget or ask + wait)
├─ Signal strengthens/weakens paths (learning)
└─ Deliver + amplify strong paths
```

**Verb-driven:** Actions are fire, mark, warn, fade, follow, forget.  
**Ephemeral:** Signals are transient; persistence is in learned paths.  
**Routing:** Signals self-route via receiver namespace + path strength.

**The gap:** OneSignal optimizes for *broadcast at scale*. ONE optimizes for *peer coordination with learning*.

---

## 3. Feature Parity Matrix

| Feature | OneSignal | ONE | Equivalent? |
|---------|-----------|-----|-------------|
| **User CRUD** | ✅ 4 endpoints | ✅ signal/ask | ✅ Yes |
| **Device/Player mgmt** | ✅ 5 endpoints | ❌ Not distinct | ⚠️ Via actor tags |
| **Subscriptions** | ✅ 5 endpoints | ❌ Implicit | ⚠️ Auto-discovered |
| **Aliases/Identity** | ✅ 5 endpoints | ✅ signal/identity | ✅ Yes |
| **Send message** | ✅ 1 endpoint | ✅ signal | ✅ Yes |
| **Synchronous ask** | ❌ Polling only | ✅ ask (30s) | ✅ ONE better |
| **Segments/Groups** | ✅ 5 endpoints | ✅ signal/groups | ✅ Yes |
| **Custom events** | ✅ 1 endpoint | ✅ signal + learning | ✅ Yes |
| **Templates** | ✅ 6 endpoints | ❌ Skills ≈ templates | ⚠️ Different model |
| **Analytics** | ✅ 3 endpoints | ✅ highways (path strength) | ✅ Different but equivalent |
| **Learning feedback** | ❌ No | ✅ mark/warn/fade | ✅ ONE unique |
| **Workspace mgmt** | ✅ 7 endpoints | ⚠️ Partial (CLI) | ⚠️ Incomplete |
| **Audit logs** | ✅ 1 endpoint | ❌ Not exposed | ❌ Missing |
| **Live Activities** | ✅ 2 endpoints | ❌ Not implemented | ❌ Missing |
| **Webhooks** | ❌ Not listed | ✅ Partial | ✅ ONE has it |

---

## 4. API Maturity & Stability

### OneSignal

- ✅ Versioned (`/api/v1/`)
- ✅ Documented (OpenAPI)
- ✅ Stable (unlikely to break)
- ✅ Rate limiting documented
- ✅ Audit logs + compliance

### ONE

- ❌ Not versioned (no `/api/v*` versioning)
- ❌ Not in OpenAPI (receiver namespace not discoverable)
- ⚠️ Receiver namespace could change (no major version protocol)
- ❌ No rate limiting documented
- ❌ No audit log API
- ❌ No versioning strategy for receiver names

**Gap:** ONE lacks API stability guarantees.

---

## 5. Priority Gaps to Close

### Tier 1 (API usability)

1. **API versioning strategy** — document `/api/v1/` + major version bumps
2. **Receiver discovery** — `GET /api/receivers` → list all valid receiver names + schemas
3. **OpenAPI/AsyncAPI spec** — publish schema so clients can auto-generate
4. **Rate limiting docs** — per-workspace quotas, per-endpoint limits
5. **Audit log API** — expose `GET /api/audit-logs` or similar

### Tier 2 (Feature parity)

1. **Live Activities** — if needed for UI pushes
2. **Message persistence** — signals are ephemeral; add archive if needed
3. **Workspace key rotation** — API for key management
4. **Bulk operations** — `/api/bulk/*` endpoints for batch sends

### Tier 3 (Advanced)

1. **Webhook event delivery** — POST to external systems
2. **Segment editing via API** — groups read-only via export
3. **Agent template CRUD** — separate from agent definitions
4. **Skill publishing via API** — `POST /api/skill/publish`

---

## 6. Quick Wins

1. **Add receiver introspection** (30 min)
   ```ts
   GET /api/receivers
   → { receivers: [{ name: "agents:commend", schema: Zod.ZodSchema }] }
   ```

2. **Publish OpenAPI spec** (1h)
3. **API versioning docs** (30 min)
4. **Audit log API** (1h)
5. **Rate limiting header** (15 min)

---

## Conclusion

| Dimension | Winner | Gap |
|-----------|--------|-----|
| **Broadcast messaging** | OneSignal | ONE lacks native templates |
| **Synchronous coordination** | ONE (ask) | OneSignal only polls |
| **Learning feedback** | ONE (mark/warn) | OneSignal has no path learning |
| **API discoverable** | OneSignal | ONE receiver namespace opaque |
| **Workspace management** | OneSignal | ONE is CLI-first |
| **Audit compliance** | OneSignal | ONE has no audit API |

**Verdict:** 
- **ONE is ahead on:** Synchronous ask, learning feedback, peer coordination
- **ONE is behind on:** API discovery, versioning, workspace mgmt, audit
- **For production:** Add receiver discovery + OpenAPI spec + versioning strategy.
