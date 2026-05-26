# UnifyGTM vs ONE: Comprehensive Platform Comparison

## Executive Summary

**UnifyGTM:** Sales & marketing automation — signals, plays, AI agents, data unification  
**ONE:** Signal-based substrate — agent coordination with learned paths and probabilistic routing

These serve **opposite audiences** (sales/marketing teams vs. developers) but share **three core concepts** (Signals, Agents, Data) implemented with fundamentally different architectures.

---

## 1. Platform Comparison Matrix

| Dimension | UnifyGTM | ONE | Note |
|-----------|----------|-----|------|
| **Primary user** | Sales/marketing teams | Developers building agents | Opposite audiences |
| **Core abstraction** | Plays (workflows) + Signals (intent) | Signals (verbs) + Paths (learning) | Both "Signals" but different |
| **Agent role** | AI research + personalization | Peer coordination + decision-making | Different model |
| **Data model** | Custom objects (schema-driven) | 6 locked dimensions | UnifyGTM: flexible; ONE: rigid |
| **API style** | REST (Objects/Attributes/Records) | Receiver namespace (verbs) | REST vs. verb-driven |
| **Learning** | No explicit learning | Path weights (highways/fade/mark/warn) | ONE has Markov-like state |
| **Integration** | HubSpot, Salesforce, 6sense, Clearbit | Composio, external webhooks | UnifyGTM: CRM-centric; ONE: open |
| **SDKs** | Python, TypeScript, JS | TypeScript only | UnifyGTM broader |
| **Deployment** | SaaS (cloud-only) | SaaS + workers (on-premise ready) | ONE more flexible |

---

## 2. Signals — Core Concept, Different Implementation

### UnifyGTM Signals

**Definition:** Data sources providing insights into buying intent

**Three types:**
1. **Native Signals** — new hires, job changes, website visits, email opens
2. **Third-Party Signals** — 6sense, Clearbit, Demandbase, G2
3. **Infinity Signals** — AI-powered (web scraping, news parsing, PDFs, OpenAI computer use)

**Use:** Trigger Plays (workflows) when signals fire

### ONE Signals

**Definition:** Fire-and-forget events with optional response

```ts
// Fire-and-forget
one.signal("agents:commend", { uid })

// Fire-and-wait (synchronous)
one.ask("market:hire", { skill, budget })
  → { outcome: 'result' | 'timeout' | 'dissolved' | 'failure', payload }
```

**Learning:** Signals strengthen/weaken paths

```ts
one.mark(edge)    // Strengthen path
one.warn(edge)    // Weaken path
one.fade()        // Asymmetric decay
```

| Aspect | UnifyGTM | ONE | Winner |
|--------|----------|-----|--------|
| **Intent detection** | ✅ Native + third-party | ❌ None | UnifyGTM |
| **Trigger workflows** | ✅ Plays | ✅ Receivers | Tie |
| **Learning from signals** | ❌ No path reinforcement | ✅ mark/warn/fade | ONE |
| **Signal routing** | ❌ Broadcast only | ✅ Receiver namespace + path strength | ONE |

---

## 3. Agents — AI Personalization vs. Peer Coordination

### UnifyGTM Agents

**Role:** AI research + copy generation

**Capabilities:**
- Scrape websites for company information
- Browse the internet for research
- Analyze PDFs, news feeds
- Use OpenAI computer use model
- Generate personalized email/call scripts
- Qualify leads based on research

### ONE Agents

**Role:** Peer coordination with decision-making authority

**Capabilities:**
- Receive signals from other agents/humans
- Ask questions (synchronous with 30s timeout)
- Mark/warn paths based on experience
- Read learned hypotheses (highways)
- Signal other agents
- Run co-signed or scoped transactions

| Aspect | UnifyGTM | ONE | Winner |
|--------|----------|-----|--------|
| **AI research** | ✅ Web scraping, news, PDFs | ❌ None | UnifyGTM |
| **Personalization** | ✅ Copy generation | ❌ None | UnifyGTM |
| **Coordination** | ❌ Sequential only | ✅ signal/ask + wait | ONE |
| **Authority** | ❌ AI writes, human approves | ✅ Agent can co-sign txs | ONE |
| **Learning** | ❌ No historical paths | ✅ Path weights | ONE |

---

## 4. Data Platform — Schema-Driven vs. Locked Dimensions

### UnifyGTM Data API

**Model:** Custom objects with flexible schema

```json
POST /api/v1/objects
{
  "provider": "CUSTOMER",
  "api_name": "deal",
  "display_name": "Sales Deal"
}
```

**Flexibility:** Users can create any schema instantly.

### ONE Data Model

**Model:** 6 locked dimensions + TypeDB

```
1. Groups      (containers)
2. Actors      (who acts)
3. Things      (what exists)
4. Paths       (weighted connections)
5. Events      (what happened)
6. Learning    (what was discovered)
```

| Aspect | UnifyGTM | ONE | Winner |
|--------|----------|-----|--------|
| **Schema flexibility** | ✅ Create any object | ❌ 6 locked dimensions | UnifyGTM |
| **No migrations** | ✅ Add fields instantly | ❌ TypeQL migrations required | UnifyGTM |
| **Query language** | ❌ REST only | ✅ TypeQL (graph DB native) | ONE |
| **Path queries** | ❌ No relationship strength | ✅ Query path weights directly | ONE |
| **Relational** | ❌ Limited | ✅ Native path queries | ONE |

---

## 5. Integrations

### UnifyGTM

**CRM:** HubSpot, Salesforce  
**Intelligence:** 6sense, Clearbit, Demandbase, G2  
**Communication:** Gmail, Slack, Nooks, Orum  
**Data Movement:** Fivetran, Hightouch  
**Analytics:** PostHog, Segment, Google Tag Manager

**Total: 12+ integrations**

### ONE

**Data:** TypeDB, D1, KV, R2  
**Agents:** Telegram, Discord, HTTP  
**Tooling:** Composio, Claude Desktop, Anthropic API  
**Blockchain:** SUI, Ethereum, Solana, Base, Arbitrum, Optimism

**Total: 10+ integrations**

| Aspect | UnifyGTM | ONE |
|--------|----------|-----|
| **CRM sync** | ✅ HubSpot, Salesforce | ❌ Webhook only |
| **B2B intelligence** | ✅ 6sense, Clearbit | ❌ None |
| **Email delivery** | ✅ Gmail managed | ✅ Via SMTP |
| **Chat platforms** | ✅ Slack | ✅ Telegram, Discord |
| **AI/LLM** | ❌ OpenAI only | ✅ Anthropic + OpenRouter |
| **Blockchain** | ❌ None | ✅ SUI, Ethereum, Solana |

---

## 6. Use Case Suitability

### Use UnifyGTM if:

✅ Sales/marketing team using email, calls, sequences  
✅ Need intent detection (new hires, job changes)  
✅ Want AI-powered personalization (copy generation)  
✅ Require HubSpot/Salesforce integration  
✅ Building CRM workflows (visual, low-code)  

### Use ONE if:

✅ Building AI agent networks  
✅ Need peer-to-peer signaling (agent↔agent)  
✅ Want learning paths (which agents/routes succeed)  
✅ Require synchronous coordination (ask + wait)  
✅ Multi-chain support (SUI, Ethereum, Solana)  
✅ Developer-first APIs (not visual builders)  
✅ On-premise deployment (CF Workers)  

---

## 7. Could ONE + UnifyGTM Integrate?

### Scenario: "Unified Outbound"

```
UnifyGTM Side:
  New hire detected (Infinity Signal)
  → Play triggers: "Personalized Outreach"
    → Agent AI researches company + hire
    → Sends signal to ONE

ONE Side:
  Signal: "outreach:newHire"
    + context: { company, hire_name, research_summary }
  → Routes via strongest path
    → Agent A (copywriter): writes email
    → Agent B (caller): schedules call
    → Both mark the path if successful
  → Next time: strengthen the winning path

Result:
  Each signal makes the system smarter
  UnifyGTM provides intent, ONE provides learning
```

---

## 8. Verdict: Complementary, Not Competitive

| Aspect | Winner | Why |
|--------|--------|-----|
| **Sales automation** | UnifyGTM | Designed for it |
| **Intent detection** | UnifyGTM | Native signals |
| **Agent coordination** | ONE | Peer-to-peer |
| **Learning paths** | ONE | mark/warn/fade |
| **Flexibility** | ONE | Code-first |
| **Enterprise ready** | UnifyGTM | Versioned, stable |
| **Developer friendly** | ONE | SDKs, MCP |

**Final verdict:** These are **complementary, not competitive**.

- **UnifyGTM** = intent source + workflow execution
- **ONE** = learning engine + agent coordination

A combined system (UnifyGTM Signals → ONE Agent Learning) would be **more powerful than either alone**.
