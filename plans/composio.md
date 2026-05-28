---
title: Composio Integration Plan
slug: composio
type: plan
tier: moderate
mode: construction
tags: [composio, integrations, chat, agents, tools]

goal: "Every active Composio connection a user has wired becomes a live tool in their chat session and agent toolkit — no code changes needed per integration."
outcome: "Active Gmail/LinkedIn/Slack connections surface as callable tools in chat. Agent auto-discovers connected toolkits per user. Tool calls go through approval gate at sensitivity ≥ 0.7."
---

# Composio Integration Plan

## State today

| Layer | Status |
|-------|--------|
| `@composio/core` SDK | Installed in `one.ie/web/` |
| OAuth redirect flow | `api/composio/connect.ts` + `api/composio/callback.ts` — fully wired |
| API key / BASIC form flow | Same route — `needs_credentials` response with field list |
| Active connections | 1 (`dataforseo` — EXPIRED) |
| Tool bridge to AI SDK | Not built — `aitools.ts` has no Composio tools |
| Tool bridge to chat | Not built — users can't invoke Composio tools in chat |
| 83 tool definitions cached | `~/.composio/tool_definitions/` — browsed, not wired |

The connect UI exists. Auth flows work. Nothing calls the tools yet.

---

## Auth matrix

Composio handles auth transparently — the agent always calls `composio execute <SLUG> -u <userId>` without knowing the auth type. But the **connect UI** and **verification UX** differ per type.

### OAuth2 (redirect flow)
`connect.ts` → Composio managed redirect → user authorizes → callback → active connection.

| Toolkit | Key tools |
|---------|-----------|
| gmail | `GMAIL_SEND_EMAIL` · `GMAIL_FETCH_EMAILS` · `GMAIL_REPLY_TO_THREAD` |
| googlecalendar | `GOOGLECALENDAR_CREATE_EVENT` · `GOOGLECALENDAR_FIND_FREE_SLOTS` |
| googledrive | `GOOGLEDRIVE_FIND_FILE` · `GOOGLEDRIVE_DOWNLOAD_FILE` |
| linkedin | `LINKEDIN_CREATE_LINKED_IN_POST` · `LINKEDIN_GET_MY_INFO` |
| twitter | `TWITTER_RECENT_SEARCH` · `TWITTER_USER_LOOKUP_BY_USERNAME` |
| github | `GITHUB_GET_A_REPOSITORY` · `GITHUB_SEARCH_CODE` |
| notion | `NOTION_CREATE_DATABASE` · `NOTION_UPSERT_ROW_DATABASE` |
| slack | `SLACK_DELETES_A_MESSAGE_FROM_A_CHAT` |
| hubspot | `HUBSPOT_CREATE_CONTACT` |
| salesforce | `SALESFORCE_CREATE_LEAD` |
| airtable | `AIRTABLE_LIST_BASES` · `AIRTABLE_GET_BASE_SCHEMA` |
| linear | `LINEAR_LIST_LINEAR_ISSUES` · `LINEAR_LIST_LINEAR_PROJECTS` |
| jira | `JIRA_GET_ALL_PROJECTS` |
| zoom | `ZOOM_CREATE_A_MEETING` |
| dropbox | `DROPBOX_LIST_FILES_IN_FOLDER` |
| figma | `FIGMA_GET_FILE_JSON` · `FIGMA_DOWNLOAD_FIGMA_IMAGES` |
| canva | `CANVA_LIST_USER_DESIGNS` · `CANVA_POST_DESIGNS` |
| mailchimp | `MAILCHIMP_SEND_CAMPAIGN` |
| quickbooks | `QUICKBOOKS_CREATE_CUSTOMER` · `QUICKBOOKS_CREATE_INVOICE` |
| shopify | `SHOPIFY_GET_APP` |
| reddit | `REDDIT_SEARCH_ACROSS_SUBREDDITS` |
| outlook | `OUTLOOK_SEND_EMAIL` |
| zoho | `ZOHO_CREATE_ZOHO_RECORD` · `ZOHO_MAIL_MESSAGES_SEND_EMAIL` |

### API Key (inline credential form)
`connect.ts` returns `{ needs_credentials, authScheme: "API_KEY", fields: [{name:"api_key"}] }` — UI shows a one-field form.

| Toolkit | Key tools |
|---------|-----------|
| stripe | `STRIPE_CREATE_CUSTOMER` · `STRIPE_CREATE_INVOICE` · `STRIPE_CREATE_PAYMENT_INTENT` · `STRIPE_SEND_INVOICE` |
| dataforseo | SEO rank/keyword tools (currently EXPIRED — re-link needed) |
| elevenlabs | `ELEVENLABS_ADD_OUTBOUND_PHONE_NUMBER` |
| vapi | `VAPI_PHONE_NUMBER_CONTROLLER_CREATE` |
| supabase | `SUPABASE_LIST_TABLES` · `SUPABASE_BETA_RUN_SQL_QUERY` |
| bamboohr | `BAMBOOHR_GET_HIRING_LEADS` |
| freshdesk | `FRESHDESK_CREATE_TICKET` |
| zendesk | `ZENDESK_CREATE_ZENDESK_TICKET_OR_VOICEMAIL_TICKET` |
| pagerduty | `PAGERDUTY_UPDATE_INTEGRATION_BY_ID_AND_INTEGRATION_ID` |

### Username + Password (BASIC form)
`connect.ts` returns `{ needs_credentials, authScheme: "BASIC", fields: [username, password] }`.

| Toolkit | Notes |
|---------|-------|
| metabase | `METABASE_LIST_DATABASES` · `METABASE_LIST_TABLES` |
| sap_successfactors | `SAP_SUCCESSFACTORS_CREATE_ONBOARDEE` |
| zoho_crm (legacy mode) | `ZOHO_SEARCH_ZOHO_RECORDS` |

---

## Verification: confirm a connection is working

A connection status of `ACTIVE` in Composio is not enough — the token may be revoked server-side (see: `dataforseo` EXPIRED). Verification = a dry-run read call that proves the credential actually works.

**Verification tool per auth type:**

| Auth type | Verification call | Pass signal |
|-----------|-------------------|-------------|
| OAuth2 (profile apps) | `composio execute GMAIL_FETCH_EMAILS -u <uid> -d '{"max_results":1}'` | Returns message list (even empty) |
| OAuth2 (social) | `composio execute LINKEDIN_GET_MY_INFO -u <uid>` | Returns `localizedFirstName` field |
| API Key | `composio execute <TOOLKIT_LIST_TOOL> -u <uid>` | 200 OK, any valid JSON |
| BASIC | Same — pick the lightest LIST tool for the toolkit | 200 OK |

**API route to add:** `GET /api/composio/verify?toolkit=<slug>` — runs the dry call and returns `{ ok: bool, error?: string }`. The integrations UI polls this after connect and shows a green/red badge.

---

## The bridge: Composio tools → AI SDK tool()

Today `buildTools(env, sensitivity, emits)` returns a static map of 10 typed tools. The bridge adds a **dynamic layer**: for each active connection the user has, inject the relevant Composio tool slugs as AI SDK `tool()` wrappers.

### Architecture

```
user sends chat message
  ↓
agent/src/builder.ts: buildTools(env, sensitivity, emits)
  ↓  [new] composioTools(env, userId) — async, loads active connections
  ↓
  {
    gmail_send:      tool({ execute: () => composioExecute('GMAIL_SEND_EMAIL', userId, args) })
    linkedin_post:   tool({ execute: () => composioExecute('LINKEDIN_CREATE_LINKED_IN_POST', userId, args) })
    stripe_invoice:  tool({ execute: () => composioExecute('STRIPE_CREATE_INVOICE', userId, args) })
    ...per active connection...
  }
  ↓
merged with static tools → passed to streamText / generateText
```

### `composioExecute` — the single integration point

```ts
// agents/src/composio.ts
async function composioExecute(slug: string, userId: string, args: Record<string, unknown>, env: Env) {
  // Calls Composio SDK server-side: POST /api/v2/tools/{slug}/execute
  // Returns { data, error? }
}
```

Composio handles auth transparently — the agent never sees tokens, never branches on auth type.

### Tool naming convention

Composio slugs are `SCREAMING_SNAKE_CASE`. Exposed to the LLM as `lowercase_snake` to match existing tools:

| Composio slug | LLM tool name | Destructive? |
|---------------|---------------|-------------|
| `GMAIL_SEND_EMAIL` | `gmail_send` | yes — sensitivity ≥ 0.7 |
| `GMAIL_FETCH_EMAILS` | `gmail_list` | no |
| `LINKEDIN_CREATE_LINKED_IN_POST` | `linkedin_post` | yes |
| `LINKEDIN_GET_MY_INFO` | `linkedin_me` | no |
| `GOOGLECALENDAR_CREATE_EVENT` | `calendar_create` | yes |
| `GOOGLECALENDAR_FIND_FREE_SLOTS` | `calendar_free_slots` | no |
| `STRIPE_CREATE_INVOICE` | `stripe_invoice` | yes |
| `STRIPE_CREATE_PAYMENT_INTENT` | `stripe_pay` | yes |
| `GITHUB_SEARCH_CODE` | `github_search` | no |
| `NOTION_UPSERT_ROW_DATABASE` | `notion_upsert` | yes |
| `SLACK_DELETES_A_MESSAGE_FROM_A_CHAT` | `slack_delete` | yes |
| `LINEAR_LIST_LINEAR_ISSUES` | `linear_issues` | no |
| `JIRA_GET_ALL_PROJECTS` | `jira_projects` | no |

**Approval gate:** any tool marked `destructive: true` is wrapped with an `approval` check before `execute` fires — same pattern as the existing `mark`/`warn` gate in `aitools.ts`. The agent presents the call to the user as a confirm card, then executes on approval.

---

## Chat integration

When a user opens chat, the agent session is built from:

1. **Static tools** — existing `buildTools()` map (discover, remember, recall, highways, mark, warn, emit_signal, emit_card, browse, draft_social_post)
2. **Composio tools** — dynamic per user's active connections

The user doesn't configure anything — they just talk. If they say "send a LinkedIn post about X" and LinkedIn is connected, the agent calls `linkedin_post`. If not connected, the agent calls `emit_card` with a `{ kind: 'connect', toolkit: 'linkedin' }` card that links to the connect flow.

**Connect card shape:**

```ts
{
  kind: 'connect'
  toolkit: string         // 'gmail' | 'linkedin' | 'stripe' | ...
  authType: 'oauth' | 'api_key' | 'basic'
  connectUrl: string      // /u/{slug}/tools/{toolkit}
  label: string           // 'Connect Gmail to send emails'
}
```

MessageRenderer adds a `connect` case: shows the toolkit icon, auth type badge, and a Connect button. No page navigation — opens connect modal inline.

---

## Agent integration (workspace agents)

Each workspace agent defined in `one.ie/agents/*.md` can declare which toolkits it uses:

```markdown
---
name: cmo
integrations: [linkedin, twitter, mailchimp, googledrive]
---
```

When the agent is invoked for a workspace, `buildTools` checks which of its declared integrations have active connections for that workspace owner. Only those tools are injected. An agent that declares `[linkedin, twitter]` and only LinkedIn is connected gets `linkedin_post` + `linkedin_me` but not `twitter_*`.

This keeps the LLM context tight — agents don't see 100 tools, only the 5-10 relevant to their role.

---

## Skill layer (per-toolkit sequences)

Composio's search results already include `recommended_plan_steps` (seen for LinkedIn). These become `.claude/skills/` entries for the agent tier, not the user tier — they teach Claude Code how to orchestrate multi-step Composio flows correctly.

**Example: `skills/composio-linkedin.md`**
```
LinkedIn posting sequence (always follow):
1. LINKEDIN_GET_MY_INFO → capture author URN
2. LINKEDIN_CREATE_LINKED_IN_POST with that URN
3. If post fails → fallback to LINKEDIN_CREATE_ARTICLE_OR_URL_SHARE
```

**Toolkits that need sequenced skills** (non-trivial call order):
- LinkedIn (author URN prerequisite)
- Gmail (fetch thread → reply — avoids duplicate send)
- Google Calendar (find free slots → create event)
- Stripe (create product → create price → create invoice → finalize → send)
- QuickBooks (create customer → create invoice)

---

## Cycles

### C1 — Tool bridge + dynamic toolset (core)

**Files:**
- `agents/src/composio.ts` — `composioExecute(slug, userId, args, env)` + `composioTools(env, userId)` factory
- `agents/src/aitools.ts` — merge Composio dynamic map into `buildTools()` return
- `agents/src/builder.ts` — pass `userId` into `buildTools` (currently uses `group` only)
- `one.ie/web/src/lib/cards.ts` — add `connect` CardData kind

**Deliverable:** chat can call `gmail_list` if Gmail is connected; calls `emit_card(connect)` if not.

### C2 — Verification endpoint + UI badge

**Files:**
- `one.ie/web/src/pages/api/composio/verify.ts` — dry-run read call, returns `{ ok, error? }`
- `one.ie/web/src/pages/api/composio/connections.ts` — list active connections for the current user (calls `composio.connectedAccounts.list`)
- `one.ie/web/src/components/chat/MessageRenderer.tsx` — add `connect` card case

**Deliverable:** integrations page shows green/red badge per toolkit. Connect card appears in chat when a needed toolkit isn't wired.

### C3 — Agent `integrations:` frontmatter + scoped toolsets

**Files:**
- `agents/src/builder.ts` — read `integrations` from agent definition, filter Composio tool map
- `one.ie/agents/*.md` — add `integrations:` to CMO, SDR, CS agents

**Deliverable:** workspace agents get scoped toolsets. CMO only sees LinkedIn + Twitter + Mailchimp tools, not Stripe + GitHub.

### C4 — Per-toolkit skill files

**Files:**
- `.claude/skills/composio-linkedin.md`
- `.claude/skills/composio-gmail.md`
- `.claude/skills/composio-stripe.md`
- `.claude/skills/composio-calendar.md`

**Deliverable:** agent follows correct multi-step sequences for non-trivial toolkits without hallucinating call order.

---

## What stays out of scope

- Building a custom UI for every toolkit's connect flow — `connect.ts` already handles all three auth types generically
- Storing Composio tokens locally — Composio holds them; we only store `word_id` + status in D1 as a cache
- Wrapping all 83 cached tool definitions — C1 only wraps tools from **active** connections; dormant toolkits inject nothing
- Polling for connection status in real time — `verify.ts` is on-demand; no background jobs

---

## Key files

| File | Role |
|------|------|
| `one.ie/web/src/pages/api/composio/connect.ts` | Auth flow — all three types handled |
| `one.ie/web/src/pages/api/composio/callback.ts` | OAuth redirect landing |
| `agents/src/aitools.ts` | Static tool map — C1 merges Composio dynamic map here |
| `agents/src/composio.ts` | *(new C1)* — execute bridge + tool factory |
| `~/.composio/tool_definitions/` | 83 cached schemas — reference only |
