---
name: /do lifecycle
description: The /do build lifecycle — idea to shipped feature. Covers the artifact spine (promise → spec → todo → code → tests → proof → docs → release), the W0-W4 BUILD engine, tier classifier (PATCH/FIX/FEATURE/SCHEMA), trust system, token economy, and the dependency graph for cross-cycle parallelism. Use when working on or extending the /do harness itself.
version: 2.0.0
---

The `/do` lifecycle harness lives in `commands/do.md`. See that file for the full contract.

Key files:
- `commands/do.md` — the lifecycle + BUILD engine
- `commands/do-autonomous.md` — autonomous loop mode
- `commands/do-show.md` — cycle frame rendering
- `commands/do-improve.md` — meta-improvement from drift signals
- `agents/w1-recon.md` — recon agent
- `agents/w2-decide.md` — decide agent
- `agents/w3-edit.md` — edit agent
- `agents/w4-verify.md` — verify agent
- `scripts/do-tier.sh` — tier + pruned spine + classifier + token ceiling
- `scripts/do-folder.sh` — folder-aware verify/build
- `scripts/do-survey.sh` — reuse verdict (expose/extend/build/drop)
- `scripts/do-analyze.sh` — spec↔todo coverage gate
- `scripts/do-prove.sh` — surface-detect proof
- `scripts/do-reconcile.sh` — substrate dim/verb/dead-name gate
- `scripts/do-smoke.sh` — deterministic outcome check
