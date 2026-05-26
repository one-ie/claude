---
title: Agent Skills — Clone & Categorise
slug: agent-skills
type: plan
tier: simple
mode: construction
tags: [agents, skills, community]

parallel_budget:
  haiku:   10
  sonnet:  4
  opus:    1

batches:
  - [C1]
  - [C2]

shared_recon:
  - plans/agent-skills-inventory.md

source_of_truth:
  - plans/agent-skills-inventory.md

existing_primitives:
  - Server/apps/: sibling apps directory — target parent for agent-skills/
  - plans/agent-skills-inventory.md: 20 agents, 16 unique GitHub repos, grouped by Marketing/Sales/Service/Community
  - one-ie/.claude/agents/: agent markdown pattern reference

show: false
escape:
  condition: ""
  action: ""
context_triggers: []
---
/cl
# Agent Skills — Clone & Categorise

**Goal:** Clone all GitHub repos from agent-skills-inventory.md into `Server/apps/agent-skills/` and produce `plans/agent-skills-org-map.md` mapping each repo to its role, category, and skills — linked into the org-chart.
**Exit:** `ls Server/apps/agent-skills/` shows ≥14 directories AND `plans/agent-skills-org-map.md` exists with all 20 agents categorised under Marketing/Sales/Service/Community headings, each entry linking to its cloned dir.

---


## C1 — clone repos  [tier: simple · batch: 1]

**Exit:** `ls Server/apps/agent-skills/ | wc -l` ≥ 14

**Demo gate:**
```yaml
demo:
  command: "ls /Users/toc/Server/apps/agent-skills/ | wc -l"
  asserts: "≥14 directories exist under agent-skills/"
  budget:  "<2s wall · bash only"
```

### W1 — Recon  [inline — shared_recon covers it]

- [ ] `plans/agent-skills-inventory.md` — extract unique clonable GitHub URLs

**Unique repos to clone (15 clonable; Citedy is API-only → skip):**

| Dir name | Repo |
|---|---|
| `marketing-skills` | https://github.com/kostja94/marketing-skills |
| `alwrity` | https://github.com/AJaySi/ALwrity |
| `claude-blog` | https://github.com/AI-Marketing-Hub/claude-blog |
| `agentic-seo` | https://github.com/Bhanunamikaze/Agentic-SEO-Skill |
| `marketing-agent-skills` | https://github.com/realjaymes/marketingagentskills |
| `ai-marketing-skills` | https://github.com/ericosiu/ai-marketing-skills |
| `salesgpt` | https://github.com/filip-michalsky/SalesGPT |
| `sales-outreach` | https://github.com/kaymen99/sales-outreach-automation-langgraph |
| `skills-dhruv` | https://github.com/aiagentwithdhruv/skills |
| `marketing-skills-corey` | https://github.com/coreyhaines31/marketingskills |
| `email-marketing-agent` | https://github.com/theaifutureguy/email-marketing-ai-agent |
| `social-media-agent` | https://github.com/langchain-ai/social-media-agent |
| `agency-agents` | https://github.com/msitarzewski/agency-agents |
| `social-gpt` | https://github.com/Social-GPT/agent |
| `agent-social-marketing` | https://github.com/agentuity/agent-social-marketing |

### W2 — Decide  [inline]

- [ ] **Compose-or-construct verdict:** bash clones only — no new code files
- [ ] Target dir: `/Users/toc/Server/apps/agent-skills/` (create if absent)
- [ ] Clone strategy: `git clone --depth 1 <url> <dir>`

### W3 — Edit  [Sonnet · single agent]

**W3a:**
- [ ] `mkdir -p /Users/toc/Server/apps/agent-skills/` then `git clone --depth 1` all 15 repos

**W3b:** *(empty)*

### W4 — Verify

- [ ] `ls /Users/toc/Server/apps/agent-skills/ | wc -l` ≥ 14
- [ ] Spot-check 5 dirs: marketing-skills, salesgpt, social-media-agent, agentic-seo, agency-agents
- [ ] No clone errors
- [ ] Rubric composite ≥ 0.65

---

## C2 — generate agent-skills-org-map.md  [tier: simple · batch: 2]

**Exit:** `grep -c "^###" plans/agent-skills-org-map.md` ≥ 20

**Demo gate:**
```yaml
demo:
  command: "grep -c '^###' /Users/toc/Server/one-ie/plans/agent-skills-org-map.md"
  asserts: "≥20 agent entries in org-map"
  budget:  "<2s wall · bash only"
```

### W1 — Recon  [inline]

- [ ] `plans/agent-skills-inventory.md` — full 20-agent roster with categories and skill lists
- [ ] `Server/apps/agent-skills/` — actual cloned dir names from C1 (used as local path links)

### W2 — Decide  [inline]

- [ ] **Compose-or-construct:** one new file `plans/agent-skills-org-map.md` — no existing primitive covers this
- [ ] Structure: four top-level sections (Marketing | Sales | Service | Community)
- [ ] Each agent entry: role title, local path `../../apps/agent-skills/<dir>`, GitHub URL, install command, key skills list
- [ ] Top-level summary table mirrors the inventory quick-summary, with local path column added

### W3 — Edit  [Sonnet · single agent]

**W3a:**
- [ ] Write `plans/agent-skills-org-map.md` — full org-map with local path links to cloned dirs

**W3b:** *(empty)*

### W4 — Verify

- [ ] `grep -c "^###" plans/agent-skills-org-map.md` ≥ 20
- [ ] All four category headings present: `grep -cE "^## (Marketing|Sales|Service|Community)" plans/agent-skills-org-map.md` = 4
- [ ] Every cloned dir name appears as a path in the org-map
- [ ] Rubric composite ≥ 0.65

---

## See also

- `plans/agent-skills-inventory.md` — source data for all cycles
- `Server/apps/agent-skills/` — cloned repos (written by C1, read by C2)
- `plans/dictionary.md` — canonical names
- `plans/rubrics.md` — scoring bands
