# seal.md — API Key Storage: Standard & Self-Sovereign

Users bring their own API keys (OpenAI, Anthropic, Stripe, GitHub, …) so
agents can act on their behalf. Two modes, one interface. Users choose based
on how much they trust us — and most should choose Standard.

---

## What "trust" actually means here

Cryptographic "even we can't see your key" sounds safer but breaks autonomous
agents: if the Worker can't decrypt without the user's device, no agent runs
while the user is offline. That's the wrong trade-off for most people.

Real trust for API key storage is what every platform people already use
(Zapier, Vercel, Linear, Composio) provides:

- Keys encrypted at rest — a breach of the DB alone reveals nothing
- Every use logged and visible to the user
- Keys scoped to what the user authorized
- Budget caps the user controls
- Instant revocation
- Legal accountability (DPA, privacy policy)

That is the Standard mode. It is trustworthy. We CAN decrypt — and we log
every time we do.

Self-sovereign mode uses the user's device Secure Enclave so we cryptographically
cannot decrypt without their passkey. The trade-off: agents only run while an
active session exists. For most users that's a worse product. Offer it; default
to Standard.

---

## Mode comparison

| | Standard | Self-sovereign |
|---|---|---|
| Platform can read key | At decrypt time — logged | No — device SE required |
| Autonomous agents (user offline) | Yes | Only within session TTL (1h) |
| Multi-device | Yes — any authenticated device | One row per passkey credential |
| Complexity | Low | Medium |
| Setup | Enter key, done | Passkey PRF ceremony |
| Trust model | Legal + audit + transparency | Cryptographic |
| Best for | Most users | Power users who don't trust any platform |

---

## Standard mode — server-side encrypted

### How it works

```
SAVE (browser → Worker, once):
  User enters API key in UI (masked input)
  POST /api/settings?scope=api_keys
    { integration: "openai", key: plaintext }  ← over TLS
  Worker:
    AES-256-GCM.encrypt(key, env.VAULT_KEY) → { ciphertext, iv }
    INSERT INTO api_keys (user_id, integration, ciphertext, iv, mode='standard')
    Plaintext discarded. D1 holds only ciphertext.

USE (Worker, any time — user does not need to be present):
  SELECT ciphertext, iv FROM api_keys WHERE user_id=? AND integration=?
  AES-256-GCM.decrypt(ciphertext, env.VAULT_KEY) → plaintext
  → call OpenAI / Stripe / etc.
  INSERT INTO api_key_usage (...) ← audit log, always

REVOKE:
  DELETE FROM api_keys WHERE user_id=? AND integration=?
  → also delete KV cache entry if present
  → Worker can no longer decrypt — no key, no plaintext, nowhere
```

`env.VAULT_KEY` is a 32-byte random key stored in CF Secrets (`wrangler secret put VAULT_KEY`).
A breach of D1 alone gives an attacker only ciphertext — useless without the CF Secret.
A breach of both D1 and CF Secrets is a full platform compromise; legal/contractual response,
not a cryptographic one.

### KV cache (performance)

For high-frequency integrations, decrypt once per session and cache:

```
AES-GCM.encrypt(plaintext, env.KV_ENCRYPTION_KEY) → kvBlob
KV.put(`sk:${sha256(sessionToken)}:${integration}`, kvBlob, { expirationTtl: 3600 })
```

Two separate encryption keys: `VAULT_KEY` (D1 at-rest), `KV_ENCRYPTION_KEY` (KV cache).
Neither alone decrypts both. KV entry expires on logout or TTL — whichever comes first.

### Audit log

Every decryption is logged. This is the core trust mechanism.

```sql
-- web/migrations/0033_api_key_usage.sql
CREATE TABLE api_key_usage (
  id           TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  user_id      TEXT NOT NULL,
  integration  TEXT NOT NULL,         -- 'openai' | 'anthropic' | 'stripe' ...
  agent_id     TEXT,                  -- which agent triggered the call
  operation    TEXT,                  -- 'chat.completion' | 'embeddings' | 'charge' ...
  tokens_used  INTEGER,               -- for LLM integrations
  cost_usd     REAL,                  -- estimated cost (from token count + model price)
  status       TEXT NOT NULL,         -- 'ok' | 'error' | 'rate_limited' | 'budget_exceeded'
  ts           INTEGER NOT NULL DEFAULT (unixepoch())
);
```

User dashboard shows: "Your OpenAI key was used 47 times today by agent alice.
GPT-4o: 12,400 tokens, ~$0.37. [View full log] [Revoke]"

### Budget caps

```sql
-- web/migrations/0033_api_key_budgets.sql
CREATE TABLE api_key_budgets (
  user_id      TEXT NOT NULL,
  integration  TEXT NOT NULL,
  monthly_usd  REAL,            -- NULL = unlimited
  alert_at_usd REAL,            -- notify when spend crosses this
  PRIMARY KEY (user_id, integration)
);
```

Worker enforces before decrypting:

```ts
const spent = await getMonthlySpend(env, userId, integration)
const budget = await getBudget(env, userId, integration)
if (budget.monthly_usd !== null && spent >= budget.monthly_usd) {
  await logUsage(env, { userId, integration, status: 'budget_exceeded' })
  throw new Error(`Monthly budget exceeded for ${integration}`)
}
```

---

## Self-sovereign mode — device-encrypted

For users who want cryptographic proof the platform cannot read their key.
Agents only run while a session is active (1h TTL). After TTL expires, the
user must re-authenticate from their device to extend.

### How it works

```
SAVE (browser, once per device — key never sent in plaintext):
  1. WebAuthn PRF extension → 32-byte device secret (SE-guarded, not extractable)
  2. GET /api/settings/wrapping-key → { hkdf_info: base64(random32) }
       Worker stores hkdf_info in D1 alongside future ciphertext
  3. HKDF(prf_output, info=hkdf_info) → AES-256-GCM key
       (split derivation: device holds PRF output, server holds hkdf_info —
        neither alone can derive the AES key)
  4. AES-256-GCM.encrypt(apiKey) → { ciphertext, iv }
  5. PUT /api/settings?scope=api_keys
       { integration: "openai", credential_id, ciphertext, iv, mode: "sovereign" }
     D1 stores ciphertext + hkdf_info + credential_id. Plaintext never sent.

DECRYPT (once per session — ECDH-wrapped, key never in HTTP body):
  1. User authenticates (passkey)
  2. GET /api/settings/session-wrap?integration=openai
       Worker: generate ephemeral ECDH P-256 keypair
       → { wrappingKey: base64(spki), sessionId }
  3. Browser:
       PRF → AES key → decrypt ciphertext → plaintext
       ECDH(browser_ephemeral, worker_public) → shared_secret
       AES-GCM.encrypt(plaintext, HKDF(shared_secret)) → wrapped
       POST /api/settings/session
         { sessionId, integration, wrapped, clientPublicKey }
  4. Worker:
       ECDH-decrypt wrapped → plaintext (exists only in V8 isolate)
       AES-GCM.encrypt(plaintext, env.KV_ENCRYPTION_KEY) → kvBlob
       KV.put(`sk:${sha256(sessionToken)}:${integration}`, kvBlob, { expirationTtl: 3600 })
       Plaintext gone. Never in HTTP body. Never in any log.

USE (same as Standard — KV read + decrypt):
  KV read → AES-GCM.decrypt(kvBlob, env.KV_ENCRYPTION_KEY) → plaintext → call API

SESSION EXPIRY:
  After 1h TTL or logout, KV entry gone.
  Agent cannot use the key until user re-authenticates from their device.
  This is the trade-off. It's real. Tell users clearly.

MULTI-DEVICE:
  Each passkey credential gets its own D1 row (UNIQUE on user_id + credential_id + integration).
  New device: user re-enters the key once, encrypted with that device's PRF → new row.
  Both devices work independently.
```

### D1 schema (Self-sovereign)

```sql
-- web/migrations/0033_api_keys.sql
CREATE TABLE IF NOT EXISTS api_keys (
  id            TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  user_id       TEXT NOT NULL,
  credential_id TEXT,               -- NULL for Standard mode; set for Self-sovereign
  scope         TEXT NOT NULL,      -- 'user' | 'agency' | 'client'
  integration   TEXT NOT NULL,
  ciphertext    TEXT NOT NULL,
  iv            TEXT NOT NULL,
  hkdf_info     TEXT,               -- NULL for Standard (platform handles derivation)
  mode          TEXT NOT NULL DEFAULT 'standard',  -- 'standard' | 'sovereign'
  layer         TEXT NOT NULL DEFAULT 'prf',       -- 'prf' | 'seal' (agency)
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  UNIQUE(user_id, credential_id, integration)
);
```

---

## Seal (Layer 2) — agency key delegation

Seal is not for individual users. It solves one specific problem: an agency
has an OpenAI org key and needs to grant N client Workers access to it without
manually re-encrypting per client.

Works with either mode above — the agency admin chooses Standard or Sovereign
for their key; Seal handles the delegation layer on top.

```
Agency saves key (Standard or Sovereign as above)
Agency admin signs Sui tx → on-chain KeyRequest → client's Sui address added
Client Worker presents KeyRequest to Seal servers (2-of-3 threshold) → key shares
Seal.decrypt(ciphertext, keyShares) → plaintext → same KV cache flow

REVOKE:
  Agency admin removes client from on-chain whitelist
  → KV TTL = natural expiry (≤1h)
  → client cannot get new key shares → access ends
  → audit trail on Sui: immutable, timestamped
```

Key server setup: claw Worker + 2 community operators, threshold 2-of-3.
One server alone cannot decrypt. Agency key is safe even if we're compromised,
provided community operators don't collude with us.

---

## Key cascade in Workers

```ts
// claw/src/lib/key-vault.ts

// Allowlist prevents dynamic env key enumeration attacks.
const PLATFORM_KEY_MAP = {
  openai:    'OPENAI_API_KEY',
  anthropic: 'ANTHROPIC_API_KEY',
  stripe:    'STRIPE_SECRET_KEY',
} as const satisfies Record<string, keyof Env>

export async function resolveKey(
  env: Env,
  sessionToken: string,
  userId: string,
  agencyId: string | null,
  integration: keyof typeof PLATFORM_KEY_MAP
): Promise<string> {
  const sessionHash = await sha256(sessionToken)

  // 1. User's own key — KV cache first (Standard or Sovereign, same shape)
  const cached = await env.KV.get(`sk:${sessionHash}:${integration}`)
  if (cached) return aesGcmDecrypt(cached, env.KV_ENCRYPTION_KEY)

  // 2. Standard mode: decrypt from D1 with platform VAULT_KEY
  const row = await getApiKey(env, userId, integration, 'standard')
  if (row) {
    const key = aesGcmDecrypt(row.ciphertext, env.VAULT_KEY)
    await cacheKey(env, sessionHash, integration, key)   // write to KV
    await logUsage(env, { userId, integration, status: 'ok' })
    return key
  }

  // 3. Agency shared key (Seal delegation)
  if (agencyId) {
    const agencyKey = await resolveSealKey(env, agencyId, integration)
    if (agencyKey) return agencyKey
  }

  // 4. Platform fallback — allowlisted only, never dynamic
  const envKey = PLATFORM_KEY_MAP[integration]
  const platformKey = env[envKey] as string | undefined
  if (platformKey) return platformKey

  throw new Error(`No ${integration} key available for ${userId}`)
}
```

---

## 4-tier ownership

```
platform (owner)
  └─ CF Secrets: OPENAI_API_KEY, ANTHROPIC_API_KEY
     ← platform LLM quota, never stored in D1

agency
  └─ Standard or Sovereign — agency's own OpenAI org key
  └─ Seal delegation: whitelist policy → clients get access without sharing the key

client
  └─ Standard (default): server-side encrypted, agents run 24/7
  └─ Sovereign (opt-in): device-encrypted, agents run within session TTL

end_user
  └─ no key management — cascade: client → agency → platform
```

---

## What we can honestly guarantee

| Guarantee | Standard | Self-sovereign | Seal (agency) |
|---|---|---|---|
| D1 breach alone reveals nothing | ✓ (VAULT_KEY in CF Secrets) | ✓ (PRF + hkdf_info split) | ✓ (threshold IBE) |
| Platform cannot read key | No — we can decrypt | Yes — device SE required | Partial — threshold required |
| Every use logged to user | ✓ | ✓ | ✓ (+ on-chain) |
| Autonomous agents run 24/7 | ✓ | Within session TTL only | ✓ |
| Instant revocation | ✓ | ✓ | ✓ (+ on-chain TTL) |
| Budget caps enforced | ✓ | ✓ | ✓ |
| Agency→Client delegation | Manual re-encrypt | Manual re-encrypt | On-chain, auditable |
| Key never in HTTP body | No (TLS only) | ✓ (ECDH wrapped) | ✓ |
| ~1ms plaintext window in Worker | Yes — unavoidable | Yes — unavoidable | Yes — unavoidable |

The ~1ms window exists in all modes. TEE would close it; CF Workers doesn't offer TEE yet.
Every other attack vector is covered.

**Standard mode marketing:** "Your API keys are encrypted at rest. We log every use.
You can see everything, revoke anytime, and set spending limits."

**Self-sovereign mode marketing:** "Your API keys are encrypted with your device's
secure enclave. Even our servers can't decrypt them — but agents can only run while
you have an active session."

---

## What to ship

### v1 — Standard mode (no new infra, ship first)

- [ ] `wrangler secret put VAULT_KEY` — 32-byte random
- [ ] `wrangler secret put KV_ENCRYPTION_KEY` — 32-byte random
- [ ] Migration `0033_api_keys.sql` + `0033_api_key_usage.sql` + `0033_api_key_budgets.sql`
- [ ] `POST /api/settings?scope=api_keys` — receive key, encrypt with VAULT_KEY, store
- [ ] `GET /api/settings?scope=api_keys` — return `{ integration, has_key, mode, created_at }`
- [ ] `DELETE /api/settings?scope=api_keys&integration=X` — full wipe
- [ ] `claw/src/lib/key-vault.ts` — allowlisted cascade resolver + audit log
- [ ] Budget enforcement in resolver (check spend before decrypt)
- [ ] UI: Settings → Integrations
  - Add key (masked input + client-side format validation before submit)
  - Usage log panel per integration
  - Budget cap input
  - Revoke button

### v2 — Self-sovereign mode (add for power users)

- [ ] `GET /api/settings/wrapping-key` — server assigns hkdf_info
- [ ] `GET /api/settings/session-wrap` — ephemeral ECDH keypair
- [ ] `POST /api/settings/session` — ECDH-unwrap, double-encrypt, write to KV
- [ ] `web/src/lib/key-vault-client.ts` — browser PRF + HKDF + AES-GCM + ECDH
- [ ] Mode toggle in UI: "Standard / Self-sovereign" with trade-off explanation inline
- [ ] Session expiry warning in agent UI when sovereign TTL < 10 min

### v3 — Seal agency delegation (needs Sui infra)

- [ ] `seal_api_keys` Move package on Sui mainnet
- [ ] Claw registered as Seal key server (1 of 3)
- [ ] `web/src/lib/seal-client.ts` — `@mysten/seal` wrapper
- [ ] Agency admin UI: Grant / Revoke client access (Sui tx)
- [ ] Usage log includes delegated-via field

---

## See also

- [`passkeys.md`](passkeys.md) — PRF derivation, device SE, BIP39
- [`web/roles.md`](web/roles.md) — owner/agency/client/end_user cascade
- [`composio.md`](composio.md) — OAuth token handling (Composio holds those; we hold API keys)
- [`walrus-sites.md`](walrus-sites.md) — Seal's sibling (Walrus storage)
- [Seal GitHub](https://github.com/MystenLabs/seal) — threshold IBE SDK + key server
