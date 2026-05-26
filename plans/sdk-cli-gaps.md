# SDK/CLI Gap Analysis: ONE vs OneSignal

## Executive Summary

**ONE** is a signal-based substrate for agent coordination (TypeDB brain, signal verbs, receiver namespace). **OneSignal** is a notification/messaging platform with broad language & platform coverage. These serve opposite purposes — not directly comparable — but the analysis reveals distribution and SDK maturity gaps.

---

## 1. Platform & Language Coverage

### OneSignal (Production)

**Mobile:** iOS, Android (Google, Huawei, FireOS)  
**Web:** Website SDK, React, Vue 2 & 3, Angular, WordPress  
**Cross-platform:** React Native, Flutter, Unity, Xamarin, Ionic, Cordova, DotNet, Expo  
**Server-side:** Node.js, Go, Java, .NET, Rust, Ruby, C++, Python, PHP

**Total:** ~25 distinct SDKs across 6+ language families.

### ONE (Current)

**TypeScript/JavaScript only:**
- `@oneie/sdk` (Node.js + browser)
- `@oneie/react` (React 19 hooks)
- `@oneie/cli` (CLI, Node.js only)
- `@oneie/mcp` (MCP server, Node.js)

**Total:** 4 SDKs, JavaScript/TypeScript only.

### Gaps

- ❌ **No native mobile SDKs** (iOS, Android)
- ❌ **No server-side SDKs** in Go, Python, Rust, Java, .NET
- ❌ **No cross-platform frameworks** (Flutter, React Native, Unity)

---

## 2. SDK Architecture & Features

| Aspect | OneSignal | ONE |
|--------|-----------|-----|
| **Direction** | Platform → Users | Agent ↔ Agent |
| **Identity** | User ID, email, phone | Actor UID |
| **Message model** | Fire-and-forget + acknowledge | Fire-and-wait + 4 outcomes |
| **SDK consumption** | Client libraries | Backend only |
| **Learning feedback** | Analytics counters | Path weights |

---

## 3. CLI Feature Gaps

**ONE CLI has:**
- `agent`: scaffold, validate, compile, serve, dev, publish, list, history, rollback, eval, ai-edit, sign
- `skill`: new, emit, publish, import, list, unimport, refresh, validate, eval
- `auth`: login, logout
- `dev`: local stack (build → D1 migrate → wrangler dev)
- `group`: bulk-create

**ONE CLI lacks:**
- ❌ **Logs/monitoring:** no `logs`, `tail`, `debug` commands
- ❌ **Metrics:** no `metrics`, `stats`, `perf` commands
- ❌ **Deployment control:** no `deploy`, `rollout`, `pause`, `resume`
- ❌ **Workspace management:** no `workspace create`, `invite`, `permissions`
- ❌ **Secret management:** no `secret`, `env` commands
- ❌ **Multi-environment:** no `--env staging|prod` flag
- ❌ **Backup/restore:** no `backup`, `restore`, `snapshot` commands

---

## 4. SDK Method Coverage

**ONE SDK Verbs (6/6 implemented):**
- `signal()` ✅
- `mark()` ✅
- `warn()` ✅
- `fade()` ✅
- `follow()` ✅
- `harden()` via `signal("learning:know")` ✅

**Gaps:**
- ⚠️ `select()` (probabilistic path selection) — not exposed in SDK; only `follow()` (deterministic)

---

## 5. Testing & Documentation

**Gaps:**
- ❌ **No SDK generation** (OpenAPI, Swagger, or TypeDB schema → SDK code)
- ❌ **No versioning strategy** documented (SemVer assumed, but no major version bump protocol)
- ❌ **No SDK spec** (TypeScript types are the spec; no formal OpenAPI/AsyncAPI)

---

## 6. Distribution & Package Management

**Gaps:**
- ❌ **Not on PyPI, Maven, Cargo, etc.** — no distributed SDKs beyond npm
- ❌ **No binary releases** (for CLI)
- ❌ **No package version management** — v0.8.0 (SDK) and v0.1.0 (CLI) — do they track separately?
- ❌ **No publish automation** — CI/CD for npm publish not documented

---

## 7. Receiver Namespace vs REST API

### ONE's Unique Design

```ts
// Instead of REST routes:
//   POST /api/agents/commend
//   POST /api/market/hire
// Use receiver namespace (single endpoint):
await one.signal("agents:commend", { uid })
await one.ask("market:hire", { skill, budget })
```

**Advantages:**
- Single verb surface (signal, mark, warn, etc.)
- Semantics in the receiver name
- No HTTP route bloat

**Disadvantages:**
- ❌ Not RESTful (violates REST conventions)
- ❌ No OpenAPI spec (autocomplete, validation, code gen tools don't work)
- ❌ Every receiver name is implicit (discovery requires docs)
- ❌ No standard error codes per receiver

**Gap:** Receiver namespace is not discoverable. Need:
- `one.receivers()` → list all valid receivers
- `one.receiverSchema(name)` → Zod schema for receiver input/output
- Or: generate receiver index from TypeDB schema

---

## 8. Authentication & Authorization

**Gaps:**
- ❌ **No RBAC in SDK** — caller doesn't know what receivers they can call
- ❌ **No token refresh** — long-lived keys only
- ❌ **No OAuth2 / OpenID** (web UI uses Better Auth, but SDK doesn't expose)
- ❌ **CLI key storage** is user-managed (0600 file) — no keychain integration

---

## 9. Comparison Matrix

| Category | OneSignal | ONE |
|----------|-----------|-----|
| **Primary use case** | Notification platform | Agent coordination |
| **Languages** | 10+ | TypeScript only |
| **Mobile SDKs** | iOS, Android (native) | None |
| **Server SDKs** | 8+ languages | None |
| **API style** | REST + OpenAPI | Receiver namespace |
| **OpenAPI spec** | ✅ | ❌ |
| **SDK generation** | ✅ (auto) | ❌ (hand-written) |
| **Learning feedback** | Analytics counters | Path weights |
| **RBAC** | ✅ | ❌ |
| **CLI versioning** | N/A | Undocumented |
| **Receiver discovery** | N/A | No SDK introspection |

---

## 10. Priority Gaps to Close

### Tier 1 (Foundation)

1. **SDK generation from schema** — emit TypeScript SDK from TypeDB schema
2. **Receiver introspection** — `one.receivers()` + `one.receiverSchema(name)` for discovery
3. **OpenAPI / AsyncAPI spec** — publish schema so external tools can generate clients
4. **CLI docs** — full command reference + examples
5. **SDK versioning strategy** — SemVer protocol, major version bumps

### Tier 2 (Reach)

1. **HTTP client SDKs** (Go, Python, Rust, Java) — codegen from schema
2. **Mobile support** — web view + native bridge or native SDKs (post-MVP)
3. **RBAC in SDK** — `one.can(receiver, action)` or similar
4. **CLI deployment control** — `oneie deploy` / `rollout` / `pause`
5. **Package publish CI/CD** — automated npm publish on tag

### Tier 3 (Polish)

1. **Keychain integration** (macOS, Linux) for CLI auth
2. **Multi-environment in SDK** — `ONE({ env: "staging" })`
3. **Binary releases** (CLI) — prebuilt for macOS, Linux, Windows
4. **Metrics/logging CLI** — `oneie logs`, `metrics`, `debug`

---

## Conclusion

ONE and OneSignal serve opposite use cases. The gap analysis shows:

- **Coverage:** ONE is TypeScript-only; OneSignal spans 10+ languages.
- **Design:** ONE's receiver namespace is unique but non-standard. Need SDK introspection.
- **Maturity:** CLI is reasonable. SDK is sufficient for current agents. Missing: generation, versioning, discovery.
- **Distribution:** npm-only is limiting long-term.

**Key investment:** SDK generation from schema + receiver introspection will unblock external developers.
