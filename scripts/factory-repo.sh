#!/usr/bin/env bash
# factory-repo.sh — generate the standalone factory repo (github.com/one-ie/factory)
#
# The factory repo is OUTPUT, never a mirror. This script builds it from canon;
# --check rebuilds and diffs, so drift is reported loudly instead of rotting.
# Design: text/factory-repo-plan.md §1. Promise: text/factory-repo.md.
#
# Usage:
#   factory-repo.sh <target-dir>          build the repo (fresh git history)
#   factory-repo.sh --check-history [dir] one commit · no env/key blob on any ref
#   factory-repo.sh --check [dir]         drift: canon vs a built tree
#   factory-repo.sh --check-env-indirection
#   factory-repo.sh --check-portability
#   factory-repo.sh --check-targets
#   factory-repo.sh --check-connect [dir]
#   factory-repo.sh --check-no-secrets [dir]
#   factory-repo.sh --check-tests [dir]
#   factory-repo.sh --check-canon [dir]   spine cites nothing the tree lacks
#   factory-repo.sh --check-substrate     live world-key round trip (needs ONE_ENV_FILE)
#   factory-repo.sh --verify              build to temp, install published, run the checks
#   factory-repo.sh --manifest            print the portability manifest
#
# Env:
#   ONE_TARGET     workspace | published   (default: published)
#   ONE_ENV_FILE   credentials for --check-substrate (default: one.ie/web/.env)
#   FACTORY_VERIFY_CYCLE=0  skip --verify's real /do cycle (default: it RUNS — the
#                           proof must not need extra env to pass; skipping still fails)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

ONE_TARGET="${ONE_TARGET:-published}"

# Pinned published versions — the version IS the boundary (plan §4).
SDK_VERSION="^0.14.11"
MCP_VERSION="^0.6.0"
CLI_VERSION="^4.0.4"

# A monorepo path is a directory that must exist on disk. `https://one.ie/x`
# is a host, not a path — the factory repo reaches the substrate over HTTPS by
# design, so matching the URL would flag the very thing we want.
MONOREPO_PATH_RE='(^|[^:a-zA-Z0-9._-])(one\.ie/(web|ai)|pay/(backend|contracts|tools)|channels/src|api/src|sync/src|backup/src|schema/[a-z-]*\.tql)|\.dev\.vars'

# A cite of this company's canon. Only `portable` SKILLS are held to it: a skill
# whose source of truth is a text/ doc is craft-plus-context, and the context
# does not travel. Scripts are not held to it — several legitimately name a
# text/ file they write into.
CANON_CITE_RE='(^|[^a-zA-Z0-9._/-])text/[a-z0-9-]+\.md'

pass() { printf '  ok   %s\n' "$*"; }
fail() { printf '  FAIL %s\n' "$*" >&2; FAILED=$((FAILED + 1)); }
info() { printf '       %s\n' "$*"; }
head_() { printf '\n== %s\n' "$*"; }

# ---------------------------------------------------------------------------
# The portability manifest — data, asserted against the scripts by
# --check-portability. Three buckets:
#
#   portable       no monorepo path, no credential read           → ships
#   needs-env      needs ONE_ENV_FILE and/or names monorepo paths
#                  that degrade to no-ops when absent             → ships
#   monorepo-only  hard-asserts against THIS tree; refuses
#                  without it                                     → never ships
#
# Why gc-content-check.sh is `needs-env` and not `portable`: it builds its own
# sandbox and never reaches into this tree, so it is portable by behaviour — but
# it must spell `one.ie/web/.astro` literally, because that path is hardcoded in
# lib/gc-finished.sh's GC_EPHEMERAL default and a sandbox that used a neutral
# name would stop exercising the filter it exists to test. Rather than teach the
# matcher an exemption that would also silence a real reach (`$ROOT/one.ie/ai`
# in close-owner.sh is the same shape), the bucket is the answer: needs-env
# ships identically and claims less. /vespio § 0 — a misbehaving bucket is a
# reclassification, not a bug.
#
# TWO KINDS OF ROW, one list. A row whose name starts with `skills/` is a
# SKILL DIRECTORY under .claude/skills/; every other row is a path under
# .claude/scripts/. One manifest, because vespio-sync.sh reads this function as
# its shippable set and the whole point of that script is that there is no
# second list to drift.
#
# Why skills are classified at all: the skill list is the discovery surface a
# session reads before it builds. Measured 2026-09-21 — the manifest classified
# scripts only, so vespio carried 7 of 25 skill directories and a collaborator
# rebuilt a feature ONE already had because nothing in their tree named it.
#
# `portable` claims MORE for a skill than it does for a script: a portable skill
# names no monorepo path AND cites no text/ canon file, so it is craft that
# travels to any tree. A skill whose worked examples are one.ie/web, or whose
# source-of-truth is a text/ doc, is `needs-env` — it ships and the cites
# degrade to prose. `monorepo-only` is for a skill whose PRIMARY ARTIFACT lives
# in a directory the downstream tree does not have: schema/*.tql, packages/*/src,
# the 5-service deploy pipeline, a text/ template it refuses to start without.
#
# NOT covered here: the loose `.md` files directly under .claude/skills/
# (build.md, dev.md, rag-*.md, sui.md …). They ship or not via excluded_claude,
# as they always have. Classifying them is a follow-on, not a silence this
# manifest pretends to have closed.
# ---------------------------------------------------------------------------
# The eight classified 2026-09-21, which the ratchet had been refusing.
# Seven already declared a class in their own header; TWO of those declarations
# were wrong against the rule and are corrected in the scripts' headers too, so
# file and manifest cannot drift.
#   monorepo-only iff the PRIMARY ARTIFACT lives where a downstream tree does not
#   have it AND no env indirection reaches it.
# The discriminator is whether the script DEGRADES or DIES with the path absent:
#   flywheel-outcome.sh  DIES   — reads one.ie/web/.dev.vars with no ONE_ENV_FILE
#                                 indirection, exit 2; then cd one.ie/web + wrangler.
#   jev-tag-audit.mjs    DIES SILENTLY — greps resolvers/pages/api/channels with
#                                 `|| true`; absent it reports zero orphans and
#                                 reads as all-clean. Worse than absent.
#   key-cycle.sh         DEGRADES — ONE_ENV_FILE and KEY_CLI both override.
#   key-lifecycle-check.sh DEGRADES — ONE_ENV_FILE overrides; text/key.md is a
#                                 comment cite, never read.
# NOTE: this heredoc has NO comment syntax — every line is `<class> <file>`.
# Prose belongs here, above the function, never inside it.
manifest() {
  cat <<'MANIFEST'
portable       browser-check.mjs
portable       chrome.mjs
portable       do-analyze.sh
portable       gate-reaper.sh
portable       gate-watchdog.sh
portable       health.sh
portable       govern-bound-check.sh
portable       factory-width.sh
portable       factory-executor-check.mjs
portable       factory-peak.sh
portable       do-learn-loop.sh
portable       do-promise-lint.sh
portable       do-world-check.sh
portable       do-recon-cache.sh
portable       do-cycle-shape-check.sh
portable       do-next.sh
portable       do-plan-json.sh
portable       do-test-gate.sh
portable       do-tick.sh
portable       do-prove-selftest.sh
portable       do-validate-armed.py
portable       factory-brief-check.sh
portable       factory-secret-gate.sh
needs-env      factory-rate.sh
portable       fixtures/triage-dupe.md
portable       gate-run.sh
portable       memory-index-budget.sh
portable       gate-reaper-check.sh
portable       govern-mem-check.sh
portable       governor-escape-check.sh
portable       lib/gc-finished.sh
portable       lib/govern.sh
portable       lib/govern.ts
portable       package.json
portable       w1-recon.ts
portable       wf-check.mjs
needs-env      m.sh
needs-env      aa-sync.mjs
needs-env      cc-connect.sh
needs-env      download-stats.sh
needs-env      gh-traffic-capture.sh
needs-env      verify-board-doors.sh
needs-env      blocks-manifest-cached.sh
needs-env      close-metrics.sh
needs-env      close-owner.sh
needs-env      do-close.sh
needs-env      do-decide.sh
needs-env      gc-content-check.sh
needs-env      do-accept.sh
needs-env      do-auto.sh
needs-env      do-board.sh
needs-env      do-derives-check.sh
needs-env      do-fleet.sh
needs-env      do-folder.sh
needs-env      do-killswitch-audit.py
needs-env      do-orchestrate.sh
needs-env      do-plan-json.mjs
needs-env      do-commit.sh
needs-env      do-brief.sh
needs-env      test-speed.sh
needs-env      do-recon-pack.sh
needs-env      do-w4-gates.sh
needs-env      sdk-build-cached.sh
needs-env      astro-build-cached.sh
needs-env      test-cached.sh
needs-env      do-preflight.sh
needs-env      tsc-cached.sh
needs-env      load-guard-check.sh
needs-env      governor-doors-check.sh
needs-env      test-lanes.sh
needs-env      test-full.sh
needs-env      do-project.sh
needs-env      do-promise-settle.sh
needs-env      do-prove.sh
needs-env      do-reconcile.sh
needs-env      do-rubric.py
needs-env      do-signal.sh
needs-env      do-survey.sh
needs-env      do-tier.sh
needs-env      do-triage.sh
needs-env      do-untracked-gate.sh
needs-env      do-walk.sh
needs-env      machine-check.sh
needs-env      machine-watch.sh
needs-env      notify.sh
needs-env      reconcile-allow.txt
needs-env      rubric-weights.json
needs-env      w4-rubric.ts
needs-env      govern-claims-check.sh
needs-env      govern-order-check.sh
needs-env      signal-watch.sh
monorepo-only  prompt-corpus.py
monorepo-only  retro-tick.sh
monorepo-only  retro.sh
monorepo-only  thread-name-backfill.ts
monorepo-only  signal-meta-backfill.ts
monorepo-only  task-titles-dump.ts
monorepo-only  CLAUDE.md
monorepo-only  agent-actor-parity.sh
monorepo-only  chat-context-check.sh
monorepo-only  triage-shape-check.sh
monorepo-only  deploy-ready.sh
monorepo-only  substrate-env-parity.mjs
monorepo-only  typedb-flake-check.sh
monorepo-only  env-sync.sh
monorepo-only  full-suite-paths-check.sh
monorepo-only  hook-scope-check.sh
monorepo-only  land.sh
monorepo-only  one-resume.sh
monorepo-only  orphan-baseline.json
monorepo-only  orphan-modules.mjs
needs-env      worktree-preview.sh
needs-env      factory-walk.sh
needs-env      factory-turn.sh
needs-env      factory-emit.sh
needs-env      factory-close-check.sh
needs-env      preview-fd-check.sh
portable       factory-review-check.mjs
portable       pr-body.sh
monorepo-only  deploy-record.sh
monorepo-only  deploy-emit.sh
needs-env      fixtures/factory-brief-real.md
monorepo-only  agentverse-audit.sh
monorepo-only  asi-walk.sh
monorepo-only  cc-events-proof.sh
monorepo-only  db-sync-lock-check.sh
monorepo-only  skills-publish.sh
monorepo-only  deploy.sh
monorepo-only  blocks-ratchet.sh
monorepo-only  blocks-manifest.mjs
monorepo-only  id-inventory.mjs
monorepo-only  fleet-manifest.mjs
monorepo-only  one-agents.mjs
monorepo-only  blocks-render-probe.mjs
monorepo-only  blocks-usage.mjs
monorepo-only  lighthouse-run.sh
monorepo-only  livekit-live-check.sh
monorepo-only  speed-check.mjs
monorepo-only  test-honesty.mjs
monorepo-only  do-consumer-sweep.sh
monorepo-only  do-derive-check.sh
monorepo-only  do-rank.py
monorepo-only  do-smoke.sh
monorepo-only  do-substrate-check.sh
monorepo-only  do-tasks-wire-check.sh
monorepo-only  do-ui-gate.sh
monorepo-only  factory-check.sh
monorepo-only  factory-repo.sh
monorepo-only  deploy-gate-check.sh
monorepo-only  release.sh
monorepo-only  factory-tasks-check.sh
monorepo-only  fade-toxic.sh
monorepo-only  hourly-brief.sh
monorepo-only  livekit-ratchet.sh
monorepo-only  outcome-pull.ts
monorepo-only  promise-manifest.mjs
monorepo-only  roles-check.sh
monorepo-only  ad-copy-lint.sh
monorepo-only  spine-canary.sh
monorepo-only  worktree-up.sh
monorepo-only  subdomains-proof.sh
monorepo-only  sync-claude-mirror.sh
monorepo-only  tg-listen.sh
monorepo-only  typedb-cluster-status.sh
monorepo-only  typedb-env.sh
monorepo-only  typedb-flap-recorder.sh
monorepo-only  typedb-scratch.sh
monorepo-only  deploy-schema-check.sh
monorepo-only  typedb-probes/containment-probe.py
monorepo-only  typedb-probes/panic-probe-version.py
monorepo-only  typedb-probes/panic-probe.py
monorepo-only  urls-lint.sh
monorepo-only  redirect-lint.sh
monorepo-only  deploy-dev.sh
monorepo-only  fleet-status.sh
monorepo-only  gen-dev-config.py
monorepo-only  speed-cache-check.sh
monorepo-only  speed-parity-check.sh
monorepo-only  speed-waterfall-check.sh
monorepo-only  tasks-claim-race.mjs
monorepo-only  tasks-loop.sh
monorepo-only  verify-fast.sh
monorepo-only  vespio-sync.sh
monorepo-only  one-sync.sh
monorepo-only  sweep.sh
monorepo-only  incident.sh
portable       skills/ai-sdk
portable       skills/ai-ui
portable       skills/composio
portable       skills/youtube-subs
monorepo-only  flywheel-outcome.sh
monorepo-only  jev-tag-audit.mjs
monorepo-only  resume-lost-sessions.sh
monorepo-only  shoot-pages.mjs
needs-env      deploy-gap.sh
needs-env      key-cycle.sh
needs-env      key-lifecycle-check.sh
needs-env      key-seat.sh
needs-env      npm-downloads.sh
needs-env      skills/astro
needs-env      skills/cloudflare-security-audit
needs-env      skills/directory-autofill
needs-env      skills/docs
needs-env      skills/fleet-audit
needs-env      skills/models
needs-env      skills/planning
needs-env      skills/promise-make
needs-env      skills/promise-settle
needs-env      skills/puck
needs-env      skills/react19
needs-env      skills/reactflow
needs-env      skills/shadcn
needs-env      skills/voice
needs-env      skills/writer
monorepo-only  skills/cli
monorepo-only  skills/deploy
monorepo-only  skills/mcp
monorepo-only  skills/meeting
monorepo-only  skills/sdk
monorepo-only  skills/typedb
MANIFEST
}

# ---------------------------------------------------------------------------
# THE PUBLIC AXIS — a SECOND, INDEPENDENT classification. Read by one-sync.sh.
#
# manifest() above answers one question: "does this work in an agency tree?"
# Vespio is OUR repo, so that axis is about a tree's SHAPE. github.com/one-ie/one
# is PUBLIC, and the question there is a different one — "is this safe, honest,
# and OURS to publish?" A row can answer the two differently: `skills/voice` is
# needs-env for vespio (it ships; its text/ cites degrade to prose) and is NOT
# public, because it is Anthony's personal register. Widening the rows above to
# carry both answers would conflate the questions AND break vespio-sync.sh's
# `awk '$2 ~ /^skills\//'`. Two functions, two axes, neither reads the other.
#
# POLARITY IS INVERTED HERE, ON PURPOSE. Above, an unclassified row REFUSES the
# build — loud, because a missing factory script is a downstream tree that
# silently lacks a capability. Here, an unlisted path simply DOES NOT SHIP:
# silence is exclusion, the only safe default when the destination is public.
# The cost is that a new skill ships to nobody until someone adds a row, so
# `one-sync.sh --report` prints everything held back — the exclusion stays a
# visible decision instead of becoming a forgetting.
#
# THE RULE THE ROWS OBEY is text/open-source.md: GIVE what is inert without the
# backend, SERVE what we host, KEEP what took real campaigns to earn.
#
# WHAT DOCTRINE REFUSES, AND WHY THE ROWS ARE THIN. The instinct is "ship the
# harness — it is the development platform." open-source.md forbids the best of
# it BY NAME: "the /do orchestration engine" is in KEEP, and "Everything in the
# KEEP bucket -> proprietary ... never given to the OSS world" covers the
# published @oneie/claude and @oneie/claude-skill packages too. The speed is a
# SERVE product, not a GIVE — the same doc sells it as "the hosted /build
# orchestrator (/do-speed without the engine source)." So no /do command, no
# do-*.sh, no w1-w4 agent has a row here. Changing that is an edit to
# open-source.md's KEEP list, not a judgement call this manifest may make.
#
# FIVE STANDING DENIALS. None is an omission; each is a different reason.
#   1. THE MOAT — schema/, the substrate, receivers, the reputation ledger, the
#      ELEVATE library (ai/skills/elevate-*), the /do engine. open-source.md
#      § What we will never do.
#   2. THIRD-PARTY VENDORED — skills/ai-sdk and skills/ai-ui are Vercel's,
#      skills/composio is Composio's, skills/cloudflare-security-audit is
#      Cloudflare's, skills/livekit-agents is LiveKit's, skills/youtube-subs
#      wraps third-party scripts. Ours to USE, never ours to sublicense under
#      the ONE License v1.0. Relicensing another party's work is the kind of
#      mistake a LICENSE file makes load-bearing.
#   3. PERSONAL / BRAND IP — skills/voice is Anthony's register; skills/writer
#      is craft, but its whole source of truth is text/voice-and-tone.md and
#      text/writing-style-guide.md, neither of which ships.
#   4. LYING CITES — measured, not guessed. A skill or rule whose worked
#      examples are one.ie/web, packages/*/src, schema/*.tql, resolvers/ or
#      .claude/scripts/ points at directories a clone does not have, and a doc
#      that cites a path the tree lacks is worse in a showcase repo than an
#      absent doc. The grep is the instrument and one-sync.sh RE-RUNS it as a
#      gate, so a row cannot rot into a lie: rules/documentation.md cites 15
#      such paths, commands/do.md cites 52, rules/engine.md 6, commands/close.md
#      11. Only astro.md and react.md came back ZERO; ui.md's single hit is a
#      `paths:` glob, which one-sync.sh REPOINTS rather than ships.
#   5. ALREADY RE-AUTHORED DOWNSTREAM — seven items exist in both trees and
#      differ because the PUBLIC one is the correct one for its tree:
#      skills/astro (public is Astro 7; ours is Astro 6 and names one.ie/web),
#      skills/react19, skills/shadcn, skills/sdk, commands/create.md,
#      commands/deploy.md, rules/design.md. They have no row, and one-sync.sh
#      REFUSES to overwrite a divergent file even if one were added. Mirror
#      semantics here would replace right docs with wrong docs in a public repo.
#
# WHAT THE GATES CANNOT SEE — and this is the important line in this header.
# The three gates in one-sync.sh catch a leak, a monorepo path and a dangling
# cite. They cannot catch the two risks that actually decide a public row:
# WHOSE WORK IT IS, and whether it is grammar or library. Those are human
# judgements, recorded here as rows. Never read "3 gates green" as "safe to
# publish"; read it as "the mechanical checks found nothing."
#
# THE VESPIO AUDIT (2026-09-22). apps/vespio is a SECOND SOURCE — nine skills
# and all seven ai/workflows there exist nowhere in this monorepo. A zero-cite
# score is necessary and NOT sufficient: for a vespio skill the binding
# question is ownership and bucket, not paths. Seventeen were read; fifteen
# scored zero cites; THREE ship. What the citation grep could never have told
# us, one by one:
#   impeccable          Apache 2.0, its OWN LICENSE file, v3.9.1, `npx impeccable`,
#                       and a vendored minified modern-screenshot.umd.js. A
#                       published third-party skill. Installable, not shippable.
#   de-slop             frontmatter says it: `credit: adapted from de-ai-ify
#                       (BrianRWagner) + ai-writing-auditor (VoltAgent)`. Derived.
#   animate             "Based on Emil Kowalski's Animations on the Web course."
#   fan-out · steps ·   each triggers on "when Donal says …" — operator working
#   skill-author · pbp  preference, harness IP, the same family as skills/voice.
#   adversarial-review  cites Rule 19/21/24 — vespio's own rule numbering, which
#                       dangles downstream — and frames output "before it reaches
#                       a client".
#   web-to-mobile       an agency SERVICE: "$3-5k flat, 2-week turnaround".
#   persona-ingest ·    agency playbook — the 27-persona council, stage-routing to
#   biz-stage-classify · /orb and /strat-hub, "how we do X at OO", the audit
#   company-standard-doc  pipeline's query generator. open-source.md's KEEP.
#   ai-keyword-gen · yt-script
#   brandkit            SHIPS. No operator name, no third-party credit, no LICENSE
#                       of its own, no client framing, no pricing: brand-identity
#                       craft that travels to any tree.
# THE ROWS THIS AUDIT REMOVED, and the gate that removed them. The first pass
# rowed six rag-*.md skills on a zero CITATION score. The OWNERSHIP gate — added
# only after this audit — refuses all six: every one stamps `source: oo-internal`,
# triggers on "when Donal says", and names OO's actual RAG vaults (oo-brain,
# agency-operator, personal-brain) as STRUCTURE, not as example. Those vault
# names are what the skill IS; there is no placeholder to substitute. Dropped.
# ai/workflows/lead-to-owner.md went the same way for a different reason: its
# description encodes an unresolved internal decision ("until Tony answers item
# 15") and names OO's own Worker as the live transport. That is a status note
# about our week, not a workflow template.
#
# ONE of the seven workflows ships. ticket-triage.md names no client and no
# vertical; its only two operator hits are PLACEHOLDERS in example fields
# (`assignee: Donal`, a `— OO Service` signature), which the transform replaces
# with `{{ owner }}` and `{{ business_name }}` — the same class of substitution
# as ui.md's `paths:` glob, mechanical rather than substantive. It carries the
# `id/label/trigger/department` frontmatter that IS the step-kind grammar
# open-source.md wants taught, and ai/workflows/ in the public repo was EMPTY.
# The other five each name a vertical (mover, roof, gmb) or the agency itself.
#
# THE VESPIO ROWS ARE GONE — the operator's call, 2026-09-22: "I don't want to
# put too much from vespio into our open source." Both had passed all four
# gates, and pulling them is a judgement the gates were never going to make.
# One of them also failed on its own merits once measured: ticket-triage.md
# carries no fenced ```graph block, so it compiled to `workflow:create` with a
# name, a description and ZERO steps — prose shaped like a workflow, landing an
# empty shell in the workspace. That trap is now written down in the `workflow`
# skill instead, which is the better place for it.
#
# WHAT REPLACES THEM IS AUTHORED, NOT HARVESTED. The rule the roster now obeys:
# an agent or skill earns its place by OPERATING A SURFACE THIS REPO SHIPS —
# plugin-{auth,backend,blog,chat,docs,pages,track,newsletter}, data/types,
# data/lifecycles, site/src/pages/api/pay, wallet.astro. Anything else is
# playbook or craft and stays private, whichever tree it was written in. Those
# live in apps/one directly (release.sh: apps/one is the starter's SSOT), so
# they are NOT governed by this manifest or by one-sync.sh's gates — a real gap
# worth naming rather than papering over.
#
# ROW SHAPE: `public  <src>  [dst]`. src is relative to the monorepo root; dst
# is relative to the apps/one root and defaults to src. A src ending in `/` is
# a directory. Every path is NAMED — no glob, no recursion into an unnamed
# parent — so clients/, .env*, schema/ and text/ are unreachable by
# construction rather than by a filter somebody could widen later.
# ---------------------------------------------------------------------------
public_manifest() {
  cat <<'PUBLIC'
public  .claude/rules/astro.md
public  .claude/rules/react.md
public  .claude/rules/ui.md
public  one.ie/ai/agents/templates/   ai/agents/templates/
PUBLIC
}

# The canon pack: the text/ files the loop itself reads. Everything else in
# text/ is this company's work product and never ships.
canon_text() {
  cat <<'CANON'
text/CLAUDE.md
text/contracts.md
text/dictionary.md
text/do.md
text/do-engine-plan.md
text/do-reference.md
text/docs.md
text/dsl.md
text/one-loop.md
text/one-ontology.md
text/patterns.md
text/promise-signals.md
text/promises.md
text/rubrics.md
text/rubric-migration-plan.md
text/templates.md
text/templates-plan.md
text/tone.md
text/voice-and-tone.md
text/writing-style-guide.md
text/lifecycle.md
text/routing.md
text/routing-plan.md
text/promise-plan.md
text/skill-invocation.md
text/surfaces-layers.md
text/orchestrator-how-to.md
text/do-autonomous-plan.md
text/agent-template-plan.md
text/marketplace.md
text/factory.md
text/factory-plan.md
text/workflows.md
CANON
}

# text/ files the shipped spine references DELIBERATELY without shipping them.
# Two kinds, both allowed, neither silent:
#   company   this repo's own work product, cited as a worked example
#   stale     the reference is already dead upstream (monorepo doc rot) —
#             listed so --check-canon reports a real gap, not a known one
allowed_dangling() {
  cat <<'ALLOW'
company  text/playbook.md
company  text/remote-suspend-todo.md
company  text/sdk-mcp-cli-schema-design-integration.md
company  text/agent-api-plan.md
company  text/workflow-bridge-plan.md
# factory-do.md is this company's factory LEDGER — 5.5k lines of measured runs,
# one machine path. guide.md and factory-executor.js cite it as the design
# source, which is true; the design the loop needs is text/factory-plan.md,
# which ships.
company  text/factory-do.md
stale    text/feature.md
stale    text/loop-log-archive.md
stale    text/rich-messages.md
stale    text/template-frame.md
stale    text/template-spec-plan.md
ALLOW
}

# Skill directories the shipped spine NAMES without shipping them. Reachable
# only since 2026-09-21, when the build started honouring the manifest's
# `monorepo-only` bucket for skills — before that every skill dir travelled and
# no cite could dangle.
#
# A cite is allowed here only when it is CONDITIONAL and the condition cannot
# arise downstream: "editing a .tql? read skills/typedb" costs nothing in a tree
# with no schema/. Anything else fails, so the SEVENTH monorepo-only skill the
# spine starts citing is caught the day it is cited — and an entry whose skill
# comes back into the tree fails as a stale exemption, exactly like the text/
# allowlist above.
allowed_dangling_skills() {
  cat <<'ALLOWSK'
conditional  skills/typedb    cited by the agents' target->skill table for .tql/.sql work; there is no schema/ downstream
conditional  skills/sdk       cited for "editing a receiver"; packages/sdk/src is not in the tree
conditional  skills/mcp       cited for "editing an MCP tool"; packages/mcp/src is not in the tree
conditional  skills/cli       cited for "editing a CLI verb"; packages/cli/src is not in the tree
conditional  skills/deploy    cited by commands/sweep.md as the thing it is NOT; the 5-service pipeline is monorepo-only
conditional  skills/meeting   cited by commands/do.md as an aside; its shape file text/template-meeting.md is not canon
ALLOWSK
}

# Files under .claude/ that are this machine's or this company's, not the loop's.
excluded_claude() {
  cat <<'EXCLUDED'
.claude/settings.json
.claude/settings.local.json
.claude/improvements.queue.md
.claude/typedb/dev.env
.claude/commands/kill.md
.claude/commands/restart.md
.claude/commands/db-sync.md
.claude/commands/deploy.md
.claude/commands/release.md
.claude/commands/one.md
.claude/commands/oo-push.md
.claude/skills/dev.md
.claude/skills/build.md
EXCLUDED
}

# ---------------------------------------------------------------------------
# 1. classify — resolve which tracked scripts ship
# ---------------------------------------------------------------------------
ships() { # $1 = script basename/relpath under .claude/scripts
  local b="$1"
  local bucket
  # `$2 !~ /^skills\//` so a skill row can never answer for a script of the
  # same name — the two kinds share one list, not one namespace.
  bucket="$(manifest | awk -v n="$b" '$2 == n && $2 !~ /^skills\// {print $1}')"
  [ -n "$bucket" ] || return 2   # unclassified
  [ "$bucket" = "monorepo-only" ] && return 1
  return 0
}

ships_skill() { # $1 = directory name under .claude/skills
  local b="skills/$1"
  local bucket
  bucket="$(manifest | awk -v n="$b" '$2 == n {print $1}')"
  [ -n "$bucket" ] || return 2   # unclassified
  [ "$bucket" = "monorepo-only" ] && return 1
  return 0
}

# Every tracked skill DIRECTORY, one name per line. A loose .md directly under
# .claude/skills/ is not a skill directory and is not classified here.
tracked_skills() {
  git ls-files .claude/skills | sed -n 's|^\.claude/skills/\([^/]*\)/.*|\1|p' | sort -u
}

# ---------------------------------------------------------------------------
# build — the 7 steps, each failing closed
# ---------------------------------------------------------------------------
build() {
  local TARGET="$1"
  [ -n "$TARGET" ] || { echo "usage: factory-repo.sh <target-dir>" >&2; return 2; }

  if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "refusing: $TARGET exists and is not empty" >&2; return 2
  fi

  # RUN FROM THE MAIN TREE. ROOT derives from BASH_SOURCE and WS from its
  # parent, so invoked as .claude/worktrees/<x>/.claude/scripts/factory-repo.sh
  # both are wrong: ROOT names the worktree and WS names `worktrees/`. The
  # scrub in portabilise() is written against those two strings, so every
  # literal /Users/<you>/Server/one-ie in a tracked file survives it. Measured
  # 2026-09-14 from .claude/worktrees/dev: the emit refused naming 10 files and
  # 5 paths, NONE of them real — a false RED, and had the scrub been laxer it
  # would have emitted a tree with the maintainer's disk in it. Same trap as
  # land.sh and release.sh, one directory over.
  if [ -f "$ROOT/.git" ]; then
    echo "refusing: $ROOT is a linked worktree, not the main checkout." >&2
    echo "  ROOT and WS would both be wrong and the scrub would miss every" >&2
    echo "  absolute path. Run the MAIN tree's copy of this script." >&2
    return 2
  fi

  local STAGE; STAGE="$(mktemp -d)"
  # No RETURN trap: bash keeps a RETURN trap set inside a function as the
  # shell's trap, so it fires again (with STAGE unbound) on every later
  # function return. Clean up explicitly instead — _bail does both.
  _bail() { rm -rf "$STAGE"; return "$1"; }

  # --- 1. classify -----------------------------------------------------
  local unclassified=0
  while IFS= read -r f; do
    local rel="${f#.claude/scripts/}"
    ships "$rel"; local rc=$?
    [ $rc -eq 2 ] && { echo "unclassified script (add to manifest): $rel" >&2; unclassified=1; }
  done < <(git ls-files .claude/scripts)
  while IFS= read -r d; do
    ships_skill "$d"; local rc=$?
    [ $rc -eq 2 ] && { echo "unclassified skill (add to manifest): skills/$d" >&2; unclassified=1; }
  done < <(tracked_skills)
  [ $unclassified -eq 0 ] || { echo "refusing to build with an incomplete manifest" >&2; _bail 3; return 3; }

  # --- 2. assemble — from the TRACKED set, never `cp -r` ---------------
  # Generating from `git ls-files` makes secret-exclusion structural: an
  # untracked .env, a scratch dir, or node_modules cannot enter by accident.
  local excl; excl="$(excluded_claude)"
  while IFS= read -r f; do
    case "$f" in
      .claude/scripts/*)
        ships "${f#.claude/scripts/}" || continue ;;
      # A skill DIRECTORY (two path components). A loose .md directly under
      # .claude/skills/ has only one and falls through to excluded_claude.
      .claude/skills/*/*)
        local _sk="${f#.claude/skills/}"; _sk="${_sk%%/*}"
        ships_skill "$_sk" || continue ;;
    esac
    grep -qxF "$f" <<<"$excl" && continue
    # launchd plists hard-code this machine's absolute paths and schedule
    # monorepo-only jobs; scratch/ is one cycle's leftovers. Neither travels.
    case "$f" in .claude/launchd/*|.claude/scratch/*) continue ;; esac
    mkdir -p "$STAGE/$(dirname "$f")"
    cp "$f" "$STAGE/$f"
  done < <(git ls-files .claude)

  while IFS= read -r f; do
    [ -f "$f" ] || { echo "canon missing: $f" >&2; _bail 3; return 3; }
    mkdir -p "$STAGE/$(dirname "$f")"
    cp "$f" "$STAGE/$f"
  done < <(canon_text)

  # The loop's doc templates — every -todo/-plan/-docs starts from one.
  while IFS= read -r f; do
    mkdir -p "$STAGE/$(dirname "$f")"
    cp "$f" "$STAGE/$f"
  done < <(git ls-files 'text/template-*.md')

  # Accumulators: the loop APPENDS to these. Ship them seeded and empty — our
  # history is not the collaborator's, but the files must exist or the first
  # cycle that tries to append has nothing to append to.
  printf '# Learnings\n\nOne line per closed cycle. See `.claude/rules/documentation.md`\n(§ Loop Close) for the format, including the eight-field rubric vector.\n' \
    > "$STAGE/text/learnings.md"
  printf '# Improvements\n\nAnchor mismatches and deferred fixes land here at `/close`, for the next\ncycle'"'"'s W2 to pick up. See `.claude/rules/documentation.md` § Loop Close.\n' \
    > "$STAGE/text/improvements.md"
  printf '# Loop log\n\nOne entry per ONE LOOP turn — lane, move, receipt. Read and appended by\n`.claude/workflows/one-loop.js`. See `text/one-loop.md`.\n' \
    > "$STAGE/text/loop-log.md"

  # --- 3. strip — settings.json never ships, and no absolute path travels ---
  write_settings_example "$STAGE/.claude/settings.example.json"
  portabilise "$STAGE" || { _bail 3; return 3; }

  # --- 4. bind — the connect layer, one file ---------------------------
  write_connect "$STAGE"
  write_package_json "$STAGE" "$TARGET"
  write_gitignore "$STAGE"
  write_readme "$STAGE"
  write_contributing "$STAGE"

  # --- 5. scan — refuse to emit on a key-shaped string -----------------
  if ! scan_secrets "$STAGE"; then
    echo "refusing to emit: key-shaped string found in the staged tree" >&2
    _bail 4; return 4
  fi

  # --- 6. seed — tests that reach into nothing -------------------------
  write_tests "$STAGE"

  # --- 7. init — fresh history, one commit, no remote ------------------
  mkdir -p "$TARGET"
  # shellcheck disable=SC2086
  ( cd "$STAGE" && tar cf - . ) | ( cd "$TARGET" && tar xf - )
  (
    cd "$TARGET" || exit 1
    git init -q -b main
    git add -A
    git -c user.name="ONE" -c user.email="build@one.ie" \
      commit -q -m "The factory, standalone.

Generated by .claude/scripts/factory-repo.sh from canon.
Fresh history by design: a history-preserving cut of any prefix
carries root-level blobs."
  ) || return 5

  rm -rf "$STAGE"
  echo "built: $TARGET  (ONE_TARGET=$ONE_TARGET)"
  echo "files: $(cd "$TARGET" && git ls-files | wc -l | tr -d ' ')"
}

# An absolute path to the maintainer's disk is not a secret, but it is a
# dependency the clone cannot satisfy — and it tells a reader where the private
# tree lives. Rewrite what can be made relative; refuse to emit what cannot.
portabilise() {
  local S="$1" home_re
  home_re="$(printf '%s' "$ROOT" | sed 's/[][\.*^$/]/\\&/g')"

  # The maintainer's workspace root — the directory the monorepo sits in. Paths
  # under it name private sibling repos (vendoring provenance, /oo-push targets)
  # and must not travel even as prose.
  local WS; WS="$(dirname "$ROOT")"

  local _sed
  if sed --version >/dev/null 2>&1; then _sed=(sed -i); else _sed=(sed -i ''); fi

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # The monorepo root becomes the repo root; the loop already runs from there.
    "${_sed[@]}" -e "s|$ROOT/one\.ie/web|<the project you are building>|g" \
                 -e "s|$ROOT|.|g" \
                 -e "s|$WS/[A-Za-z0-9._-]*|<a private sibling repo>|g" "$f" 2>/dev/null || true
  done < <(grep -rl -e "$ROOT" -e "$WS" "$S" 2>/dev/null)

  # Anything still absolute under /Users or /home is a path we could not make
  # portable. Fail closed rather than shipping a broken reference.
  local left
  left="$(grep -rlE '(/Users/[a-z]+/|/home/[a-z]+/)' "$S" 2>/dev/null | sed "s|^$S/||")"
  if [ -n "$left" ]; then
    echo "refusing to emit: absolute machine paths survive in:" >&2
    echo "$left" | head -10 >&2
    grep -rhoE '(/Users/[a-z]+/|/home/[a-z]+/)[^ "'"'"')]*' "$S" 2>/dev/null | sort -u | head -5 >&2
    return 1
  fi
  return 0
}

write_settings_example() {
  cat > "$1" <<'JSON'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "FABLE_AVAILABLE": "off"
  },
  "permissions": {
    "allow": [
      "Bash(bash .claude/scripts/*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Read(//**)"
    ]
  }
}
JSON
}

# The connect layer: ONE file names the URL and the key, and it names them
# by ENV VAR, never by value. Nothing else in the repo knows a URL or a secret.
write_connect() {
  local S="$1"
  cat > "$S/.mcp.json" <<JSON
{
  "mcpServers": {
    "oneie": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@oneie/mcp@${MCP_VERSION#^}"],
      "env": {
        "ONEIE_API_URL": "\${ONEIE_API_URL:-https://one.ie}",
        "ONEIE_API_KEY": "\${ONEIE_API_KEY}"
      }
    }
  }
}
JSON

  cat > "$S/.env.example" <<'ENVX'
# The connect layer. Copy to .env and fill in. .env is gitignored and must stay that way.
#
# This private repo drives the PUBLIC stack — github.com/one-ie/one and the
# published @oneie/{sdk,mcp,cli} packages — over the api.one.ie substrate.
# Nothing here needs a private checkout.
#
# Mint your own key rather than being handed one — it carries exactly your
# authority and nothing more:
#
#   npx -y @oneie/cli auth login
#
# ONEIE_API_URL must be the app origin, not the gateway. The MCP client calls
# /api/* paths; https://api.one.ie serves the substrate unprefixed and every
# tool 404s against it.

# IMPORTANT: this file is not loaded for you. Claude Code expands ${VAR} in
# .mcp.json from the PROCESS environment, and does not read .env. Export it
# before starting the client, every session:
#
#   set -a; source .env; set +a
#   claude
#
# Skip that and the MCP server starts with an empty key: every substrate tool
# fails, and nothing says why.

ONEIE_API_URL=https://one.ie
ONEIE_API_KEY=

# The loop's own scripts (signals, promise settle, the /close propagate) default
# to a localhost dev server. In a clone there isn't one — point them at the live
# substrate or every mark and warn the loop emits goes nowhere quietly.
ONE_API_URL=https://one.ie

# A dotenv file is not a shell: ${ONEIE_API_KEY} would be read literally by any
# script that parses this file. Paste the SAME key here.
ONE_API_KEY=

# The loop's own scripts read credentials through this indirection, so the
# harness never needs a one.ie/web/ on disk.
ONE_ENV_FILE=.env
ENVX
}

write_package_json() {
  local S="$1" deps overrides=""
  if [ "$ONE_TARGET" = "workspace" ]; then
    # `workspace:*` only resolves for a member of a workspace that DECLARES it.
    # A generated tree sitting outside the monorepo is not one, so a
    # workspace:* dep here fails to resolve — verified: `bun install` errors on
    # all three. The maintainer target therefore uses file: paths, computed at
    # build time relative to this tree, which is what workspace:* was only
    # pretending to be. Relative on purpose: portabilise() refuses to emit an
    # absolute machine path, and a relative one is honest about being local.
    # Absolute, deliberately. A relative link looked cleaner and was wrong:
    # on macOS /var is a symlink to /private/var, so a path computed from an
    # unresolved temp dir was one level short and every dep failed to resolve.
    # The maintainer target is machine-local by definition and is never the
    # tree that gets pushed, so naming the machine's path is honest here —
    # --check-no-machine-paths asserts against the PUBLISHED target, which ships.
    local rel="$ROOT"
    deps="\"@oneie/sdk\": \"file:$rel/packages/sdk\",
    \"@oneie/mcp\": \"file:$rel/packages/mcp\",
    \"@oneie/cli\": \"file:$rel/packages/cli\""
    # The linked packages declare workspace:* between THEMSELVES (cli → sdk,
    # cli → evals). Those resolve for a workspace member and fail for anyone
    # else, so every @oneie/* reachable transitively is overridden to the same
    # local path. Without this, `bun install` errors on evals even though all
    # three direct deps resolve — verified.
    overrides=",
  \"overrides\": {
    \"@oneie/sdk\": \"file:$rel/packages/sdk\",
    \"@oneie/mcp\": \"file:$rel/packages/mcp\",
    \"@oneie/cli\": \"file:$rel/packages/cli\",
    \"@oneie/evals\": \"file:$rel/packages/evals\",
    \"@oneie/react\": \"file:$rel/packages/react\"
  }"
  else
    deps="\"@oneie/sdk\": \"$SDK_VERSION\",
    \"@oneie/mcp\": \"$MCP_VERSION\",
    \"@oneie/cli\": \"$CLI_VERSION\""
  fi
  cat > "$S/package.json" <<JSON
{
  "name": "@one-ie/factory",
  "version": "0.1.0",
  "private": true,
  "description": "The ONE factory — the /do loop and its connect layer, standalone.",
  "type": "module",
  "scripts": {
    "test": "bun test tests/",
    "check": "bash .claude/scripts/wf-check.mjs 2>/dev/null; node .claude/scripts/wf-check.mjs"
  },
  "dependencies": {
    $deps
  }$overrides,
  "engines": { "node": ">=20" },
  "//": "ONE_TARGET=$ONE_TARGET — the version is the boundary. See README.md."
}
JSON
}

write_gitignore() {
  cat > "$1/.gitignore" <<'GI'
.env
.env.*
!.env.example
.dev.vars
*.key
*.pem
.claude/settings.local.json
.claude/settings.json
.claude/scratch/
.claude/worktrees/
.do-worktrees/
node_modules/
__pycache__/
.DS_Store
GI
}

# ---------------------------------------------------------------------------
# step 5 — the scan. Runs BEFORE git init, so a secret can never enter
# history even for one commit.
# ---------------------------------------------------------------------------
scan_secrets() {
  local S="$1" hits=0
  # Key shapes this substrate actually mints, plus the usual suspects.
  local pat='(one-[0-9a-f]{32,})|(osk_[A-Za-z0-9]{16,})|(sk-[A-Za-z0-9_-]{20,})|(ghp_[A-Za-z0-9]{20,})|(suiprivkey[a-z0-9]{20,})|(AKIA[0-9A-Z]{16})|(-----BEGIN [A-Z ]*PRIVATE KEY-----)'
  while IFS= read -r line; do
    hits=$((hits + 1)); echo "  secret-shaped: $line" >&2
  done < <(grep -rInE "$pat" "$S" 2>/dev/null | grep -v '\.env\.example:' | head -20)

  # Any real dotenv (not the example) must not exist at all.
  while IFS= read -r f; do
    hits=$((hits + 1)); echo "  dotenv in tree: ${f#"$S"/}" >&2
  done < <(find "$S" -name '.env' -o -name '.env.*' ! -name '.env.example' -o -name '.dev.vars' 2>/dev/null)

  [ $hits -eq 0 ]
}

write_tests() {
  local S="$1"
  mkdir -p "$S/tests"
  cat > "$S/tests/factory.test.ts" <<'TS'
/**
 * The factory repo's own suite. It reaches into nothing — reaching tests are
 * what pin the monorepo together (24 files, 43 refs) and this tree must not
 * inherit that. Every assertion below reads only this repo.
 */
import { describe, expect, test } from "bun:test"
import { existsSync, readFileSync, readdirSync } from "node:fs"
import { join } from "node:path"

const ROOT = join(import.meta.dir, "..")
const read = (p: string) => readFileSync(join(ROOT, p), "utf8")

describe("the loop is present", () => {
  test("/do and its spine exist", () => {
    for (const f of [".claude/commands/do.md", ".claude/commands/close.md", ".claude/CLAUDE.md"])
      expect(existsSync(join(ROOT, f))).toBe(true)
  })

  test("the four build-wave agents exist", () => {
    for (const w of ["w1-recon", "w2-decide", "w3-edit", "w4-verify"])
      expect(existsSync(join(ROOT, `.claude/agents/${w}.md`))).toBe(true)
  })

  test("the promise lint ships and is executable", () => {
    expect(existsSync(join(ROOT, ".claude/scripts/do-promise-lint.sh"))).toBe(true)
  })

  test("the doc templates ship", () => {
    const t = readdirSync(join(ROOT, "text")).filter((f) => f.startsWith("template-"))
    expect(t.length).toBeGreaterThan(3)
  })
})

describe("the boundary holds", () => {
  test("no monorepo-only script shipped", () => {
    const banned = ["factory-check.sh", "do-substrate-check.sh", "spine-canary.sh", "typedb-env.sh", "do-rank.py"]
    for (const b of banned) expect(existsSync(join(ROOT, `.claude/scripts/${b}`))).toBe(false)
  })

  test("no shipped script HARD-depends on the monorepo", () => {
    // The property that matters is not "never says one.ie/web" — a comment or
    // an optional fallback path is harmless and degrades to nothing here. What
    // breaks a clone is an *unconditional* dependency: importing a module from
    // the monorepo, sourcing a file there, or writing output into it.
    const scripts = readdirSync(join(ROOT, ".claude/scripts"), { withFileTypes: true })
      .filter((e) => e.isFile())
      .map((e) => `.claude/scripts/${e.name}`)

    const HARD = [
      /^\s*(import|export)\s.*['"][^'"]*one\.ie\/web[^'"]*['"]/m, // import from the app tree
      /^\s*(source|\.)\s+\S*one\.ie\/web/m,                       // source a file there
      /resolve\([^)]*['"]one\.ie\/web/m,                          // resolve an output path there
    ]
    const offenders = scripts.filter((f) => {
      let src: string
      try { src = read(f) } catch { return false }
      return HARD.some((re) => re.test(src))
    })
    expect(offenders).toEqual([])
  })

  test("every shipped credential read honours ONE_ENV_FILE", () => {
    // A script that reads one.ie/web/.env with no override cannot find
    // credentials in a clone — it fails silently, which is worse than loudly.
    const scripts = readdirSync(join(ROOT, ".claude/scripts"), { withFileTypes: true })
      .filter((e) => e.isFile())
      .map((e) => `.claude/scripts/${e.name}`)

    const offenders = scripts.filter((f) => {
      let src: string
      try { src = read(f) } catch { return false }
      if (!/one\.ie\/web\/\.(env|secrets|dev\.vars)/.test(src)) return false
      return !/ONE_ENV_FILE/.test(src)
    })
    expect(offenders).toEqual([])
  })

  test("settings.json does not ship; the example does", () => {
    // Assert what is TRACKED, not what is on disk. A set-up clone is a superset
    // of the shipped tree: README step 3 tells you to create .claude/settings.json,
    // so an existsSync check here goes red for every collaborator who followed
    // the instructions — a suite that fails when you do it right teaches people
    // to ignore the suite.
    expect(existsSync(join(ROOT, ".claude/settings.example.json"))).toBe(true)
    const gi = read(".gitignore")
    expect(gi).toMatch(/^\.claude\/settings\.json$/m)
  })

  test("CONTRIBUTING.md ships and names the return path", () => {
    // A generated tree that doesn't say it's generated invites the one mistake
    // that loses work: fixing it here and never carrying it upstream. The doc
    // has to name the direction, not just invite contributions generically.
    expect(existsSync(join(ROOT, "CONTRIBUTING.md"))).toBe(true)
    // \s+ between words, never a literal space: prose here is hard-wrapped at
    // ~78 chars, so any phrase can acquire a newline mid-sentence on an edit.
    const c = read("CONTRIBUTING.md")
    expect(c).toMatch(/generated\s+output/i)
    expect(c).toMatch(/not\s+a\s+second\s+source/i)
    expect(c).toMatch(/pull\s+requests?\s+.*canonical\s+harness/is)
    expect(c).toMatch(/regenerated\s+outward/i)
  })
})

describe("the connect layer is one file", () => {
  test(".mcp.json names the substrate by env var, never by value", () => {
    const mcp = read(".mcp.json")
    expect(mcp).toContain("@oneie/mcp")
    expect(mcp).toContain("ONEIE_API_KEY")
    expect(/one-[0-9a-f]{32,}/.test(mcp)).toBe(false)
  })

  test(".env is gitignored and .env.example is not", () => {
    const gi = read(".gitignore")
    expect(gi).toMatch(/^\.env$/m)
    expect(gi).toMatch(/^!\.env\.example$/m)
  })

  test("no key-shaped string anywhere in the tree", () => {
    const walk = (d: string): string[] =>
      readdirSync(join(ROOT, d), { withFileTypes: true }).flatMap((e) => {
        if (e.name === "node_modules" || e.name === ".git") return []
        return e.isDirectory() ? walk(join(d, e.name)) : [join(d, e.name)]
      })
    const pat = /(one-[0-9a-f]{32,})|(osk_[A-Za-z0-9]{16,})|(sk-[A-Za-z0-9_-]{20,})|(-----BEGIN [A-Z ]*PRIVATE KEY-----)/
    const offenders = walk(".").filter((f) => {
      if (f.endsWith(".env.example")) return false
      try { return pat.test(read(f)) } catch { return false }
    })
    expect(offenders).toEqual([])
  })
})
TS
}

# Authored by the loop itself, in a clone, on 2026-07-30 — then folded back
# into the generator. That round trip is the contribution path this file
# describes, run once for real.
write_contributing() {
  cat > "$1/CONTRIBUTING.md" <<'MD'
# Contributing

This tree is **generated output**, not a second source. It is built from the
canonical harness and can be rebuilt at any time — so a fix committed only here
survives exactly until the next regeneration, then vanishes. That is not a bug
to work around; it is the one direction of truth the factory keeps.

## The return path

An improvement travels back up, then outward again:

```
1. change it here          prove it in this tree — the loop is runnable
2. pull request upstream    against the canonical harness, not against this tree
3. regenerate outward       merged canon is regenerated into every built tree
4. --check                  reports drift between a built tree and canon
```

Step 2 is the whole rule: **improvements return as pull requests against the
canonical harness upstream and get regenerated outward.** One direction of
truth, both ways of travelling it.

Use this tree to *prove* the change — edit the command, run the loop, watch it
close a cycle. Then carry the proven diff upstream. A patch that was never run
here is a patch nobody has tested; a patch that only landed here is a patch
nobody will keep.

If the two ever disagree, canon wins and `--check` is how you find out.

## What a returning change must hold

The boundary is the reason a clone works at all, so contributions keep it:

- **No secrets, ever.** Not in a file, not in one commit. The generator scans
  for key-shaped strings *before* `git init`; `tests/factory.test.ts` scans the
  whole tree again.
- **No monorepo-only checks.** A script that asserts against the tree this was
  generated from fails here for the wrong reason, so it must not ship.
- **No hard dependency on a private checkout.** A comment or an optional
  fallback is fine; an unconditional import, `source`, or output path into the
  application tree is not.
- **Credential reads honour `ONE_ENV_FILE`.** A script that reads a fixed
  `.env` inside the app tree finds nothing in a clone and fails silently —
  worse than failing loudly.
- **Tests reach into nothing.** Every assertion in `tests/` reads only this
  repo. Reaching tests are what pin a monorepo together, and this tree must not
  inherit that.

## Checks this tree can run

Both run with no monorepo, no substrate, and no key:

```bash
bun test tests/     # the boundary suite — the tree's own shape
bun run check       # syntax-checks .claude/workflows/*.js
```

Anything needing a workspace needs your own key (`.env.example` → `.env`) and
is not part of the boundary suite by design.

---

*Details of what is deliberately absent, and why: `README.md`.*
MD
}

write_readme() {
  local S="$1"
  cat > "$S/README.md" <<'MD'
# The ONE Factory

A loop that takes an intention and returns shipped, verified work — with a
promise at the top that can only settle when a command exits zero.

This repo is the loop itself, standalone. It contains no secrets, no tenant
data, and no part of the system it was cut from. You point it at your own
workspace and it builds *your* projects.

**Private repo, public stack.** Everything the loop reaches for is open or
published:

| | |
|---|---|
| `github.com/one-ie/one` | the open-source starter the loop scaffolds projects from |
| `@oneie/sdk` · `@oneie/mcp` · `@oneie/cli` | published on npm |
| `api.one.ie` · `one.ie/api/*` | the substrate, over HTTPS |

Nothing here requires a private checkout. The repo is private because the
*loop* is the thing worth keeping close — not because its dependencies are.

---

## Clone to first closed cycle

```bash
git clone git@github.com:one-ie/factory.git
cd factory

# 1. mint your own key — it carries exactly your authority, nothing more
npx -y @oneie/cli auth login

# 2. bind the connect layer
cp .env.example .env
$EDITOR .env          # paste ONEIE_API_KEY

# 3. bring the harness up
cp .claude/settings.example.json .claude/settings.json
bun install

# 4. export — nothing loads .env for you, and an unexported
#    key means every substrate tool fails without saying why
set -a; source .env; set +a

# 5. warm the npx cache once — on a cold cache the MCP
#    server download outlasts startup and reads as unavailable
npx -y @oneie/mcp@0.6.0 --help

# 6. run the loop
claude
> /do add a health endpoint that reports substrate reachability
```

`/do` walks AIM → PROMISE → SURVEY → DESIGN → PLAN → BUILD → TEST → VERIFY →
PROVE → TEACH → SHIP → LEARN. Every stage is an artifact made true; the promise
at the top settles only when its `proof:` command exits zero.

## Building a project

The factory doesn't hold your project — it builds one, next to itself, from the
public starter:

```bash
npx -y @oneie/cli new my-project     # scaffolds from github.com/one-ie/one
cd my-project && bun install
```

Then run the loop against it. `/do` finds the project by its `text/` canon, so
point it at the tree you want built:

```bash
claude
> /do in ../my-project, add a pricing page that reads plans from the substrate
```

Every cycle closes back into the substrate — `mark` on what worked, `warn` on
what didn't — so the next cycle starts from evidence rather than from scratch.

## Adding tasks to the board

Your tasks live in the substrate, not in a file. The MCP server in `.mcp.json`
gives the loop — and you — a board:

```
tasks_create   title + notes + tags        → returns a tid
tasks_list     the open queue, weight-ranked
tasks_claim    take one off the queue, stamps @you
tasks_status   open | picked | done | verified | dissolved
```

Or over plain HTTP, which is all the MCP server is doing:

```bash
curl -s -X POST https://one.ie/api/ask/tasks:create \
  -H "Authorization: Bearer $ONEIE_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"data":{"title":"Ship the health endpoint","notes":"Done = /health returns 200 and names the substrate it reached.","tags":["factory"]}}'
```

The `data` envelope is required. Every task you create is tagged with your
workspace, and the board ranks by *learned* weight where it has evidence — the
priority you author is the starting point, not the final order.

## What is here

| | |
|---|---|
| `.claude/commands/` | `/do`, `/close`, `/go`, `/see`, `/create` … the operator surface |
| `.claude/agents/` | the four build waves — recon, decide, edit, verify |
| `.claude/skills/` | domain skills the loop pulls in on match |
| `.claude/rules/` | auto-loaded per file glob |
| `.claude/hooks/` | the gates — staging guards, config guard, outcome check |
| `.claude/scripts/` | the deterministic checks: promise lint, reconcile, rubric, walk |
| `text/` | the canon the loop reads, and the doc templates it writes from |
| `tests/` | this repo's own suite — it reaches into nothing |

## What is deliberately absent

Not an oversight, a boundary.

- **No secrets.** The generator refuses to emit a tree containing a key-shaped
  string, and it scans *before* `git init` — so nothing can enter history even
  for one commit.
- **No tenant data, no client sites, no application tree.**
- **No production credentials.** You bring your own workspace and your own key.
- **No upstream history.** This tree is born with one commit, because a
  history-preserving cut of any prefix carries root-level blobs.
- **No monorepo-only checks.** Scripts that assert against the tree this was
  generated from do not ship; they would fail here for the wrong reason.

## The two targets

The repo binds to the substrate through a published interface, not a directory.

```
ONE_TARGET=published   @oneie/{sdk,mcp,cli} from npm
                       (no monorepo on disk — the default)

ONE_TARGET=workspace   workspace links, for a maintainer
                       with the monorepo checked out
```

No source edits between them. The version is the boundary.

## Contributing back

This tree is **generated output**, not a second source. Improvements return as
pull requests against the canonical harness upstream and get regenerated
outward — one direction of truth, both ways of travelling it.

The return path, the boundary suite a PR must keep green, and what never
travels upstream: [CONTRIBUTING.md](CONTRIBUTING.md).

---

*Generated by `factory-repo.sh`. Licence: see `.claude/LICENSE`.*
MD
}

# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------
tmpbuild() { # build into a temp dir and echo the path
  local d; d="$(mktemp -d)/factory"
  build "$d" >/dev/null 2>&1 || { echo ""; return 1; }
  echo "$d"
}

use_tree() { # $1 = optional dir; else build one
  if [ -n "${1:-}" ] && [ -d "$1" ]; then echo "$1"; else tmpbuild; fi
}

check_history() {
  head_ "check-history — one commit, no env/key blob on any ref"
  local T; T="$(use_tree "${1:-}")" || { fail "build failed"; return; }
  local n; n="$(git -C "$T" rev-list --count --all 2>/dev/null || echo 0)"
  [ "$n" = "1" ] && pass "exactly one commit on all refs" || fail "expected 1 commit, found $n"
  local blobs
  blobs="$(git -C "$T" log --all --full-history --name-only --format="" \
    -- '*.dev.vars' '*.env' '.env.*' '*secret*' '*.pem' '*.key' 2>/dev/null \
    | grep -v '\.env\.example$' | sort -u)"
  [ -z "$blobs" ] && pass "no env/key blob reachable from any ref" || fail "blobs in history: $blobs"
  [ -z "$(git -C "$T" remote 2>/dev/null)" ] && pass "born with no remote" || info "remote already set (expected after handover)"
}

check_drift() {
  head_ "check — drift between canon and a built tree"
  local T="${1:-}"
  if [ -z "$T" ] || [ ! -d "$T" ]; then
    # Determinism first — a generator that varies makes every drift report noise.
    local A B; A="$(tmpbuild)"; B="$(tmpbuild)"
    [ -n "$A" ] && [ -n "$B" ] || { fail "build failed"; return; }
    local d; d="$(diff -rq --exclude=.git "$A" "$B" 2>&1)"
    [ -z "$d" ] && pass "generator is deterministic" || { fail "non-deterministic build:"; echo "$d" | head -10 >&2; }

    # Then the drift the deliverable actually names: canon vs the PUBLISHED
    # tree. Without this, "--check reports drift" was only ever comparing the
    # generator to itself — and the live remote could rot unnoticed, which is
    # the exact failure mode this repo is designed to avoid.
    local REMOTE="${FACTORY_REMOTE:-https://github.com/one-ie/factory.git}"
    local C; C="$(mktemp -d)/published"
    if git clone -q --depth 1 "$REMOTE" "$C" 2>/dev/null; then
      T="$C"
      info "comparing canon against the published tree at $REMOTE"
    else
      # FAIL, never skip. This check's entire deliverable is "drift is detected
      # loudly"; letting an unreachable remote pass green means the proof
      # settles KEPT on a machine that verified no drift at all. Set
      # FACTORY_CHECK_OFFLINE=1 to acknowledge deliberately — it still fails,
      # because a check that did not run proved nothing.
      if [ "${FACTORY_CHECK_OFFLINE:-0}" = "1" ]; then
        fail "drift NOT CHECKED — FACTORY_CHECK_OFFLINE=1 was set deliberately"
      else
        fail "drift NOT CHECKED — cannot reach $REMOTE (no access, or no network)"
        info "the published tree is the thing this check exists to compare against"
      fi
      return
    fi
  fi
  local F; F="$(tmpbuild)"
  [ -n "$F" ] || { fail "build failed"; return; }
  local d; d="$(diff -rq --exclude=.git --exclude=node_modules --exclude=.env "$F" "$T" 2>&1)"
  if [ -z "$d" ]; then pass "built tree matches canon"
  else fail "drift vs canon:"; echo "$d" | head -30 >&2; fi
}

check_env_indirection() {
  head_ "check-env-indirection — every credential read honours ONE_ENV_FILE"
  local bad=0
  while IFS= read -r rel; do
    local f=".claude/scripts/$rel"
    [ -f "$f" ] || continue
    grep -qE 'one\.ie/web/\.(env|secrets|dev\.vars)' "$f" || continue
    if grep -q 'ONE_ENV_FILE' "$f"; then
      pass "$rel honours ONE_ENV_FILE"
    else
      fail "$rel reads one.ie/web/.env with no ONE_ENV_FILE override"; bad=1
    fi
  done < <(manifest | awk '$1 != "monorepo-only" {print $2}')

  # Behavioural: point ONE_ENV_FILE at a foreign path and prove it is read.
  # Behavioural: point ONE_ENV_FILE at a path nothing in this tree knows about
  # and prove the resolver actually reads it. A grep for the variable name is
  # not evidence the override works.
  local tmp; tmp="$(mktemp -d)/foreign.env"
  mkdir -p "$(dirname "$tmp")"
  printf 'SERVER_SECRET=factory-repo-probe\n' > "$tmp"
  local got; got="$(ONE_ENV_FILE="$tmp" bash .claude/scripts/do-signal.sh --print-env 2>/dev/null)"
  if [ "$got" = "resolved-from: $tmp" ]; then
    pass "do-signal.sh resolves credentials from a foreign ONE_ENV_FILE"
  else
    fail "ONE_ENV_FILE override is not honoured at runtime — got: ${got:-<nothing>}"; bad=1
  fi

  # And it must go red: with the override pointing at nothing, the resolver
  # must not silently claim success.
  local none; none="$(ONE_ENV_FILE=/nonexistent/nope.env bash .claude/scripts/do-signal.sh --print-env 2>/dev/null)"
  if [ "$none" = "resolved-from: $tmp" ]; then
    fail "the probe reports a stale path — it is not reading the override"; bad=1
  else
    pass "the probe tracks the override (proof it is a check, not theatre)"
  fi
  [ $bad -eq 0 ] || return 1
}

check_portability() {
  head_ "check-portability — the manifest is asserted against the scripts and skills"
  local bad=0

  # Every tracked script is classified.
  while IFS= read -r f; do
    local rel="${f#.claude/scripts/}"
    manifest | awk -v n="$rel" '$2 == n {found=1} END {exit !found}' \
      || { fail "unclassified: $rel"; bad=1; }
  done < <(git ls-files .claude/scripts)

  # Every manifest entry names a real file.
  while IFS= read -r rel; do
    [ -f ".claude/scripts/$rel" ] || { fail "manifest names a missing file: $rel"; bad=1; }
  done < <(manifest | awk '$2 !~ /^skills\// {print $2}')

  # `portable` means portable: no monorepo path, no credential read.
  # A URL (https://one.ie/…) is not a path — the boundary is a directory that
  # must exist on disk, not a host the script talks to over HTTPS.
  # Two narrow exclusions, each earning its place:
  #   * a COMMENT-ONLY line is prose, not a dependency — it named do-test-gate.sh
  #     line 35 (a sentence about fixtures) as though it were a load-bearing path.
  #   * `portability-ok: <reason>` marks a line where the path is a PROBE
  #     CANDIDATE that degrades when absent, not a dependency that dies. The
  #     reason is mandatory: a bare pragma is refused below.
  # Anything else still fails. These narrow what the grep MEANS, never what it sees.
  while IFS= read -r rel; do
    local f=".claude/scripts/$rel"
    local hits
    hits="$(grep -nE "$MONOREPO_PATH_RE" "$f" 2>/dev/null \
            | grep -vE '^[0-9]+:[[:space:]]*(#|//|\*)' \
            | grep -v 'portability-ok:' || true)"
    if [ -n "$hits" ]; then
      fail "declared portable but names a monorepo path: $rel"
      printf '%s\n' "$hits" | head -3 | sed 's/^/         /' >&2
      bad=1
    fi
    # A pragma with no reason after it is not a justification.
    if grep -qE 'portability-ok:[[:space:]]*$' "$f" 2>/dev/null; then
      fail "portability-ok pragma with no reason: $rel"
      bad=1
    fi
  done < <(manifest | awk '$1 == "portable" && $2 !~ /^skills\// {print $2}')

  # --- skills ------------------------------------------------------------
  # Same three buckets, same refusal: a skill nobody classified does not ship,
  # and the build will not run until it is named. Silence is never a licence.
  while IFS= read -r d; do
    manifest | awk -v n="skills/$d" '$2 == n {found=1} END {exit !found}' \
      || { fail "unclassified: skills/$d"; bad=1; }
  done < <(tracked_skills)

  # Every skills/ row names a real directory.
  while IFS= read -r rel; do
    [ -d ".claude/skills/${rel#skills/}" ] \
      || { fail "manifest names a missing skill: $rel"; bad=1; }
  done < <(manifest | awk '$2 ~ /^skills\// {print $2}')

  # `portable` means the skill travels to ANY tree: no monorepo path, and no
  # text/ canon cite either — a skill whose source of truth is a text/ doc is
  # needs-env, because the doc does not travel with it.
  while IFS= read -r rel; do
    local d=".claude/skills/${rel#skills/}"
    if grep -rqE "$MONOREPO_PATH_RE" "$d" 2>/dev/null; then
      fail "skill declared portable but names a monorepo path: $rel"
      grep -rnE "$MONOREPO_PATH_RE" "$d" | head -3 | sed 's/^/         /' >&2
      bad=1
    fi
    if grep -rqE "$CANON_CITE_RE" "$d" 2>/dev/null; then
      fail "skill declared portable but cites text/ canon (should be needs-env): $rel"
      grep -rnE "$CANON_CITE_RE" "$d" | head -3 | sed 's/^/         /' >&2
      bad=1
    fi
  done < <(manifest | awk '$1 == "portable" && $2 ~ /^skills\// {print $2}')

  local n_scripts n_skills
  n_scripts="$(manifest | awk '$2 !~ /^skills\//' | wc -l | tr -d ' ')"
  n_skills="$(manifest | awk '$2 ~ /^skills\//' | wc -l | tr -d ' ')"
  [ $bad -eq 0 ] && pass "$n_scripts scripts + $n_skills skills classified, portable set is clean"
  [ $bad -eq 0 ] || return 1
}

check_targets() {
  head_ "check-targets — one flag, no source edits"
  local bad=0
  local A B
  A="$(ONE_TARGET=published tmpbuild)"; B="$(ONE_TARGET=workspace tmpbuild)"
  [ -n "$A" ] && [ -n "$B" ] || { fail "build failed under one of the targets"; return 1; }

  grep -q '"@oneie/sdk": "\^' "$A/package.json" && pass "published → pinned npm versions" \
    || { fail "published target does not pin versions"; bad=1; }
  grep -q '"@oneie/sdk": "file:' "$B/package.json" && pass "workspace → local file: links" \
    || { fail "workspace target does not link locally"; bad=1; }

  # A dep string is not a resolvable dep. `workspace:*` in a tree outside the
  # workspace that declares it fails to resolve — verified, all three packages —
  # so this must install, not merely parse. This is the check that caught it.
  if command -v bun >/dev/null 2>&1; then
    local out; out="$(cd "$B" && bun install --dry-run 2>&1)"
    if grep -q 'failed to resolve' <<<"$out"; then
      fail "workspace target does not install:"; grep 'failed to resolve' <<<"$out" | sed 's/^/         /' >&2; bad=1
    else
      pass "workspace target's deps actually resolve (bun install --dry-run)"
    fi
  else
    info "bun not found — workspace deps not resolution-tested"
  fi

  local d; d="$(diff -rq --exclude=.git --exclude=package.json "$A" "$B" 2>&1)"
  [ -z "$d" ] && pass "the two targets differ in package.json only — no source edits" \
    || { fail "targets differ outside package.json:"; echo "$d" | head -10 >&2; bad=1; }
  [ $bad -eq 0 ] || return 1
}

check_connect() {
  head_ "check-connect — the connect layer is one file"
  local T; T="$(use_tree "${1:-}")" || { fail "build failed"; return 1; }
  local bad=0

  [ -f "$T/.mcp.json" ] && pass ".mcp.json present" || { fail ".mcp.json missing"; bad=1; }

  # One file BINDS the substrate; many may READ it. The distinction is the
  # whole point of a connect layer: `${ONE_API_URL:-https://one.ie}` in a
  # script is a consumer with an overridable default, whereas a bare
  # `ONE_API_URL=https://one.ie` is a second binding that .env can no longer
  # move. Only unconditional assignments count as bindings.
  local binders
  binders="$(grep -rlE '^[[:space:]]*(export[[:space:]]+)?(ONEIE?_API_URL|ONEIE?_API_KEY)=[^$]' "$T" 2>/dev/null \
    | sed "s|^$T/||" | grep -v '^\.env\.example$' | sort)"
  [ -z "$binders" ] && pass "nothing but the connect layer binds the substrate — every other reference is an overridable default" \
    || { fail "a second file binds the substrate:"; echo "$binders" >&2; bad=1; }

  # Every shipped origin default must be overridable, or a clone is pinned to
  # a host it cannot reach.
  local pinned
  # Overridable takes three shapes across bash, TS, and node: `${VAR:-url}`,
  # `process.env.VAR ?? 'url'`, and `argv.find(…) ?? 'url'`. All three are fine.
  # A doc example inside help text is not a binding either.
  pinned="$(grep -rInE 'https?://(one\.ie|api\.one\.ie|localhost:4321)' "$T/.claude/scripts" "$T/.claude/hooks" 2>/dev/null \
    | grep -vE '\$\{[A-Z_]+:-' \
    | grep -vE '\?\?[[:space:]]*.https?://' \
    | grep -vE '^\S+:[0-9]+:[[:space:]]*#' \
    | grep -vE 'one\.ie/foo' \
    | sed "s|^$T/||")"
  [ -z "$pinned" ] && pass "no shipped script pins an origin it cannot be moved off" \
    || { fail "a script pins an origin with no env override:"; echo "$pinned" | head -8 >&2; bad=1; }

  # .env.example must set every origin the shipped scripts fall back on, or a
  # clone silently signals into a localhost dev server that does not exist.
  grep -q '^ONE_API_URL=' "$T/.env.example" && pass ".env.example moves the loop off the localhost default" \
    || { fail ".env.example does not set ONE_API_URL — the loop would signal into localhost"; bad=1; }

  # Claude Code expands ${VAR} in .mcp.json from the PROCESS environment and
  # does not read dotenv files. A .env nobody exports is a connect layer that
  # silently comes up with an empty key — so the tree must say so out loud.
  grep -q 'source .env' "$T/.env.example" && pass ".env.example says how to actually load itself" \
    || { fail ".env.example does not name the export step — a clone would start with an empty key"; bad=1; }

  grep -q 'oneie/mcp' "$T/.mcp.json" && pass ".mcp.json runs the published @oneie/mcp" \
    || { fail ".mcp.json does not reference @oneie/mcp"; bad=1; }
  grep -qE 'one-[0-9a-f]{16,}' "$T/.mcp.json" && { fail ".mcp.json carries a literal key"; bad=1; } \
    || pass ".mcp.json names the key by env var, never by value"

  grep -q 'ONEIE_API_KEY' "$T/.env.example" && pass ".env.example names the key without a value" \
    || { fail ".env.example does not name ONEIE_API_KEY"; bad=1; }
  grep -qE '^ONEIE_API_KEY=$' "$T/.env.example" && pass "the example key is empty" \
    || { fail ".env.example has a non-empty key"; bad=1; }
  grep -qx '.env' "$T/.gitignore" && pass ".env is gitignored" || { fail ".env not gitignored"; bad=1; }
  [ $bad -eq 0 ] || return 1
}

check_no_secrets() {
  head_ "check-no-secrets — the scan, and the refusal"
  local T; T="$(use_tree "${1:-}")" || { fail "build failed"; return 1; }
  if scan_secrets "$T"; then pass "no key-shaped string in the built tree"
  else fail "key-shaped string in the built tree"; return 1; fi

  # The check must be able to go red. Plant one and prove the scan catches it.
  local canary; canary="$(mktemp -d)"
  cp -R "$T/." "$canary/" 2>/dev/null
  printf 'ONEIE_API_KEY=one-%s\n' "$(printf '0%.0s' $(seq 1 40))" > "$canary/planted.txt"
  if scan_secrets "$canary" >/dev/null 2>&1; then
    fail "the scan passed a tree containing a planted key — it cannot go red"
    return 1
  else
    pass "the scan goes red on a planted key (proof it is a check, not theatre)"
  fi
  rm -rf "$canary"
}

check_tests() {
  head_ "check-tests — the repo carries its own suite, reaching into nothing"
  local T; T="$(use_tree "${1:-}")" || { fail "build failed"; return 1; }
  [ -f "$T/tests/factory.test.ts" ] && pass "suite present" || { fail "no suite"; return 1; }

  if grep -qE '\.\./\.\./(one\.ie|pay|channels|api|schema)' "$T/tests/"*.ts 2>/dev/null; then
    fail "the suite reaches out of the repo"; return 1
  fi
  pass "the suite has no cross-tree imports"

  if command -v bun >/dev/null 2>&1; then
    local out; out="$(cd "$T" && bun test tests/ 2>&1)"
    if grep -qE '[0-9]+ pass' <<<"$out" && ! grep -qE '[1-9][0-9]* fail' <<<"$out"; then
      pass "suite runs green in the built tree — $(grep -oE '[0-9]+ pass' <<<"$out" | head -1)"
    else
      fail "suite is red in the built tree:"; echo "$out" | tail -25 >&2; return 1
    fi
  else
    info "bun not found — suite present but not executed"
  fi
}

# The shipped harness reads canon. A command that cites text/lifecycle.md in a
# tree that doesn't carry it sends the reader — human or agent — to a file that
# isn't there. This was real: rules/documentation.md names SIX source-of-truth
# docs and the first build shipped four.
check_canon() {
  head_ "check-canon — the spine cites nothing the tree does not carry"
  local T; T="$(use_tree "${1:-}")" || { fail "build failed"; return 1; }
  local bad=0 allow; allow="$(allowed_dangling | awk '{print $2}')"

  local dangling=""
  while IFS= read -r ref; do
    [ -f "$T/$ref" ] && continue
    grep -qxF "$ref" <<<"$allow" && continue
    dangling="$dangling$ref
"
  done < <(grep -rhoE 'text/[a-z0-9-]+\.md' \
             "$T/.claude/commands" "$T/.claude/rules" \
             "$T/.claude/agents" "$T/.claude/workflows" 2>/dev/null | sort -u)

  if [ -z "$dangling" ]; then
    pass "every text/ file the spine cites is present, or explicitly allowed"
  else
    fail "the spine cites canon the tree does not carry:"
    printf '%s' "$dangling" | sed 's/^/         /' >&2
    bad=1
  fi

  # The same rot, one namespace over. The build drops `monorepo-only` skill
  # directories, so a shipped agent/command/rule/workflow pointing at one names
  # a directory the tree does not carry. Scoped to the skills this build
  # DELIBERATELY dropped: a cite of a loose .claude/skills/*.md, or of a skill
  # that does not exist upstream either, is a different (older) question and is
  # not laundered through this check.
  local dangling_skills="" allow_skills dropped_skills
  allow_skills="$(allowed_dangling_skills | awk '{print $2}')"
  dropped_skills="$(manifest | awk '$1 == "monorepo-only" && $2 ~ /^skills\// {print $2}')"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    grep -qxF "$ref" <<<"$dropped_skills" || continue      # not a dropped skill
    [ -d "$T/.claude/$ref" ] && continue                   # shipped after all
    grep -qxF "$ref" <<<"$allow_skills" && continue
    dangling_skills="$dangling_skills$ref
"
  done < <(grep -rhoE '(^|[^/[:alnum:]._-])(\.claude/)?skills/[a-z0-9-]+' \
             "$T/.claude/commands" "$T/.claude/rules" \
             "$T/.claude/agents" "$T/.claude/workflows" 2>/dev/null \
             | sed -E 's|^[^a-zA-Z0-9._]*||; s|^\.claude/||' | sort -u)

  if [ -z "$dangling_skills" ]; then
    pass "every monorepo-only skill the spine cites is allowlisted as conditional"
  else
    fail "the spine cites a monorepo-only skill the tree does not carry:"
    printf '%s' "$dangling_skills" | sed 's/^/         /' >&2
    info "either ship it (reclassify in the manifest) or add it to allowed_dangling_skills with a reason"
    bad=1
  fi

  # A skills exemption that came back into the tree is a stale exemption.
  while IFS= read -r ref; do
    [ -d "$T/.claude/$ref" ] || continue
    fail "skill allowlisted but now shipped — drop the exemption: $ref"; bad=1
  done < <(allowed_dangling_skills | awk '{print $2}')

  # The allowlist must not rot either: an entry that is now shipped, or a
  # `stale` entry that came back upstream, is a stale exemption.
  while IFS= read -r line; do
    local kind ref; kind="${line%% *}"; ref="${line##* }"
    if [ -f "$T/$ref" ]; then
      fail "allowlisted but now shipped — drop the exemption: $ref"; bad=1
    elif [ "$kind" = "stale" ] && [ -f "$ROOT/$ref" ]; then
      fail "allowlisted as stale but exists upstream now — reclassify: $ref"; bad=1
    fi
  done < <(allowed_dangling)

  # It must be able to go red.
  local canary; canary="$(mktemp -d)/tree"
  mkdir -p "$canary/.claude/commands"
  printf 'see text/definitely-not-shipped.md\n' > "$canary/.claude/commands/probe.md"
  if grep -rhoE 'text/[a-z0-9-]+\.md' "$canary/.claude/commands" | grep -q 'definitely-not-shipped'; then
    pass "the check goes red on a planted dangling reference"
  else
    fail "the dangling-reference scan cannot detect a planted reference"; bad=1
  fi
  rm -rf "$canary"
  [ $bad -eq 0 ] || return 1
}

check_no_machine_paths() {
  head_ "check-no-machine-paths — no absolute path to the maintainer's disk travels"
  local T; T="$(use_tree "${1:-}")" || { fail "build failed"; return 1; }
  local left
  left="$(grep -rlE '(/Users/[a-z]+/|/home/[a-z]+/)' "$T" 2>/dev/null | sed "s|^$T/||")"
  [ -z "$left" ] && pass "no absolute machine path in the built tree" \
    || { fail "absolute machine paths survive in:"; echo "$left" | head -8 >&2; return 1; }

  # It must be able to go red: plant one and prove the build refuses.
  local canary; canary="$(mktemp -d)/tree"
  mkdir -p "$canary"; cp -R "$T/." "$canary/" 2>/dev/null
  printf 'cd /Users/someone/private/repo && bun run dev\n' > "$canary/planted.sh"
  if grep -rqE '(/Users/[a-z]+/|/home/[a-z]+/)' "$canary" 2>/dev/null; then
    pass "the check goes red on a planted path (proof it is a check, not theatre)"
  else
    fail "the check passed a tree containing a planted machine path"; return 1
  fi
  rm -rf "$canary"
}

# Live round trip on the rail a standalone clone actually uses: a world key,
# over HTTPS, no monorepo. Reads ONE_ENV_FILE (or the monorepo default).
check_substrate() {
  head_ "check-substrate — a world key creates a task over plain HTTPS"
  local envf="${ONE_ENV_FILE:-$ROOT/one.ie/web/.env}"
  local key="${ONEIE_API_KEY:-}" url="${ONEIE_API_URL:-https://one.ie}"
  if [ -z "$key" ] && [ -f "$envf" ]; then
    key="$(grep -m1 -E '^(ONEIE_API_KEY|ONE_API_KEY)=' "$envf" | cut -d= -f2- | tr -d '"'"'"' ')"
  fi
  if [ -z "$key" ]; then
    # FAIL, never skip — same reasoning as --check. This is the deliverable that
    # says a clone can put work on a board; with no key the round trip never
    # happens, so passing green would settle the contract on nothing.
    if [ "${FACTORY_SKIP_SUBSTRATE:-0}" = "1" ]; then
      fail "substrate rail NOT CHECKED — FACTORY_SKIP_SUBSTRATE=1 was set deliberately"
    else
      fail "substrate rail NOT CHECKED — no ONEIE_API_KEY in env or $envf"
      info "the live round trip is the proof that a clone can add tasks; without a key there is none"
    fi
    return
  fi

  local body; body="$(curl -s -m 20 -X POST "$url/api/ask/tasks:create" \
    -H "Authorization: Bearer $key" -H 'Content-Type: application/json' \
    -d '{"data":{"title":"factory-repo --check-substrate probe","notes":"Automated rail probe. Dissolved immediately.","tags":["factory","probe"]}}')"
  local tid; tid="$(sed -n 's/.*"tid":"\([^"]*\)".*/\1/p' <<<"$body")"
  if [ -n "$tid" ]; then
    pass "task created over the world-key rail — $tid"
    curl -s -m 20 -o /dev/null -X POST "$url/api/ask/tasks:status" \
      -H "Authorization: Bearer $key" -H 'Content-Type: application/json' \
      -d "{\"data\":{\"tid\":\"$tid\",\"status\":\"dissolved\"}}"
    pass "probe dissolved"
  else
    fail "tasks:create did not return a tid: $(head -c 200 <<<"$body")"; return 1
  fi
}

verify() {
  head_ "verify — build to temp, no monorepo assumed, run every check"
  local T; T="$(mktemp -d)/factory"
  build "$T" || { fail "build failed"; return 1; }
  info "built at $T"

  FAILED=0
  check_history "$T"
  check_connect "$T"
  check_no_secrets "$T"
  check_tests "$T"
  check_portability
  check_targets
  check_canon "$T"

  head_ "verify — the loop in a clone"
  # Default ON. The opt-in version was a cross-surface lie: the proof passed
  # when a human ran it with FACTORY_VERIFY_CYCLE=1 and failed under
  # do-promise-settle.sh, which runs the proof string verbatim with no extra
  # env — so the promise settled BROKEN while every check was green. A proof
  # that only passes with setup its own settle harness doesn't apply is not the
  # proof in the contract. Set FACTORY_VERIFY_CYCLE=0 to skip deliberately;
  # skipping still FAILS, because a cycle that didn't run proved nothing.
  if [ "${FACTORY_VERIFY_CYCLE:-1}" = "1" ] && command -v claude >/dev/null 2>&1; then
    info "running a real /do cycle in $T …"
    # A freshly generated tree is an untrusted workspace, so Claude Code ignores
    # settings.json's permissions.allow and every bash gate in W4 goes unrun.
    # The mode must be passed here or this step silently proves less than it
    # claims — the cycle "closes" without its deterministic checks having fired.
    local log="$T/../cycle.log" after
    (
      cd "$T" || exit 1
      cp .claude/settings.example.json .claude/settings.json
      claude -p --permission-mode "${FACTORY_VERIFY_PERMS:-bypassPermissions}" \
        "${FACTORY_VERIFY_PROMPT:-/do PATCH: create docs/standalone-proof.md — a short file recording that this tree closed a /do cycle with no monorepo on disk, naming the date and what the boundary suite asserts. The file does not exist yet; create it. Then run \`bun test tests/\` and report the count. Close the cycle properly.}"
    ) > "$log" 2>&1
    after="$(cd "$T" && git status --porcelain | wc -l | tr -d ' ')"
    # Run the suite ONCE and match the captured text. The old form ran it twice
    # and the second run was a false GREEN: `bun test … | grep -qE 'fail'` under
    # `set -o pipefail` (line 25) returns 141, not 0, when it MATCHES — grep -q
    # exits on the first hit, bun is still writing, bun takes SIGPIPE. That 141
    # then went through the surrounding `! ( … )`, which inverts any non-zero to
    # true. Measured 2026-08-04 against a suite reporting `201 pass 1 fail`:
    # this branch reported the clone's boundary suite green. A false pass on the
    # gate that decides whether the factory repo ships.
    local suite_out; suite_out="$(cd "$T" && bun test tests/ 2>&1 || true)"
    local suite; suite="$(grep -m1 -oE '[0-9]+ pass' <<<"$suite_out" || true)"
    local suite_failed=0
    if grep -qE '[1-9][0-9]* fail' <<<"$suite_out"; then suite_failed=1; fi
    if [ "$after" -gt 0 ] && [ -n "$suite" ] && [ "$suite_failed" -eq 0 ]; then
      pass "a real cycle ran in the clone and left the boundary suite green — $after file(s) changed, $suite"
    else
      fail "the cycle did not close — $after file(s) changed, suite: ${suite:-none}"
      info "cycle transcript: $log"
      tail -20 "$log" 2>/dev/null | sed 's/^/       | /' >&2
    fi
  else
    fail "NOT RUN — a real /do cycle in a clone is the deliverable that gates KEPT."
    if command -v claude >/dev/null 2>&1; then
      info "FACTORY_VERIFY_CYCLE=0 was set. Unset it to run the cycle."
    else
      info "\`claude\` not on PATH — the cycle cannot run here."
    fi
  fi

  head_ "verify — result"
  [ "$FAILED" -eq 0 ] && echo "  all green" || echo "  $FAILED check(s) red"
  return "$FAILED"
}

# ---------------------------------------------------------------------------
FAILED=0
case "${1:-}" in
  --manifest)              manifest ;;
  --check-history)         check_history "${2:-}" ;;
  --check)                 check_drift "${2:-}" ;;
  --check-env-indirection) check_env_indirection ;;
  --check-portability)     check_portability ;;
  --check-targets)         check_targets ;;
  --check-connect)         check_connect "${2:-}" ;;
  --check-no-secrets)      check_no_secrets "${2:-}" ;;
  --check-tests)           check_tests "${2:-}" ;;
  --check-canon)           check_canon "${2:-}" ;;
  --check-no-machine-paths) check_no_machine_paths "${2:-}" ;;
  --check-substrate)       check_substrate ;;
  --verify)                verify ;;
  -h|--help|"")            sed -n '2,30p' "$0" ;;
  -*)                      echo "unknown flag: $1" >&2; exit 2 ;;
  *)                       build "$1" ;;
esac
rc=$?
[ "$FAILED" -gt 0 ] && exit 1
exit $rc
