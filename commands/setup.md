# /setup — Connect to the ONE substrate

Wire Claude Code to your ONE workspace. Run once; the substrate tools become available immediately.

---

## What this does

1. Checks for an existing `ONEIE_API_KEY` in the environment
2. If absent — asks for your key and writes it to `.env.local` (gitignored)
3. Verifies the connection with a live `signal` call to `api.one.ie`
4. Confirms which MCP tools are now available

---

## Steps

**1. Check environment**

```bash
echo ${ONEIE_API_KEY:-"not set"}
```

If already set → skip to step 3.

**2. Collect the key**

Ask the user (single `AskUserQuestion`):
- "What is your ONE API key?" (find it at https://one.ie/settings/keys)

Write to `.env.local`:
```bash
echo "ONEIE_API_KEY=<key>" >> .env.local
grep -q ".env.local" .gitignore || echo ".env.local" >> .gitignore
export ONEIE_API_KEY=<key>
```

**3. Verify**

```bash
curl -sf -X POST https://api.one.ie/signal \
  -H "Authorization: Bearer $ONEIE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"receiver":"setup:verify","data":{"tags":["setup"]}}' \
  | jq -r '.ok // "failed"'
```

Exit 0 → connected. Non-zero → report the error, link to https://one.ie/docs/api-keys.

**4. Report**

On success:
```
✓ Connected to ONE substrate
  API: https://api.one.ie
  MCP tools available: signal · ask · mark · warn · fade · follow · select · recall · reveal · forget · frontier · know · highways
  Lifecycle tools: auth_agent · sync_agent · publish_agent · list_agents · list_skills · register · pay
  Observability: stats · health · revenue · export_highways

Run /do to start building.
```

---

## Env vars

| Var | Default | What |
|-----|---------|------|
| `ONEIE_API_KEY` | required | Your workspace API key |
| `ONEIE_API_URL` | `https://api.one.ie` | Override for self-hosted |

To use a different API endpoint:
```bash
echo "ONEIE_API_URL=https://your-api.example.com" >> .env.local
```
