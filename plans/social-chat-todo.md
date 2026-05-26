---
title: Social Chat
slug: social-chat
type: plan
tier: simple
mode: construction
tags: [social, chat, cards, agent]

goal: "User says 'post X on LinkedIn' in chat and a SocialDraftCard appears in the thread with Approve / Send Now buttons."
outcome: "grep -q 'social-draft' one.ie/web/src/lib/cards.ts && test -f one.ie/web/src/components/cards/SocialDraftCard.tsx && grep -q 'social-draft' one.ie/web/src/components/chat/MessageRenderer.tsx && grep -q 'emit_card' agents/src/aitools.ts"
outcome_asserts: "SocialDraftCard type in union, component on disk, wired into MessageRenderer, and draft_social_post emits a card."

deliverables:
  - lib: one.ie/web/src/lib/cards.ts — social-draft CardData kind
  - component: one.ie/web/src/components/cards/SocialDraftCard.tsx — platform badges, char bar, Approve / Send Now / View
  - wire: one.ie/web/src/components/chat/MessageRenderer.tsx — dispatch social-draft → SocialDraftCard
  - agent-tool: agents/src/aitools.ts — draft_social_post emits card after creating draft

ux_before: "User asks agent to post on social, gets a text reply, must navigate to /in/social to approve."
ux_after: "User asks in chat, a SocialDraftCard appears in the thread; user approves or sends from the card."
ux_delta: "Chat becomes a complete social posting surface — no tab switch required."

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
  - agents/src/aitools.ts: draft_social_post exists; C1 extends it to call emit_card
  - one.ie/web/src/lib/cards.ts: CardData union; C1 adds social-draft (same pattern as signup/checkout)
  - one.ie/web/src/components/chat/MessageRenderer.tsx: switch dispatch; C1 adds one case
  - one.ie/web/src/pages/api/social/posts/[id]/publish.ts: Send Now calls this directly
  - one.ie/web/src/pages/api/social/posts/[id].ts: Approve PATCHes status/scheduled_at
  - one.ie/web/src/lib/social-validate.ts: PLATFORM_RULES for char limits in the card

show: false
---

# Social Chat

## Status

```
Batch 1
  - [x] C1 — Card + tool wiring    state: done
    - [x] W0
    - [x] W1
    - [x] W2
    - [x] W3
    - [x] W4

Plan close — outcome kill-switch
  - [x] outcome command exits 0
  - [x] deliverables all shipped
```

---

## C1 — Card + tool wiring  [tier: simple · batch: 1]

### W1 — Recon
- [ ] `one.ie/web/src/lib/cards.ts` — full union + two most recent additions as shape reference
- [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — full switch dispatch pattern
- [ ] `agents/src/aitools.ts` — draft_social_post + emit_card usage
- [ ] `one.ie/web/src/lib/social-validate.ts` — PLATFORM_RULES shape
- [ ] `one.ie/web/src/components/social/SocialComposer.tsx` — PLATFORMS const (icons/labels)

### W2 — Decide
- [ ] W2 gate: goal-delta · deliverable · ux-delta
- [ ] Compress check per primitive
- [ ] Diff specs written → .w2-spec.json

### W3 — Edit
- [ ] `one.ie/web/src/lib/cards.ts` — add social-draft to CardData union
- [ ] `one.ie/web/src/components/cards/SocialDraftCard.tsx` — new component
- [ ] `one.ie/web/src/components/chat/MessageRenderer.tsx` — dispatch case
- [ ] `agents/src/aitools.ts` — emit_card after draft_social_post success

### W4 — Verify
- [ ] bun run verify green (tsc + vitest)
- [ ] outcome command exits 0
- [ ] delta_tsc ≤ 0
- [ ] rubric composite ≥ 0.65
