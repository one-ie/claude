---
name: fleet-audit
description: How to run multi-fleet agent audits without contradiction — probe before reading, shared measurement pack, one join fleet, default REFUTED, fleet-prompt rules. Use when the operator opts into multi-agent audits or fleets.
---

# Multi-fleet audits — how the 2026-08-25 launch audit actually worked

When the operator opts into multi-agent work, this shape holds up. Six fleets ran
concurrently from one window without contradicting each other.

**1. Probe before you read.** Every launch-blocking finding that day came from a
live probe; not one would have been caught by reading source. The codebase is
honest about intent and silent about reachability — *declared ≠ wired ≠ configured
≠ reachable ≠ working from this egress IP*. Mint a real checkout to learn the
Stripe mode. Read a D1 **count** (`2 of 68`) to learn if a feature is used. Probe a
third-party API **from where the code runs** — Solana's public RPC 403s CF egress
and serves a laptop happily. Treat any `/status` route as a claim: `pay/backend/src/routes/status.ts:37`
hardcodes its chain list as a literal array.

**2. Synchronise by shared evidence, not by orchestration.** Build ONE measurement
pack of file:line facts, then embed it verbatim in every fleet prompt. Fleets given
identical facts cannot drift; fleets given only a task description will.

**3. One fleet is the join.** A final fleet folds every other fleet's findings back
into `text/one.md`, which already carries the rule: *the specific doc wins and the
spine gets reconciled.*

**4. Default REFUTED on every verify, and demand the quoted stopping line.** "No
quotable line ⇒ not proven" is what catches plausible-but-wrong fixes.

**5. Two instances of one defect shape ⇒ fix the seam, never the sites.** Two
unrelated fleets hit the same unenforced-auth-label bug. That is a root cause and a
base rate, not two bugs — patching both sites would have left ~300 receivers open.

**6. Kill a fleet the moment its premise dies.** When the design changed from
"convert a stranger" to "an agent provisions the account", the in-flight blocker
fleet was still building an *anonymous checkout* — the exact unauthenticated write
path every other verifier was hunting. Stop it; discard the worktree.

**Four rules for the fleet prompts themselves:**

- **Never let a fleet spend money to prove a point.** One audit billed ~$0.215 of
  real DataForSEO credit demonstrating an anonymous-spend hole. Correct finding,
  wrong method — once the first call proves the door is open, reason from code, and
  say so in the prompt.
- **Never simulate a run and report it as one.** Instruct explicitly: *if you
  cannot execute for real, say so and STOP.* A fabricated run report poisons every
  decision downstream of it.
- **Give a legitimate "no change needed" exit.** Telling one fleet that "leave it
  gated, fix the funnel order" was an acceptable answer stopped it punching a hole
  in the payment path to make a landing page prettier.
- **Name the forbidden sentence.** For anything customer-facing, have the fleet
  emit the sentences that would be FALSE, quoted verbatim, so nobody ships them by
  accident. This is what caught "Google recovers your wallet".

**Isolation:** worktrees for writers only; doc-only and read-only fleets don't need
one. Watch for a fleet editing shared `main` — that is how a neighbour's work gets
swept into the wrong commit.
