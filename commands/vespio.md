# /vespio — the standing sync fleet

```
  ██╗   ██╗███████╗███████╗██████╗ ██╗ ██████╗
  ██║   ██║██╔════╝██╔════╝██╔══██╗██║██╔═══██╗
  ██║   ██║█████╗  ███████╗██████╔╝██║██║   ██║   one-ie ──▶ vespio
  ╚██╗ ██╔╝██╔══╝  ╚════██║██╔═══╝ ██║██║   ██║   one way · manifest-driven
   ╚████╔╝ ███████╗███████║██║     ██║╚██████╔╝
    ╚═══╝  ╚══════╝╚══════╝╚═╝     ╚═╝ ╚═════╝
```

Keep `apps/vespio` current with the tools it can actually use. One word to see
the gap, close it, and push.

**Vespio is not a smaller monorepo.** It is an agency tree — `clients/`, `site/`,
`web/`, `ai/`, `packages/`. There is no `schema/`, no `pay/`, no `channels/`, and
no `text/` promise layer. Most of one-ie's harness hard-asserts against a tree
vespio does not have. So the interesting question was never *"how do we copy
everything"* — it is *"what is portable, and who decides?"*

---

## 0 · The manifest decides — there is no second list

`.claude/scripts/factory-repo.sh` already classifies every script:

| bucket | means | ships to vespio |
|---|---|---|
| `portable` | no monorepo path, no credential read | **yes** |
| `needs-env` | wants `ONE_ENV_FILE`, or names paths that degrade to no-ops | **yes** |
| `monorepo-only` | hard-asserts against THIS tree; refuses without it | **never** |
| *unclassified* | nobody has decided yet | **never — silence is not a licence** |

`vespio-sync.sh` reads that manifest rather than keeping its own copy. Two lists
drift; one cannot. Adding a script to `.claude/scripts/` therefore means adding a
manifest line — `factory-repo.sh --check-portability` names every script that
still has none, and `/vespio` prints them so they cannot rot in silence.

**The `needs-env` bucket was classified against the FACTORY tree, not vespio's.**
Same three buckets, different destination. When a `needs-env` script misbehaves in
vespio, that is a reclassification, not a bug — fix the manifest.

---

## 1 · Run it

```bash
bash .claude/scripts/vespio-sync.sh --check    # read-only: missing · drifted
bash .claude/scripts/vespio-sync.sh            # copy, then show the diff
bash .claude/scripts/vespio-sync.sh --commit   # copy + commit (never pushes)
git -C ../apps/vespio push origin main         # the human step, always separate
```

`--check` costs nothing. Run it first and last.

**Pull before you sync.** Vespio's `main` drifts behind `origin/main` — it was
9 commits behind on 2026-08-26. Syncing onto a stale local tree and pushing is
the one irreversible mistake available here.

```bash
git -C ../apps/vespio fetch origin && git -C ../apps/vespio pull --ff-only origin main
```

---

## 2 · What ships, and what is held back on purpose

Held back is a **decision**, not an oversight. Record the reason or it will be
"fixed" by the next person.

| Held back | Why |
|---|---|
| `deploy.md` · `db-sync.md` · `release.md` | the 5-service pipeline; vespio ships a site |
| `one.md` | nine fleets over `text/*.md` docs that do not exist here |
| `oo-push.md` · `rag.md` | monorepo-specific surfaces |
| skills `typedb` `sdk` `mcp` `cli` `puck` `promise-*` | need `schema/`, `packages/`, or the promise layer |
| every `monorepo-only` script | by manifest |

`cp -RL`, not `cp -R`: `.claude/skills/livekit-agents` is a **symlink out of the
tree** and would land in vespio as a dangling link.

---

## 3 · Staging law — the neighbour's work is not yours

Vespio carries uncommitted `clients/*/data/lifecycles/*.toml` edits that belong to
somebody else. A harness sync must never carry them.

- `git add .claude` — explicit path, always.
- Never `git add -A`, never `git add .`, never `git commit -a`.
- Commit and push are **separate breaths**. Show the file list, then push.

---

## 4 · Standing state

**`.env.local.bak` is TRACKED in vespio and contains a real `ONE_API_KEY`.**
It entered at `b931b69` and `.gitignore` covers `.env.local` but not the `.bak`.
Untracking it forward is safe and done; **the key is still in git history and must
be rotated** — that is an operator action, not a fleet's. Do not attempt a history
rewrite on a shared remote.

---

## Don't

- Don't sync while a fleet is mid-write in vespio. Land the board, don't widen it.
- Don't hand-edit vespio's `.claude/` — it is generated output. Change one-ie, sync.
- Don't ship an unclassified script. Classify it in the manifest first.
- Don't push in the same breath as the commit. Look at the file list.
