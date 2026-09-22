# PROVENANCE — vendored, not ours

This directory is **generated output from an external repository**, copied verbatim
except for the two deltas recorded below. Do not hand-edit it. To take an upstream
change: re-clone, re-copy, re-apply the deltas, and update the sha here.

| | |
|---|---|
| Upstream | https://github.com/cloudflare/security-audit-skill |
| Path taken | `skills/security-audit/` (all 20 files) + root `LICENSE` |
| Commit | `c1c8a8c1471069fb0e188eeaff69b8e8db6564a8` |
| Commit date | 2026-09-14T20:28:54+01:00 |
| Vendored | 2026-09-17 |
| Licence | MIT — Copyright (c) 2025-2026 Cloudflare, Inc. (`LICENSE`, in this directory) |

`.claude/` mirrors to github.com/one-ie/claude, so the MIT notice travels inside
this directory rather than only at the clone root.

## Verify it is still verbatim

```bash
git clone --depth 1 https://github.com/cloudflare/security-audit-skill /tmp/cfsec
diff -r /tmp/cfsec/skills/security-audit .claude/skills/cloudflare-security-audit \
  --exclude PROVENANCE.md --exclude LICENSE
# expected: ONE hunk, the SKILL.md frontmatter (the two deltas below). Anything
# else is either an upstream change to take, or a hand-edit to revert.
```

## The two deltas, and why

1. **`name: security-audit` → `name: cloudflare-security-audit`.** A skill's `name`
   must match its directory, and the directory could not be `security-audit`:
   `one.ie/ai/skills/security-audit/SKILL.md` already holds that name and is loaded
   by that exact path from `one.ie/ai/agents/security-auditor/agent.md`.

2. **`description` narrowed to whole-repo / third-party audits**, with an explicit
   pointer to ONE's own skill for everything else. The upstream description fires on
   "security questions, focused reviews, … or pen tests" — i.e. on a routine "is this
   secure?". That is the ONE question, and answering it out of this file would hand
   the reader a doctrine that *forbids* probing deployed endpoints. Which brings us to:

## The doctrine conflict — read this before loading the skill

The two skills disagree, on purpose, and the disagreement is load-bearing.

| | Cloudflare (this skill) | ONE (`one.ie/ai/skills/security-audit/SKILL.md`) |
|---|---|---|
| Target | somebody else's repo, assumed hostile | our own estate, assumed honest-but-silent |
| Evidence | source trace + a sandboxed fixture | a live probe from where the code runs |
| Deployed endpoints | **do not probe** | **probe, or you have proven nothing** |
| Running target code | only inside an OS-enforced sandbox | n/a |
| Output | `findings.json` + `REPORT.md` under `~/security-audit-skill/<repo>/run-N` | `{refuted, findings}`, or a compact report |

**Neither overrides the other. They are scoped by target:**

- **Running target-controlled code, or auditing a third-party / untrusted repo** →
  Cloudflare's sandbox envelope governs, in full. Every control it names, or you do
  not execute.
- **ONE's own deployed surfaces** → ONE's live-probe rule governs, unchanged and
  still mandatory. Every launch-blocking finding on record came from a live probe;
  not one would have been caught by reading. Reading the source and finding nothing
  wrong remains a refusal, not a clearance.

Taking Cloudflare's "do not probe deployed endpoints" as a general rule would delete
the one rule that has ever found anything here — a regression wearing an upgrade's
clothes.

## Mode, before you run it

The skill has two modes and says loading it authorizes neither.

- **Guidance mode** — the default, and the only mode on a review-lens turn. Use the
  relevant parts; write no files, create no output directory, run no six-phase
  workflow. A lens returns `REVIEW_SCHEMA` `{refuted, findings}`; the factory
  executor's `votes.flatMap` cannot read a `REPORT.md`.
- **Full audit mode** — only when a person or `cto` calls it in by hand for a repo
  audit or pen test. It orchestrates subagent fleets and writes a run directory
  outside the target.
