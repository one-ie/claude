# Partner Access — Donal (Agency)

## Goal

Give Donal agency-level access to build alongside Tony using Claude Code on the private one-ie repo.

## Repo access (GitHub)

1. Go to **github.com/one-ie/one → Settings → Collaborators and teams**
2. Click **Add people** → search Donal's GitHub username or email
3. Set role: **Write** (can push branches, open PRs) or **Maintain** (can merge, manage settings short of admin)
4. Donal accepts the invite via email or `github.com/notifications`

For org repos: add him to a team (e.g. `agency`) with Write access to the repo instead of individual collaborator.

## Claude Code setup for Donal

Once he has repo access, Donal runs Claude Code against the same codebase. Key files he needs to read first:

| File | Why |
|------|-----|
| `CLAUDE.md` (root) | Geography — what's load-bearing, what's scratch |
| `one-ie/CLAUDE.md` | Operating manual — tech stack, locked names, rules |
| `one-ie/.claude/CLAUDE.md` | Harness — /do, /create, /close commands |
| `one-ie/plans/dictionary.md` | Canonical names — never deviate |
| `one-ie/plans/contracts.md` | Verb pre/post/inv contracts |

## Workflow boundaries

- All work goes through feature branches → PRs → Tony reviews before merge to main
- Donal uses `/do` for implementation cycles (W1→W4 gated by rubric ≥ 0.65)
- Donal uses `/create` for new feature plans, `/close` to propagate doc changes
- No direct pushes to main

## What Donal should not touch

- `schema/one.tql` — schema changes need explicit Tony sign-off (locked: 6 dims, 6 verbs)
- `text/` — marketing copy follows the voice contract in `.claude/product-marketing.md`
- Cloudflare / TypeDB credentials — Tony holds these; Donal works against local mocks or staging env

## Staging environment (to set up)

Donal needs his own `.dev.vars` / `.env` pointing to a staging TypeDB instance or local Docker. Document shared secrets in 1Password (not in repo).

## Communication

- PRs are the primary async channel — use PR descriptions to explain decisions
- Tag `@toc` on PRs that touch locked rules, schema, or public surfaces
