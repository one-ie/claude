---
paths:
  - ".claude/scripts/**"
  - "packages/claude/scripts/**"
---

# Harness script rules

Short on purpose. Every rule here is imperative and true at the line it guards;
the story that earned it is one command away and is never summarised:

```bash
bash .claude/scripts/incident.sh --for <script>   # the accounts for this file
bash .claude/scripts/incident.sh                  # every family
```

Two neighbours, so nothing here restates them: `.claude/scripts/CLAUDE.md` is
the per-script INVENTORY (what each door does, and the SIGPIPE/`grep -q` and
governor sections), loaded when you work in that directory;
`.claude/incidents/` is the ACCOUNTS. This file is only the imperatives.

`incident.sh` and `.claude/incidents/` are **monorepo-only** — they hold this
repo's measured history and do not ship to the factory clone. In a generated
clone the rules below still apply; the accounts behind them do not travel.

## Writing one

- **Declare the manifest — in the TABLE.** The authority is the heredoc in
  `factory-repo.sh` (`portable | needs-env | monorepo-only  <script>`); the
  `# manifest:` line in the script itself is a convenience copy the check does
  **not** read. `factory-repo.sh` **refuses to build** with an unclassified
  script, and `--check-portability` only sees TRACKED files — so a new script
  passes the check right up until you commit it.
- **Split the comment.** A block is two things: the RULE (imperative, 1-2 lines,
  stays inline) and the ACCOUNT (dates, shas, counts, the wrong diagnosis that
  came first — moves to `.claude/incidents/<family>.md` under a `## <id>`, and
  the script keeps a bare `incident:<id>` token). **Carry every measurement,
  date, sha, count and error string over unchanged** — a trap loses its authority
  the moment its numbers are summarised away; rewrapping the prose around them is
  fine. `incident.sh --check` proves every pointer resolves and every account is
  reachable, both directions, both copies — but it scans DIRECTORIES, so it
  cannot see a broken `--for`, which is how deploy.sh's pointers resolved for the
  checker and not for the reader for an hour.
- **Both copies.** `packages/claude/scripts/` is a hand-maintained verbatim
  mirror with no build step, so it rots silently. `sync-claude-mirror.sh` after
  every edit; a proof that covers canon and not the copy that ships is worse than
  no proof.
- **`set -uo pipefail`, never `-e`.** These scripts read exit codes as answers
  (`git diff --quiet` exits 1 to mean "differs"); `-e` turns an answer into a
  crash.

## Gates and exit codes

- **Never pipe a gate.** `bun run verify | tail` reports tail's status — measured
  reporting **0** for an exit-1 verify. Redirect to a file, or read
  `PIPESTATUS[0]`. In the Claude Code Bash tool (zsh) `PIPESTATUS` is **empty**:
  use `${pipestatus[1]}` or a file.
- **An unrun gate is never a pass.** `gate-run.sh` exits **127** when its target
  is not on `PATH`. Invoke by absolute path, and distinguish `pass|fail|unrun|n/a`.
- **Everything heavy goes through `gate-run.sh`** — a raw `vitest` bypasses the
  governor and `hook:load-guard` blocks it.
- **Exit codes are distinct and named.** "It refused" is not a finding: give each
  refusal its own code and say which one bit.

## Proofs

- **A checker must be able to go RED.** Ship a `--self-test` that drives the
  failure, not only the success, and prove it by breaking the code on a copy.
- **A `.sh` is in no import graph**, so `vitest related` can never select it. A
  shell proof the suite must keep running needs a vitest wrapper **and** a name
  in `VERIFY_FAST_PINS` (`verify-fast.sh`) — otherwise it stops being run the
  moment its author's session ends.
- **A fixture looser than production certifies the bug.** Build the sandbox to
  match the real tree's shape, then assert.

## Doors

- **Run door scripts from the MAIN tree's copy.** `land.sh`, `release.sh`,
  `deploy.sh` and `sweep.sh` all derive `ROOT` from `${BASH_SOURCE[0]}/../..`; a
  worktree's copy operates on that worktree.
- **And check the main tree is CURRENT** — `git rev-list --count HEAD..origin/main`
  is exactly how many commits old the script you are about to run is. `git status`
  clean says nothing about it.
- **Deploy and ship are `release-manager`'s**, spawned as a subagent; the box is
  `doctor`'s. See `.claude/commands/deploy.md` and `/sweep`.
