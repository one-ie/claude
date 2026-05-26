---
title: Social Chat
slug: social-chat
type: plan
tier: moderate
mode: construction
tags: [social, chat, cards, agent, composio]

goal: "User types a social post request in chat — 'post about X on LinkedIn' — and the agent drafts it, returns a SocialDraftCard in the thread, and the user approves/schedules/sends directly from the card without leaving chat."
outcome: "grep -q 'social-draft' one.ie/web/src/lib/cards.ts && test -f one.ie/web/src/components/cards/SocialDraftCard.tsx && grep -q 'social-draft' one.ie/web/src/components/chat/MessageRenderer.tsx && grep -q 'emit_card' agents/src/aitools.ts"
outcome_asserts: "SocialDraftCard type in the union, component on disk, wired into MessageRenderer, and draft_social_post emits a card so the chat thread shows it."

deliverables:
  - lib: one.ie/web/src/lib/cards.ts — add social-draft CardData kind (C1)
  - component: one.ie/web/src/components/cards/SocialDraftCard.tsx — renders platform badges, content, char bar, Approve / Send Now / View actions (C1)
  - wire: one.ie/web/src/components/chat/MessageRenderer.tsx — dispatch social-draft → SocialDraftCard (C1)
  - agent-tool: agents/src/aitools.ts — draft_social_post emits a card (kind:social-draft) via emit_card after posting draft (C1)

ux_before: "To post on social via chat the user must say 'post X', get a text reply with confirmation, then go to /in/[group]/social to see the draft and click Approve."
ux_after: "User says 'post about X on LinkedIn and Twitter' in chat. Agent drafts it, a card appears in the thread with platform badges, char count, and Approve / Send Now buttons. Approve schedules it; Send Now publishes immediately — no tab switch required."
ux_delta: "Chat becomes a complete social posting surface — compose, approve, and publish without leaving the conversation."

parallel_budget:
  haiku:  8
  sonnet: 4
  opus:   1

batches:
  - [C1]

shared_recon:
  - one.ie/web/src/lib/cards.ts
  - one.ie/web/src/components/chat/MessageRenderer.tsx
  - agents/src/aitools.ts
  - one.ie/web/src/pages/api/social/posts/index.ts
  - one.ie/web/src/pages/api/social/posts/[id]/publish.ts

source_of_truth:
  - one.ie/web/src/lib/cards.ts
  - agents/src/aitools.ts

existing_primitives:
  - agents/src/aitools.ts: draft_social_post — already creates the DB row; C1 extends it to also call emit_card with the post id/content/platforms
  - one.ie/web/src/lib/cards.ts: CardData union — C1 extends with social-draft kind (same pattern as signup/checkout added in home-chat)
  - one.ie/web/src/components/chat/MessageRenderer.tsx: switch(data.kind) dispatch — C1 adds one case (same pattern as campaign, team-message)
  - one.ie/web/src/pages/api/social/posts/[id]/publish.ts: POST endpoint — SocialDraftCard's Send Now button hits this directly
  - one.ie/web/src/pages/api/social/posts/[id].ts: PATCH endpoint — SocialDraftCard's Approve / Schedule buttons PATCH status/scheduled_at
  - one.ie/web/src/lib/social-validate.ts: PLATFORM_RULES — card reads charLimit per platform for the char bar; import from this lib, do not inline limits
  - one.ie/web/src/components/social/SocialComposer.tsx: PLATFORMS const — platform label + icon map to reuse

show: false
---

# Social Chat

## Goal

User composes a social post through natural language in the chat UI. The agent calls `draft_social_post`, which creates the DB row **and** returns a `SocialDraftCard` in the thread. The card shows platform badges, content preview, per-platform char bar, and inline actions — no context switch to `/in/social`.

---

## The card shape (`social-draft`)

```ts
{
  kind: 'social-draft'
  postId: string                                 // DB id in social_posts
  content: string
  platforms: ('twitter' | 'linkedin' | 'instagram' | 'tiktok' | 'facebook')[]
  scheduledAt?: number                           // unix epoch; absent = unscheduled
  groupId: string                                // needed for PATCH/publish calls
  workspaceUrl: string                           // /in/[groupId]/social — "view" link
}
```

Actions the card exposes: `approve` · `send-now` · `view`. Edit redirects to `workspaceUrl` (full editor).

---

## What each action does

| Action button | API call | Result |
|---|---|---|
| **Approve** | `PATCH /api/social/posts/:id { status: 'scheduled', scheduledAt }` | status → scheduled; scheduler picks it up at `scheduledAt` |
| **Send Now** | `POST /api/social/posts/:id/publish` | immediate Composio publish across all platforms |
| **View** | link to `workspaceUrl` | full editor + kanban context |

Approve without a `scheduledAt` on the card → sets `status='approved'`; scheduler cron will not pick it up until a date is set. The card shows a mini date-time picker inline before the Approve button fires if `scheduledAt` is absent.

---

## Where `emit_card` fires

`draft_social_post` in `agents/src/aitools.ts` already calls `POST /api/social/posts` and gets back `{ post: { id } }`.

After that success, it calls the existing `emit_card` tool with:

```ts
{
  kind: 'social-draft',
  postId: post.id,
  content,
  platforms,
  scheduledAt,
  groupId: session.groupId,
  workspaceUrl: `/in/${session.groupId}/social`,
}
```

The AI SDK renders that as a card frame in the message thread. `MessageRenderer` dispatches `kind === 'social-draft'` → `SocialDraftCard`.

---

## SocialDraftCard UI spec

```
┌─────────────────────────────────────────────────┐
│  [LinkedIn] [X/Twitter]           Draft          │
│─────────────────────────────────────────────────│
│  "Here's a look at our new AI features..."      │
│                                                  │
│  LinkedIn  ████████████░░░░░░░░  48 / 3000      │
│  X/Twitter ████████████░░░░░░░░  48 / 280       │
│                                                  │
│  [  Schedule for 09:00 ▾  ]                     │
│                                                  │
│  [ View ]  [ Approve ]  [ Send Now ]             │
└─────────────────────────────────────────────────┘
```

- Platform badges: pill with lucide icon + label; one per selected platform
- Content: full text, no truncation inside the card
- Char bar per platform: `PLATFORM_RULES[p].charLimit` from `social-validate.ts`; red when over limit
- Schedule picker: `<input type="datetime-local">` collapsed behind "Schedule for…" — only shown when Approve is about to fire and `scheduledAt` is absent
- Buttons use the standard 6-variant pattern (View = ghost, Approve = outline, Send Now = primary)
- On Approve success: card title changes to "Scheduled · [date]"; buttons collapse to [View]
- On Send Now success: card title changes to "Published"; per-platform post URL links appear below

---

## Card state machine

```
draft (initial)
  → [Approve + scheduledAt set]  → scheduled (card title updates, buttons collapse)
  → [Approve, no scheduledAt]    → approved  (card shows "Awaiting schedule")
  → [Send Now]                   → publishing (spinner) → published / failed
```

The card holds local state for the transition; the DB is the authority. On published/failed, the card shows the outcome and disables further action.

---

## Char count per platform

The card shows one bar per platform. Color rules:

| Ratio | Bar color |
|---|---|
| < 80% | `var(--color-primary)` |
| 80–99% | `var(--color-secondary)` |
| ≥ 100% (over) | `var(--color-destructive)` |

If any platform is over limit, Approve and Send Now disable with a tooltip: "Content exceeds [platform] limit".

---

## Natural language triggers (agent prompt guidance)

The existing `social-media-manager.md` agent handles "plan next week" style requests. For direct chat-driven posting, the agent route (`/message`) already uses `aitools.ts`. The agent system prompt should include:

> When the user asks to post, publish, or share something on social media, call `draft_social_post` with their content and platform(s). If platforms are not specified, default to the group's connected platforms. Always draft first (status=draft); do not skip the card — the human approves.

This belongs as a sentence in the general agent system prompt / `AGENT_SYSTEM_PROMPT` env var, not as a dedicated agent markdown file (the request may come from any agent persona).

---

## Files changed

| File | Change |
|---|---|
| `one.ie/web/src/lib/cards.ts` | extend `CardData` with `social-draft` kind |
| `one.ie/web/src/components/cards/SocialDraftCard.tsx` | new component ≤200 LOC |
| `one.ie/web/src/components/chat/MessageRenderer.tsx` | one case in the switch |
| `agents/src/aitools.ts` | `draft_social_post` emits card after successful POST |

No new API routes. No new DB columns. Everything routes through the existing `POST /api/social/posts` + `PATCH /api/social/posts/:id` + `POST /api/social/posts/:id/publish` that the social-poster plan already ships.

---

## C1 — Card + tool wiring  [tier: moderate · batch: 1]

**Goal delta:** Typing "post about X on LinkedIn" in chat renders a SocialDraftCard with Approve / Send Now. The whole thing is wired end-to-end.

**Cycle outcome:** `grep -q 'social-draft' one.ie/web/src/lib/cards.ts && test -f one.ie/web/src/components/cards/SocialDraftCard.tsx && grep -q 'social-draft' one.ie/web/src/components/chat/MessageRenderer.tsx`

**Demo gate:**
```yaml
demo:
  command: "bun run verify && grep -q 'social-draft' one.ie/web/src/lib/cards.ts && grep -q 'SocialDraftCard' one.ie/web/src/components/chat/MessageRenderer.tsx && echo pass"
  asserts: "type in union, component wired into renderer, tsc clean"
  budget: "<10s · 0 LOC test overhead (covered by tsc)"
```

### W1 — Recon

- [ ] `one.ie/web/src/lib/cards.ts` — full union; the two most recent additions (`signup`, `checkout`, `team-message`) as shape reference
- [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — full switch; the `campaign` or `team-message` case as wiring reference
- [ ] `agents/src/aitools.ts` — `draft_social_post` current shape; how `emit_card` is called by other tools
- [ ] `one.ie/web/src/components/social/SocialComposer.tsx` — PLATFORMS const for icons/labels; re-use, don't copy
- [ ] `one.ie/web/src/lib/social-validate.ts` — PLATFORM_RULES export shape (charLimit per platform for the char bar)
- [ ] One existing card component (e.g. `ResultCard.tsx`) as structural reference for the design pattern

### W2 — Decide

- [ ] **Compose-or-construct:**

| Proposed | Closest | Gap | Verdict |
|---|---|---|---|
| `social-draft` in `cards.ts` | existing union | new discriminant needed | **extend** union |
| `SocialDraftCard.tsx` | no close match | new card | **new** ≤200 LOC; imports PLATFORM_RULES + emitClick |
| MessageRenderer case | existing switch | one new case | **extend** |
| `draft_social_post` emit | existing tool POSTs and returns; `emit_card` pattern exists | missing emit_card call | **extend** tool (2–5 LOC) |

- [ ] **Card actions** — Approve fires `PATCH /api/social/posts/:id`; Send Now fires `POST /api/social/posts/:id/publish`; View is an `<a>` to `workspaceUrl`. No new API routes.
- [ ] **Schedule picker** — `<input type="datetime-local">` inside the card; only shown when Approve is about to fire without a `scheduledAt`. No popover lib needed.
- [ ] **Over-limit guard** — `validatePost` from social-validate, run client-side on content+platforms; disable action buttons if `!ok`; show per-platform error strings from `errors[]`.
- [ ] **Optimistic state** — card transitions locally on button click; on API failure, revert + show `error`.

### W3 — Edit  [Sonnet]

**W3a — independent:**
- [ ] `one.ie/web/src/lib/cards.ts` — add `social-draft` discriminant to `CardData` union
- [ ] `one.ie/web/src/components/cards/SocialDraftCard.tsx` — full component per UI spec above; imports from `social-validate.ts` (char limits), `SocialComposer.tsx` PLATFORMS (icons/labels), `emitClick` from `ui-signal`
- [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — add `case 'social-draft': return <SocialDraftCard ...>`

**W3b — dependent on W3a:**
- [ ] `agents/src/aitools.ts` — after the `POST /api/social/posts` success in `draft_social_post`, call `emit_card` with the social-draft shape; no change to the tool's input schema or validation

### W4 — Verify

- [ ] `bun run verify` green (tsc + vitest) — `delta_tsc = 0`
- [ ] Demo gate command exits 0
- [ ] Design rule check: no hex literals, no Tailwind palette classes, no inline SVG icons (lucide only), all buttons use `emitClick`
- [ ] Reuse audit: `SocialDraftCard` imports `PLATFORM_RULES` (not inlined limits); icons from `lucide-react`; PATCH/publish calls the existing API routes (grep — no new fetch targets)
- [ ] Closed-loop check: `draft_social_post` still calls `mark`/`warn` after publish — the emit_card addition must not remove the substrate close
- [ ] goal-fit ≥ 0.50 · composite ≥ 0.65

---

## See also

- `plans/social-poster.md` — the full social system this builds on (API, scheduler, kanban, calendar) — read it first; social-chat adds zero new infrastructure
- `one.ie/web/src/lib/cards.ts` — CardData union (source of truth for card types)
- `one.ie/web/src/lib/social-validate.ts` — PLATFORM_RULES (charLimit per platform)
- `agents/src/aitools.ts` — `draft_social_post` + `emit_card` (the two tools that compose)
- `one.ie/web/src/components/social/SocialComposer.tsx` — PLATFORMS const to reuse (icons + labels)
- `one.ie/web/src/pages/api/social/posts/[id]/publish.ts` — the publish endpoint Send Now calls
- `plans/dictionary.md` — canonical names; never use "pheromone" in card labels
